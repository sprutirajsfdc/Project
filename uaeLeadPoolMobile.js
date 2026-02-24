import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPropertiesUAEKeyset from '@salesforce/apex/LeadControllerMobile.getPropertiesUAEKeyset';
import getPicklistValues from '@salesforce/apex/LeadControllerMobile.getPicklistValues';
import getCommunityFacets from '@salesforce/apex/LeadControllerMobile.getCommunityFacets';

// Constants
const PERSIST_KEY = 'uaeLeadPoolMobile.filters.v2';
const PAGE_SIZE = 25;
const DEBOUNCE_DELAY = 300;
const OWNER_HUES = ['hue-1', 'hue-2', 'hue-3', 'hue-4', 'hue-5', 'hue-6'];
const DEFAULT_PICKLIST_OPTION = { label: '--None--', value: '' };

export default class UkLeadPoolMobile extends NavigationMixin(LightningElement) {
  // State management
  @track showFilters = true;
  @track rows = [];
  @track pageNumber = 1;
  @track communities = [];
  @track subCommunities = [];
  @track communityOptions = [];
  @track subCommunityOptions = [];
  @track showCommunityDropdown = false;
  @track showSubCommunityDropdown = false;
  @track backwardCursor = null;  // NEW: For backward pagination

  loading = false;
  hasSearched = false;
  hasMore = false;
  cursor = null;
  nextCursor = null;
  totalRecords = 0;

  // Filter state (unchanged)
  nameOrRef = '';
  inquiryType = '';
  status = '';
  subStatus = '';
  propertyType = '';
  priceMin = '';
  priceMax = '';
  bedMin = '';
  bedMax = '';
  createdStart = '';
  createdEnd = '';
  communityQuery = '';
  subCommunityQuery = '';

  // Data options (unchanged)
  allSubCommunityOptions = [];
  typeOptions = [];
  inquiryOptionsFiltered = [];
  statusOptionsFiltered = [];
  subStatusOptionsFiltered = [];

  viewMode = 'card';
  columns = [
    { label: 'Inquiry', fieldName: 'Name' },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Sub Status', fieldName: 'Sub_Status__c' },
    { label: 'Type', fieldName: 'Inquiry_Type__c' },
    { label: 'Property', fieldName: 'Property_Type__c' },
    { label: 'Bedrooms', fieldName: 'BedroomsRange' },
    { label: 'Budget', fieldName: 'BudgetRange' },
    { label: 'Owner', fieldName: 'ownerDisplay' },
    { label: 'Created', fieldName: 'CreatedDateFormatted' },
    { type: 'button', typeAttributes: { label: 'View', name: 'view', variant: 'brand-outline' } }
  ];

  // Debounce timers (unchanged)
  _communitySearchTimeout;
  _subCommunitySearchTimeout;

  connectedCallback() {
    this.initializeComponent();
  }


  getStatusStyle(status) {
    const styleMap = {
      'New Lead': 'background-color: #fff3cd; color: #856404; --dot-color: #ffc107;', // Bright yellow
      'Engaged': 'background-color: #fff3cd; color: #856404; --dot-color: #ffc107;', // Bright yellow
      'Viewing': 'background-color: #fff3cd; color: #856404; --dot-color: #ffc107;', // Bright yellow
      'Won': 'background-color: #d4edda; color: #155724; --dot-color: #28a745;', // Bright green
      'Lost': 'background-color: #f8d7da; color: #721c24; --dot-color: #dc3545;', // Bright red
      'Offering': 'background-color: #fff3cd; color: #856404; --dot-color: #ffc107;' // Bright yellow
    };
    return styleMap[status] || 'background-color: #fff3cd; color: #856404; --dot-color: #ffc107;';
  }

  getStatusDateStyle(status) {
    const colorMap = {
      'New': '#856404',
      'In-Progress': '#856404',
      'Closed': '#856404',
      'Won': '#155724',
      'Lost': '#721c24',
      'Pending': '#856404'
    };
    return `color: ${colorMap[status] || '#856404'}`;
  }

  // Initialization (unchanged)
  initializeComponent() {
    try {
      window.localStorage?.removeItem(PERSIST_KEY);
      this.resetState();
      this.loadFacets();
    } catch (error) {
      console.error('Error in connectedCallback:', error);
    }
  }

  resetState() {
    this.nameOrRef = '';
    this.communities = [];
    this.subCommunities = [];
    this.inquiryType = '';
    this.status = '';
    this.subStatus = '';
    this.propertyType = '';
    this.priceMin = '';
    this.priceMax = '';
    this.bedMin = '';
    this.bedMax = '';
    this.createdStart = '';
    this.createdEnd = '';
    this.communityQuery = '';
    this.subCommunityQuery = '';
    this.showCommunityDropdown = false;
    this.showSubCommunityDropdown = false;
    this.rows = [];
    this.pageNumber = 1;
    this.cursor = null;
    this.nextCursor = null;
    this.backwardCursor = null;  // NEW
    this.hasMore = false;
    this.totalRecords = 0;
    this.hasSearched = false;
    this.showFilters = true;
  }

  // Data loading methods (unchanged)
  async loadFacets() {
    try {
      const data = await getCommunityFacets({
        communitySearchInput: this.communityQuery,
        subCommunitySearchInput: this.subCommunityQuery
      });

      this.communityOptions = data?.communities || [];
      this.allSubCommunityOptions = data?.subCommunities || [];

      // Debug logs to verify data
      console.log('Community options:', this.communityOptions);
      console.log('Sub-community options:', this.allSubCommunityOptions);
      console.log('Sub-community query:', this.subCommunityQuery);

    } catch (error) {
      console.error('Error loading community facets:', error);
    }
  }

  // Wire adapters for picklist values (unchanged)
  @wire(getPicklistValues, { objectApiName: 'Inquiry__c', fieldApiName: 'Property_Type__c' })
  typeOptionsHandler({ data, error }) {
    if (data) {
      this.typeOptions = [DEFAULT_PICKLIST_OPTION, ...data];
    }
    if (error) console.error(error);
  }

  @wire(getPicklistValues, { objectApiName: 'Inquiry__c', fieldApiName: 'Inquiry_Type__c' })
  inquiryOptionsHandler({ data, error }) {
    if (data) {
      this.inquiryOptionsFiltered = [
        DEFAULT_PICKLIST_OPTION,
        ...data.filter(opt =>
          ['buyer', 'tenant'].includes(String(opt.value || opt.label || '').toLowerCase())
        )
      ];
    }
    if (error) console.error(error);
  }

  @wire(getPicklistValues, { objectApiName: 'Inquiry__c', fieldApiName: 'Status__c' })
  statusOptionsHandler({ data, error }) {
    if (data) {
      this.statusOptionsFiltered = [
        DEFAULT_PICKLIST_OPTION,
        ...data.filter(opt => {
          const value = String(opt.value || opt.label || '').toLowerCase();
          return value !== 'won' && value !== 'offering' 
        })
      ];
    }
    if (error) console.error(error);
  }

  @wire(getPicklistValues, { objectApiName: 'Inquiry__c', fieldApiName: 'Sub_Status__c' })
  subStatusOptionsHandler({ data, error }) {
    if (data) {
      this.subStatusOptionsFiltered = [DEFAULT_PICKLIST_OPTION, ...data];
    }
    if (error) console.error(error);
  }

  // Input handlers (unchanged)
  onChangeName = (e) => { this.nameOrRef = e.target.value || ''; }
  onChangeInquiryType = (e) => { this.inquiryType = e.detail.value || ''; }
  onChangeStatus = (e) => { this.status = e.detail.value || ''; }
  onChangeSubStatus = (e) => { this.subStatus = e.detail.value || ''; }
  onChangePropertyType = (e) => { this.propertyType = e.detail.value || ''; }
  onChangePriceMin = (e) => { this.priceMin = e.target.value; }
  onChangePriceMax = (e) => { this.priceMax = e.target.value; }
  onChangeBedMin = (e) => { this.bedMin = e.target.value; }
  onChangeBedMax = (e) => { this.bedMax = e.target.value; }
  onChangeCreatedStart = (e) => { this.createdStart = this.toYmd(e.target.value); }
  onChangeCreatedEnd = (e) => { this.createdEnd = this.toYmd(e.target.value); }

  // Community management (unchanged - FIXED DROPDOWN ISSUES)
  focusCommunityInput = () => {
    console.log('focusCommunityInput called');
    const input = this.template.querySelector('.tokenselect__input');
    if (input) {
      input.focus();
    }
    this.showCommunityDropdown = true;
    console.log('showCommunityDropdown set to:', this.showCommunityDropdown);
  };

  onCommunityQuery = (event) => {
    this.communityQuery = event.target.value;
    this.showCommunityDropdown = true;
    this.debounce(this.loadFacets.bind(this), DEBOUNCE_DELAY, '_communitySearchTimeout');
  };

  onCommunityKeydown = (e) => {
    switch (e.key) {
      case 'Enter':
        e.preventDefault();
        this.addFirstCommunityOption();
        break;
      case 'Escape':
        this.showCommunityDropdown = false;
        break;
      case 'Backspace':
        if (!this.communityQuery && this.communities.length) {
          this.communities = this.communities.slice(0, -1);
        }
        break;
    }
  };

  addFirstCommunityOption() {
    const firstOption = this.communityFiltered[0];
    if (firstOption) {
      this.addCommunity(firstOption.value);
    }
  }

  addCommunity(value) {
    if (!this.communities.includes(value)) {
      this.communities = [...this.communities, value];
    }
    this.communityQuery = '';
    this.showCommunityDropdown = false;
  }

  removeCommunity = (e) => {
    const value = e.currentTarget?.dataset?.value;
    this.communities = this.communities.filter(v => v !== value);
  };

  pickCommunity = (e) => {
    const value = e.currentTarget?.dataset?.value;
    if (value) this.addCommunity(value);
  };

  // Sub-community management (unchanged)
  focusSubCommunityInput = () => {
    const inputs = this.template.querySelectorAll('.tokenselect__input');
    const subCommunityInput = inputs[1];
    if (subCommunityInput) {
      subCommunityInput.focus();
    }
    this.showSubCommunityDropdown = true;
  };

  onSubCommunityQuery = (event) => {
    this.subCommunityQuery = event.target.value;
    this.showSubCommunityDropdown = true;

    // Clear any pending timeout first
    if (this._subCommunitySearchTimeout) {
      clearTimeout(this._subCommunitySearchTimeout);
    }

    // Set a new timeout for debouncing
    this._subCommunitySearchTimeout = setTimeout(() => {
      this.loadFacets();
    }, DEBOUNCE_DELAY);
  };

  onSubCommunityKeydown = (e) => {
    switch (e.key) {
      case 'Enter':
        e.preventDefault();
        this.addFirstSubCommunityOption();
        break;
      case 'Escape':
        this.showSubCommunityDropdown = false;
        break;
      case 'Backspace':
        if (!this.subCommunityQuery && this.subCommunities.length) {
          this.subCommunities = this.subCommunities.slice(0, -1);
          this.searchFresh();
        }
        break;
    }
  };

  addFirstSubCommunityOption() {
    const firstOption = this.subCommunityFiltered[0];
    if (firstOption) {
      this.addSubCommunity(firstOption.value);
    }
  }

  addSubCommunity(value) {
    if (!this.subCommunities.includes(value)) {
      this.subCommunities = [...this.subCommunities, value];
    }
    this.subCommunityQuery = '';
    this.showSubCommunityDropdown = false;
    this.searchFresh();
  }

  removeSubCommunity = (e) => {
    const value = e.currentTarget?.dataset?.value;
    this.subCommunities = this.subCommunities.filter(v => v !== value);
    this.searchFresh();
  };

  pickSubCommunity = (e) => {
    const value = e.currentTarget?.dataset?.value;
    if (value) this.addSubCommunity(value);
  };

  // Search and pagination
  handleSearch = () => {
    this.searchFresh();
  };

  searchFresh() {
    this.cursor = null;
    this.nextCursor = null;
    this.backwardCursor = null;  // NEW
    this.pageNumber = 1;
    this.hasMore = false;
    this.totalRecords = 0;
    this.rows = [];
    this.search(true);
  }

  async search(isFirstPage = false) {
    this.loading = true;
    this.hasSearched = true;

    try {
      const filter = this.buildFilter();
      const cursorToUse = this.buildCursor();

      const result = await getPropertiesUAEKeyset({
        f: JSON.parse(JSON.stringify(filter)),
        c: cursorToUse
      });

      this.processSearchResult(result, isFirstPage);

    } catch (error) {
      console.error('Search error', error);
      this.handleSearchError();
    } finally {
      this.loading = false;
    }
  }

  buildFilter() {
    return {
      nameOrRef: this.trimOrNull(this.nameOrRef),
      communities: this.communities.filter(Boolean),
      subCommunities: this.subCommunities.filter(Boolean),
      inquiryType: this.trimOrNull(this.inquiryType),
      status: this.trimOrNull(this.status),
      subStatus: this.trimOrNull(this.subStatus),
      propertyType: this.trimOrNull(this.propertyType),
      priceMin: this.toNumberOrNull(this.priceMin),
      priceMax: this.toNumberOrNull(this.priceMax),
      bedMin: this.toNumberOrNull(this.bedMin),
      bedMax: this.toNumberOrNull(this.bedMax),
      createdStart: this.trimOrNull(this.createdStart),
      createdEnd: this.trimOrNull(this.createdEnd),
      applyBaseline: true
    };
  }

  // buildCursor() {
  //   return {
  //     lastCreatedDate: this.cursor?.lastCreatedDate || null,
  //     lastId: this.cursor?.lastId || null,
  //     pageSize: PAGE_SIZE,
  //     forward: this.cursor?.forward ?? true,
  //     pageNumber: this.cursor?.pageNumber || 1
  //   };
  // }

buildCursor() {
    return {
      lastCreatedDate: this.cursor?.lastCreatedDate || null,
      lastId: this.cursor?.lastId || null,
      pageSize: PAGE_SIZE,
      forward: this.cursor?.forward ?? true,
      pageNumber: this.pageNumber   // ⬅️ ALWAYS USE CURRENT PAGE
    };
}


  processSearchResult(result, isFirstPage) {
    this.rows = this.transformRecords(result?.records || []);
   if (isFirstPage) {
    this.totalRecords = result.totalRecords || 0;
}

    this.hasMore = result?.hasMore === true;

    this.initializeCursor(result);
    this.updateNextCursor(result);


    // 🔥 FIX: Rebuild nextCursor when returning to Page 1
    if (this.pageNumber === 1 && this.rows.length > 0) {
      const last = this.rows[this.rows.length - 1];
      this.nextCursor = {
        lastCreatedDate: last.CreatedDate,
        lastId: last.Id,
        pageSize: PAGE_SIZE,
        forward: true,
        pageNumber: 2
      };
    }


    // NEW: Set backward cursor to first row (newest in DESC order)
    if (this.rows.length > 0) {
      this.backwardCursor = {
        lastCreatedDate: this.rows[0].CreatedDate,
        lastId: this.rows[0].Id,
        forward: false,
        pageNumber: this.pageNumber
      };
    } else {
      this.backwardCursor = null;
    }

    if (isFirstPage) {
      this.pageNumber = 1;
    }

    // this.showFilters = false;
  }

  transformRecords(records) {
    return records.map(record => {
      const ownerDisplay = record?.Owner?.Name || 'Unassigned';
      return {
        ...record,
        CreatedDateFormatted: this.formatDT(record.CreatedDate),
        Price_Min_Formatted: this.formatCurrency(record.Price_min__c),
        Price_Max_Formatted: this.formatCurrency(record.Price_max__c),
        BudgetRange: `${this.formatCurrency(record.Price_min__c)} - ${this.formatCurrency(record.Price_max__c)}`,
        BedroomsRange: `${record.Bedrooms_min__c || ''}-${record.Bedrooms_max__c || ''}`,
        ownerDisplay,
        ownerInitials: this.initials(ownerDisplay),
        ownerHueClass: OWNER_HUES[this.strHash(ownerDisplay) % OWNER_HUES.length],
        statusBadgeStyle: this.getStatusStyle(record.Status__c),
        statusDateStyle: this.getStatusDateStyle(record.Status__c),
        OwnerName: record.Owner?.Name || 'Unassigned',
        showLostReason: record.Status__c === 'Lost' && record.Lost_Reason__c,
        Lost_Reason__c: record.Lost_Reason__c || ''
      };
    });
  }

  initializeCursor(result) {
    if (!this.cursor && result.records && result.records.length > 0) {
      const firstRecord = result.records[0];
      this.cursor = {
        lastCreatedDate: firstRecord.CreatedDate,
        lastId: firstRecord.Id,
        pageSize: PAGE_SIZE,
        forward: true,
        pageNumber: 1
      };
    }
  }

  updateNextCursor(result) {
    if (this.hasMore && result.nextCreatedDate && result.nextId) {
      this.nextCursor = {
        lastCreatedDate: result.nextCreatedDate,
        lastId: result.nextId,
        pageSize: PAGE_SIZE,
        forward: true,
        pageNumber: this.pageNumber + 1
      };
    } else {
      this.nextCursor = null;
    }
  }

  handleSearchError() {
    this.rows = [];
    this.hasMore = false;
    this.nextCursor = null;
    this.backwardCursor = null;  // NEW
  }

  // Pagination - FIXED
  // previousPage = () => {
  //   if (this.pageNumber <= 1 || !this.backwardCursor) {
  //     console.warn('⚠️ [PREV] Already at first page — cannot go back.');
  //     return;
  //   }

  //   // Use backward cursor (first of current page) with forward=false to fetch previous batch
  //   this.cursor = {
  //     lastCreatedDate: this.backwardCursor.lastCreatedDate,
  //     lastId: this.backwardCursor.lastId,
  //     pageSize: PAGE_SIZE,
  //     forward: false,
  //     pageNumber: this.pageNumber - 1
  //   };

  //   this.pageNumber -= 1;
  //   this.search(false);
  // };


  previousPage = () => {
    if (this.pageNumber <= 1 || !this.backwardCursor) {
      console.warn('⚠️ [PREV] Already at first page — cannot go back.');
      return;
    }

    const newPage = this.pageNumber - 1;

    this.cursor = {
      lastCreatedDate: this.backwardCursor.lastCreatedDate,
      lastId: this.backwardCursor.lastId,
      pageSize: PAGE_SIZE,
      forward: false,
      pageNumber: newPage === 1 ? 1 : newPage  // ⚠️ FORCE PAGE 1
    };

    this.pageNumber = newPage;
    this.search(false);
};


  nextPage = () => {
    if (!this.nextCursor) return;

    // UPDATED: No prevStack push needed
    this.cursor = {
      ...this.nextCursor,
      forward: true,
      pageSize: PAGE_SIZE,
      pageNumber: this.pageNumber + 1
    };
    this.pageNumber += 1;

    this.search(false);
  };

  // UI actions (unchanged)
  handleReset = () => {
    this.resetState();
    try {
      window.localStorage?.removeItem(PERSIST_KEY);
    } catch (e) {
      // Silent fail
    }
  };

  reopenFilters = () => {
    this.showFilters = true;
  };

  setCardView = () => {
    this.viewMode = 'card';
  };

  setTableView = () => {
    this.viewMode = 'table';
  };

  // Navigation (unchanged)
  openRecord = (e) => {
    const recordId = e.currentTarget?.dataset?.id;
    if (recordId) {
      this.navigateToRecord(recordId);
    }
  };

  handleRowAction = (e) => {
    const { action, row } = e.detail || {};
    if (action?.name === 'view' && row?.Id) {
      this.navigateToRecord(row.Id);
    }
  };

  navigateToRecord(recordId) {
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        objectApiName: 'Inquiry__c',
        actionName: 'view'
      }
    });
  }

  // Card flip animation (unchanged)
  flipThenOpen = (evt) => {
    const card = evt.currentTarget;
    if (!card) return;

    card.classList.add('flip');
    const recordId = card?.dataset?.id;

    setTimeout(() => {
      card.classList.remove('flip');
      if (recordId) {
        window.open(`/lightning/r/Inquiry__c/${recordId}/view`, '_blank');
      }
    }, 320);
  };

  flipThenOpenByKey = (evt) => {
    if (evt.key === 'Enter' || evt.key === ' ') {
      evt.preventDefault();
      this.flipThenOpen(evt);
    }
  };

  // Utility methods (unchanged)
  debounce(func, delay, timeoutProperty) {
    clearTimeout(this[timeoutProperty]);
    this[timeoutProperty] = setTimeout(func, delay);
  }

  trimOrNull(value) {
    const trimmed = String(value ?? '').trim();
    return trimmed === '' ? null : trimmed;
  }

  toNumberOrNull(value) {
    if (value == null) return null;
    const stringValue = String(value).trim();
    if (stringValue === '') return null;
    const numberValue = Number(stringValue);
    return Number.isFinite(numberValue) ? numberValue : null;
  }

  toYmd(dateString) {
    if (!dateString) return '';
    const match = String(dateString).match(/^(\d{4})-(\d{2})-(\d{2})$/);
    return match ? `${match[1]}-${match[2]}-${match[3]}` : '';
  }

  formatDT(dateTimeString) {
    if (!dateTimeString) return '';

    try {
      const date = new Date(dateTimeString);
      if (isNaN(date.getTime())) return '';

      return new Intl.DateTimeFormat('en-GB', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      }).format(date).replace(',', '');
    } catch {
      return '';
    }
  }

  formatCurrency(amount) {
    const numberAmount = Number(amount);
    if (!Number.isFinite(numberAmount)) return '';

    try {
      return new Intl.NumberFormat('en-GB', {
        style: 'currency',
        currency: 'AED',
        maximumFractionDigits: 0
      }).format(numberAmount);
    } catch {
      return String(numberAmount);
    }
  }

  initials(name) {
    if (!name) return '-';
    const parts = String(name).trim().split(/\s+/).slice(0, 2);
    return parts.map(part => part[0]?.toUpperCase() || '').join('') || '-';
  }

  strHash(string = '') {
    let hash = 2166136261;
    for (let i = 0; i < string.length; i++) {
      hash ^= string.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  // Computed properties (unchanged)
  get communityFiltered() {
    if (!this.communityQuery) {
      return this.communityOptions || [];
    }

    const query = this.communityQuery.toLowerCase().trim();
    return (this.communityOptions || []).filter(opt =>
      String(opt.label || '').toLowerCase().includes(query) ||
      String(opt.value || '').toLowerCase().includes(query)
    );
  }

  get subCommunityFiltered() {
    if (!this.subCommunityQuery) {
      return this.allSubCommunityOptions || [];
    }

    const query = this.subCommunityQuery.toLowerCase().trim();
    return (this.allSubCommunityOptions || []).filter(opt =>
      String(opt.label || '').toLowerCase().includes(query) ||
      String(opt.value || '').toLowerCase().includes(query)
    );
  }

  get isFirstPage() {
    return this.pageNumber === 1;
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get disableFirst() {
    return this.pageNumber <= 1 || this.loading;
  }

  get disableLast() {
    return !this.hasMore || this.loading;
  }

  get isCardView() {
    return this.viewMode === 'card';
  }

  get cardBtnVariant() {
    return this.isCardView ? 'brand' : 'neutral';
  }

  get tableBtnVariant() {
    return this.isCardView ? 'neutral' : 'brand';
  }
}
