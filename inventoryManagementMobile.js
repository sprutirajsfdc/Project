/*  InventoryManagementMobile.js  –  Aug 2025 (v2.9)
    ─────────────────────────────────────────────────────────────
    ✔ Dynamic field-set filters (picklists + text/number)
    ✔ Robust status tiles (null/legacy statuses guarded)
    ✔ Modal compatible with template using isUnitModalOpen
    ✔ “All” sentinel for picklists
    ✔ Project name / area formatting; image fallback
*/

import { LightningElement, track } from 'lwc';
import getExclusiveProjects        from '@salesforce/apex/UnitControllerMobile.getExclusiveProjects';
import getDeveloper                from '@salesforce/apex/UnitControllerMobile.getDeveloper';
import getLocation                 from '@salesforce/apex/UnitControllerMobile.getLocation';
import getTotalUnitCount           from '@salesforce/apex/UnitControllerMobile.getTotalUnitCount';
import getTotalSAR                 from '@salesforce/apex/UnitControllerMobile.getTotalSAR';
import getFieldSetFieldsWithLabel  from '@salesforce/apex/UnitControllerMobile.getFieldSetFieldsWithLabel';
import getPicklistValues           from '@salesforce/apex/UnitControllerMobile.getPicklistValues';
import getAllStatusLabels          from '@salesforce/apex/UnitControllerMobile.getAllStatusLabels';
import getUnits                    from '@salesforce/apex/UnitControllerMobile.getUnits';
import getListingImages            from '@salesforce/apex/UnitControllerMobile.getListingImages';
import getMobileFields             from '@salesforce/apex/UnitControllerMobile.getMobileFields';
import { ShowToastEvent }          from 'lightning/platformShowToastEvent';
import getUnitFieldSetValues       from '@salesforce/apex/UnitControllerMobile.getUnitFieldSetValues';

const FALLBACK_IMG = '/resource/Fallback_Unit_Image';
const isReal       = v => v && v !== 'All';
const numTypes     = ['DOUBLE', 'INTEGER', 'PERCENT', 'CURRENCY'];

export default class InventoryManagementMobile extends LightningElement {
  /* ───────── reactive state ───────── */
  @track statusCounts        = [];
  @track unitRecords         = [];
  @track totalUnits          = 0;
  @track totalSalesPrice     = 0;

  @track projectOptions      = [];
  @track developerOptions    = [];
  @track locationOptions     = [];

  @track selectedProject     = '';
  @track selectedDeveloper   = '';
  @track selectedLocation    = '';

  @track showFilters         = false;
  @track hasUserSearched     = false;

  @track dynamicFilterFields = [];   // raw from Apex (apiName, label, type)
  @track dynamicFilterValues = {};   // apiName -> value
  @track picklistOptions     = {};   // apiName -> [{label,value}]

  @track showUnitModal       = false;
  @track modalFields         = [];
  @track modalUnitName       = '';
  @track modalUnitId         = '';

  /* ───────── lifecycle ───────── */
  connectedCallback() {
    this.loadFilterOptions();
    this.loadFieldSetFields();
  }

  /* ───────── static pick-lists ───────── */
  loadFilterOptions() {
    getExclusiveProjects()
      .then(r => this.projectOptions = r.map(p => ({ label: p.Name, value: p.Id })))
      .catch(e => this.showError('Failed to load projects', e));

    getDeveloper()
      .then(r => this.developerOptions = [{ label: 'All', value: 'All' },
                                          ...r.map(d => ({ label: d, value: d }))])
      .catch(e => this.showError('Failed to load developers', e));

    getLocation()
      .then(r => this.locationOptions  = [{ label: 'All', value: 'All' },
                                          ...r.map(l => ({ label: l, value: l }))])
      .catch(e => this.showError('Failed to load locations', e));
  }

  /* ───────── dynamic filters ───────── */
  loadFieldSetFields() {
    getFieldSetFieldsWithLabel()
      .then(fields => {
        this.dynamicFilterFields = fields || [];

        // Preload picklist options (and add "All")
        this.dynamicFilterFields.forEach(f => {
          getPicklistValues({ objectApiName: 'Unit__c', fieldApiName: f.apiName })
            .then(opts => {
              const list = Array.isArray(opts) ? opts : [];
              if (list.length) {
                this.picklistOptions = {
                  ...this.picklistOptions,
                  [f.apiName]: [{ label: 'All', value: 'All' }, ...list]
                };
              }
            })
            .catch(e => this.showError(`Error loading ${f.apiName} options`, e));
        });
      })
      .catch(e => this.showError('Error loading filters', e));
  }

  /* View-model for template (computed from raw + current values) */
  get filterFields() {
    return (this.dynamicFilterFields || []).map(f => {
      const opts = this.picklistOptions[f.apiName] || null;
      const isPick = Array.isArray(opts) && opts.length > 0;
      return {
        apiName   : f.apiName,
        label     : f.label,
        isPicklist: isPick,
        inputType : numTypes.includes((f.type || '').toUpperCase()) ? 'number' : 'text',
        options   : opts || [],
        value     : this.dynamicFilterValues[f.apiName] || ''
      };
    });
  }

  /* Backward-compat for templates still using dynamicFilterFieldsWithValues */
  get dynamicFilterFieldsWithValues() { return this.filterFields; }

  /* ───────── modal handlers ───────── */
  togglePanel()      { this.showFilters = true; }
  closeFilterPanel() { this.showFilters = false; }
  resetFilters() {
    this.selectedProject      = '';
    this.selectedDeveloper    = '';
    this.selectedLocation     = '';
    this.dynamicFilterValues  = {};
  }

  handleProjectChange(e){   this.selectedProject   = e.detail.value; }
  handleDeveloperChange(e){ this.selectedDeveloper = e.detail.value; }
  handleLocationChange(e){  this.selectedLocation  = e.detail.value; }

  handleDynamicInput(e) {
    const api = e.target.dataset.field;
    this.dynamicFilterValues = { ...this.dynamicFilterValues, [api]: e.detail.value };
  }

  /* ───────── Search click ───────── */
  filterAndClosePanel() {
     const hasProject   = !!this.selectedProject;
      const hasDeveloper = !!this.selectedDeveloper;

      if (!hasProject && !hasDeveloper) {
        this.showError('Selection required', { body: { message: 'Pick either a Project or a Developer to search.' }});
        return;
      }
    const cleanDynamic = Object.fromEntries(
      Object.entries(this.dynamicFilterValues).filter(([, v]) => isReal(v))
    );

    const filters = {
      ...(isReal(this.selectedDeveloper) ? { Developer_Name__c: this.selectedDeveloper } : {}),
      ...(isReal(this.selectedLocation)  ? { Location__c      : this.selectedLocation  } : {}),
      ...cleanDynamic
    };

    this.showFilters     = false;
    this.hasUserSearched = true;

    this.fetchSummary();
    this.fetchAndBuildTiles(filters);
  }

  /* ───────── summary counters (top-level only) ───────── */
  fetchSummary() {
    const proj = this.selectedProject || null;
    const dev  = isReal(this.selectedDeveloper) ? this.selectedDeveloper : null;
    const loc  = isReal(this.selectedLocation)  ? this.selectedLocation  : null;

    getTotalUnitCount({ proj, dev, loc }).then(c   => this.totalUnits      = c).catch(e => this.showError('Count failed', e));
    getTotalSAR      ({ proj, dev, loc }).then(sum => this.totalSalesPrice = sum).catch(e => this.showError('Sum failed', e));
  }

  /* ───────── main query + tiles ───────── */
  fetchAndBuildTiles(filters) {
    const proj = this.selectedProject || null;

    getAllStatusLabels()
      .then(statusList => {
        return getUnits({ proj, filters }).then(wrap => ({ statusList, wrap }));
      })
      .then(({ statusList, wrap }) => {
        const units = (wrap && wrap[0]) ? wrap[0] : [];

        // Build base tile map for all active statuses
        const tileMap = {};
        (statusList || []).forEach(s => { tileMap[s] = { label: s, count: 0, totalPrice: 0 }; });

        if (!units.length) {
          this.unitRecords  = [];
          this.statusCounts = Object.values(tileMap).map(t => ({
            ...t,
            totalPriceFormatted: 'AED 0.00'
          }));
          return;
        }

        const unitIds = new Set();

        // First pass: accumulate tiles & collect IDs
        units.forEach(u => {
          const st = u.Status__c || '';
          if (!tileMap[st]) tileMap[st] = { label: st, count: 0, totalPrice: 0 };

          const price = Number(u.CD_Sales_Price__c || 0);
          tileMap[st].count += 1;
          tileMap[st].totalPrice += price;

          unitIds.add(u.Id);
        });

        // Fetch images then compose records
        return getListingImages({ unitIds: Array.from(unitIds) })
          .then(imgMap => {
            this.unitRecords = units.map(u => {
              const projName = (u.Project__r && u.Project__r.Name) ? u.Project__r.Name : '';
              const areaValPresent = (u.Total_Area_SQ_FT__c !== undefined && u.Total_Area_SQ_FT__c !== null);
              const areaVal = areaValPresent ? u.Total_Area_SQ_FT__c : '';
              return {
                ...u,
                imageUrl: (imgMap && imgMap[u.Id]) ? imgMap[u.Id] : FALLBACK_IMG,
                // Precompute class for template usage: {unit.statusClass}
                statusClass: 'status-' + (u.Status__c || '').replace(/\s+/g, ''),
                projectName: projName,
                salesPriceFormatted: Number(u.CD_Sales_Price__c || 0).toLocaleString('en-US'),
                formattedArea: `${areaVal} ${u.SQM__c ? 'sqm' : 'sqft'}`
              };
            });

            this.statusCounts = Object.values(tileMap).map(t => ({
              ...t,
              totalPriceFormatted:
                'AED ' + Number(t.totalPrice).toLocaleString('en-US', { minimumFractionDigits: 2 })
            }));
          });
      })
      .catch(e => this.showError('Failed to load units/tiles', e));
  }

  /* ───────── helpers / getters ───────── */
  get formattedTotalSalesPrice() {
    return 'AED ' + Number(this.totalSalesPrice)
             .toLocaleString('en-US', { minimumFractionDigits: 2 });
  }

  get showNoUnitsMessage() { return this.hasUserSearched && !(this.unitRecords && this.unitRecords.length); }

  get visibleStatusCounts() {
    const chosen = this.dynamicFilterValues['Status__c'];
    if (!this.hasUserSearched) return [];
    if (isReal(chosen)) {
      const match = this.statusCounts.find(t => t.label === chosen);
      return match ? [match] : [{ label: chosen, count: 0, totalPrice: 0, totalPriceFormatted: 'AED 0.00' }];
    }
    return this.statusCounts;
  }

  get statusBadgesClass() {
    return (this.visibleStatusCounts.length <= 1)
      ? 'status-badges status-center'
      : 'status-badges';
  }

  // If your template still calls {getStatusClass(unit.Status__c)} it won’t work in LWC.
  // Use {unit.statusClass} instead (precomputed above). Keeping this here for reference.
  getStatusClass(status) { return 'status-' + String(status || '').replace(/\s+/g, ''); }

  get searchDisabled() {
    // Enforce “select Project or Developer” before searching
    return !(this.selectedProject || this.selectedDeveloper);
  }

  /* ───────── modal (detail view) ───────── */
  openUnitModal(unitId, name) {
    this.modalUnitId = unitId;
    this.modalUnitName = name;
    this.showUnitModal = true;
    getUnitFieldSetValues({ unitId, fieldSetApiName: 'Unit_Table' })
    .then(fields => { this.modalFields = fields || []; })
    .catch(err => this.showError('Failed to load Unit_Table fields', err));

    try {
      document.body.scrollTop = 0;
      document.documentElement.scrollTop = 0;
      document.body.style.overflow = 'hidden';
      document.body.classList.add('modal-open');
    } catch (e) {
      // ignore SSR / locker quirks
    }

    getMobileFields({ unitId })
      .then(fields => {
        this.modalFields = fields || [];
        if (!this.modalFields.length) this.showToast('No fields returned for this unit.');
      })
      .catch(err => this.showError('Failed to load unit details', err));
  }

  closeUnitModal() {
    this.showUnitModal = false;
    this.modalFields = [];
    this.modalUnitId = '';
    this.modalUnitName = '';

    try {
      document.body.classList.remove('modal-open');
      document.body.style.overflow = '';
    } catch (e) {
      // ignore
    }
  }

  handleUnitClick(event) {
    const unitId = event.currentTarget.dataset.unitId;
    const name   = event.currentTarget.dataset.unitName;
    this.openUnitModal(unitId, name);
  }

  /* Template compat: your markup uses if:true={isUnitModalOpen} */
  get isUnitModalOpen() { return this.showUnitModal; }

  /* ───────── toasts ───────── */
  showError(title, err) {
    this.dispatchEvent(new ShowToastEvent({
      title,
      message : err?.body?.message || (typeof err === 'string' ? err : JSON.stringify(err)),
      variant : 'error'
    }));
  }

  showToast(msg) {
    this.dispatchEvent(new ShowToastEvent({
      title: 'Notice',
      message: msg,
      variant: 'warning'
    }));
  }
}
