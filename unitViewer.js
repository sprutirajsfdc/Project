import { LightningElement, track, wire } from 'lwc';
import getExclusiveProjects from '@salesforce/apex/UnitController.getExclusiveProjects';
import getUnits from '@salesforce/apex/UnitController.getUnits';
import getFieldSetFieldsWithLabel from '@salesforce/apex/UnitController.getFieldSetFieldsWithLabel';
import getPicklistValues from '@salesforce/apex/UnitController.getPicklistValues';
import getUserProfileName from '@salesforce/apex/UnitController.getUserProfileName';
import getDeveloper from '@salesforce/apex/UnitController.getDeveloper';
import getLocation from '@salesforce/apex/UnitController.getLocation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import { updateRecord } from 'lightning/uiRecordApi';
import UNIT_ID from '@salesforce/schema/Unit__c.Id';

import UNIT_NAME from '@salesforce/schema/Unit__c.Name';
import INTERNAL_AREA from '@salesforce/schema/Unit__c.Internal_Area__c';
import EXTERNAL_AREA from '@salesforce/schema/Unit__c.Balcony_Area__c';
import TOTAL_PRICE from '@salesforce/schema/Unit__c.Unit_Price_AED__c';
import STATUS from '@salesforce/schema/Unit__c.Status__c';
import PROJECT from '@salesforce/schema/Unit__c.Project__r.Name';
import TOTAL_SQFT from '@salesforce/schema/Unit__c.Total_Area_SQ_FT__c';
import SIZE from '@salesforce/schema/Unit__c.CD_Size_pb__c';
import UNIT_TYPE from '@salesforce/schema/Unit__c.CD_Unit_Type__c';
import getTotalUnitCount from '@salesforce/apex/UnitController.getTotalUnitCount';
import getTotalSAR from '@salesforce/apex/UnitController.getTotalSAR';


const FIELDS = [
    UNIT_NAME, INTERNAL_AREA, EXTERNAL_AREA, TOTAL_PRICE,
    STATUS, PROJECT, TOTAL_SQFT, SIZE, UNIT_TYPE
];

export default class UnitViewer extends NavigationMixin(LightningElement) {
    @track projectOptions = [];
    @track statusOptions = [];
    @track currencyOptions = [];
    @track viewOptions = [];
    @track developerOptions = [];
    @track locationOptions = [];

    @track selectedProject;
    @track totalSalesPrice = 0;
    @track selectedLocation;
    @track filters = {};
    @track units = [];
    @track columns = [];
    @track mobileColumns = [];
    @track selectedDeveloper;
    @track allProjects = [];
    get isUnitListEmpty() {
        return this.units && this.units.length === 0;
    }
    @track statusCounts = [];
    @track totalUnits = 0;
    @track isSalesAgent = false;

    @track unitDetails = {};
    @track selectedUnitId;
    @track isModalOpen = false;
    @track isMobile = false;
    @track disablePrev = false;
    @track disableNext = false;

    @track pageSize = 100;
    @track pageSizeOptions = [
        { label: '10', value: 10 },
        { label: '20', value: 20 },
        { label: '50', value: 50 },
        { label: '100', value: 100 },
        { label: '200', value: 200 }
    ];

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.pageNumber = 1;
        this.loadUnits();
    }

    fieldLabelMap = {};

    //====== Mobile view filter panel Start =======
    @track showPanel = false;
    @track mobileRecordDetail = false;

    togglePanel() {
        this.showPanel = true;
        this.pageNumber = 1;
        this.units = [];
        this.columns = [];
        this.mobileColumns = [];
        this.totalUnits = 0;
        this.totalSalesPrice = 0;
        this.statusCounts = [];
    }

    filterAndClosePanel() {
        this.showPanel = false;
        this.loadUnits();
    }

    closePanel() {
        this.showPanel = false;
    }

    //====== Mobile view filter panel End =======

    @wire(getDeveloper)
    wiredDevelopers({ error, data }) {
        if (data) {
            this.developerOptions = [
                { label: 'All', value: 'All' },
                ...data.map(name => ({ label: name, value: name }))
            ];
        } else if (error) {
            console.error('Error fetching developers', error);
        }
    }

    @wire(getLocation)
    wiredLocation({ error, data }) {
        if (data) {
            this.locationOptions = [
                { label: 'All', value: 'All' },
                ...data.map(loc => ({ label: loc, value: loc }))
            ];
        } else if (error) {
            console.error('Error fetching locations', error);
        }
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;
        this.pageNumber = 1;
        if (!this.showPanel) this.loadUnits();
    }

    handleDeveloperChange(event) {
        this.selectedDeveloper = event.detail.value;
        this.filterProjects();
        if ((this.selectedProject || this.selectedDeveloper) && !this.showPanel) this.loadUnits();
    }

    handleLocationChange(event) {
        this.selectedLocation = event.detail.value;
        this.filterProjects();
        if ((this.selectedProject || this.selectedDeveloper) && !this.showPanel) this.loadUnits();
    }

    filterProjects() {
        let filtered = [...this.allProjects];

        if (this.selectedDeveloper && this.selectedDeveloper !== 'All') {
            filtered = filtered.filter(p =>
                p.Developer_Name__c?.toLowerCase() === this.selectedDeveloper?.toLowerCase()
            );
        }

        if (this.selectedLocation && this.selectedLocation !== 'All') {
            filtered = filtered.filter(p => p.Location__c === this.selectedLocation);
        }

        this.projectOptions = filtered.map(p => ({
            label: p.Name,
            value: p.Id
        }));

        if (!filtered.some(p => p.Id === this.selectedProject)) {
            this.selectedProject = '';
            this.units = [];
            this.columns = [];
            this.mobileColumns = [];
        }
    }

    connectedCallback() {
        this.loadProjects();
        this.loadPicklists();
        this.isMobile = window.matchMedia('(max-width: 768px)').matches;
    }

    loadProjects() {
        getExclusiveProjects()
            .then(data => {
                if (!data || data.length === 0) {
                    this.projectOptions = [{ label: 'No Projects Available', value: '' }];
                    return;
                }
                this.allProjects = data;
                this.projectOptions = data.map(p => ({
                    label: p.Name,
                    value: p.Id
                }));
            })
            .catch(error => {
                console.error('Error loading projects', error);
                this.projectOptions = [{ label: 'Error loading projects', value: '' }];
            });
    }

    loadPicklists() {
        getUserProfileName()
            .then(profileName => {
                this.isSalesAgent = profileName === 'Sales Agent';
                return getPicklistValues({ objectApiName: 'Unit__c', fieldApiName: 'Status__c' });
            })
            .then(data => {
                let filteredOptions = data;
                if (this.isSalesAgent) {
                    filteredOptions = data.filter(opt => ['Available', 'Sold'].includes(opt.value));
                }
                this.statusOptions = [{ label: 'All', value: 'All' }, ...filteredOptions];
            })
            .catch(error => console.error('Error loading profile or status options:', error));

        getPicklistValues({ objectApiName: 'Unit__c', fieldApiName: 'View__c' })
            .then(data => {
                this.viewOptions = [{ label: 'All', value: 'All' }, ...data];
            });

        getPicklistValues({ objectApiName: 'Unit__c', fieldApiName: 'CurrencyIsoCode' })
            .then(data => this.currencyOptions = data);
    }

    get formattedTotalSalesPrice() {
        return this.formatCurrency(this.totalSalesPrice);
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-SA', {
            style: 'currency',
            currency: 'AED',
            minimumFractionDigits: 2
        }).format(amount);
    }

    updateFilter(key, value) {
        if (value) {
            this.filters = { ...this.filters, [key]: value };
        } else {
            const newFilters = { ...this.filters };
            delete newFilters[key];
            this.filters = newFilters;
        }
        this.pageNumber = 1;
        if (!this.showPanel) this.loadUnits();
    }

    @track unit_Status_Input;
    @track unit_View_Input;
    @track unit_Number_Input;
    @track unit_Tower_Input;
    @track unit_Bedroom_Input;

    handleStatusSearch(event) {
        this.updateFilter('Status__c', event.detail.value);
        this.unit_Status_Input = event.detail.value;
    }
    handleCurrencySearch(event) {
        this.updateFilter('CurrencyIsoCode', event.detail.value);
    }
    handleViewSearch(event) {
        this.updateFilter('View__c', event.detail.value);
        this.unit_View_Input = event.detail.value;
    }
    handleUnitnoChange(event) {
        this.updateFilter('Unit_Number__c', event.target.value);
        this.unit_Number_Input = event.detail.value;
    }
    handletoweroChange(event) {
        this.updateFilter('CD_Tower__c', event.target.value);
        this.unit_Tower_Input = event.detail.value;
    }
    handleBedroomChange(event) {
        this.updateFilter('CD_Bedrooms__c', event.target.value);
        this.unit_Bedroom_Input = event.detail.value;
    }

    handleResetFilters() {
        this.selectedProject = '';
        this.selectedDeveloper = '';
        this.selectedLocation = '';
        this.unit_Status_Input = '';
        this.unit_View_Input = '';
        this.unit_Number_Input = '';
        this.unit_Tower_Input = '';
        this.unit_Bedroom_Input = '';

        this.filters = {};
        this.pageNumber = 1;
        this.units = [];
        this.columns = [];
        this.mobileColumns = [];
        this.totalUnits = 0;
        this.totalSalesPrice = 0;
        this.statusCounts = [];

        this.projectOptions = this.allProjects.map(p => ({
            label: p.Name,
            value: p.Id
        }));

        const inputs = this.template.querySelectorAll('lightning-combobox, lightning-input');
        inputs.forEach(input => { input.value = undefined; });
    }

    loadUnits() {
        if (!this.selectedProject && !this.selectedDeveloper) return;

        const combinedFilters = {
            ...this.filters,
            ...(this.selectedDeveloper ? { 'Developer_Name__c': this.selectedDeveloper } : {}),
            ...(this.selectedLocation ? { 'Location__c': this.selectedLocation } : {})
        };
        if (this.isSalesAgent) {
            const status = this.filters?.Status__c;
            if (!['Available', 'Sold'].includes(status)) {
                this.filters.Status__c = 'All';
            }
        }
        if (this.selectedProject) {
            combinedFilters['Project__c'] = this.selectedProject;
        }

        this.units = [];
        this.columns = [];
        this.mobileColumns = [];
        this.totalUnits = 0;
        this.totalSalesPrice = 0;
        this.statusCounts = [];

        const fetchData = () => this.fetchUnitData(combinedFilters);

        if (Object.keys(this.fieldLabelMap).length === 0) {
            getFieldSetFieldsWithLabel()
                .then(fieldMeta => {
                    fieldMeta.forEach(f => this.fieldLabelMap[f.apiName] = f.label);
                    fetchData();
                })
                .catch(error => {
                    console.error('Field Labels Error:', error);
                    fetchData();
                });
        } else {
            fetchData();
        }
    }

    fetchUnitData(combinedFilters = this.filters) {
        if (!this.selectedProject) this.selectedProject = '';
        getUnits({
            projectId: this.selectedProject,
            filters: combinedFilters,
            pageSize: this.pageSize,
            pageNumber: this.pageNumber
        })
            .then(data => {
                let allUnitData = [];
                let offsetUnitData = [];
                if (data !== null) {
                    allUnitData = [...data[0]];
                    offsetUnitData = [...data[1]];

                    this.units = offsetUnitData.map(u => {
                        const record = { ...u, statusClass: this.getStatusClass(u.Status__c) };
                        const unitLabel = u.SQM__c == true ? 'Sq.m' : 'Sq.ft';
                        if (u.Internal_Area__c != null) record.Internal_Area__c = `${u.Internal_Area__c} ${unitLabel}`;
                        if (u.Balcony_Area__c != null) record.Balcony_Area__c = `${u.Balcony_Area__c} ${unitLabel}`;
                        if (u.Total_Area_SQ_FT__c != null) record.Total_Area_SQ_FT__c = `${u.Total_Area_SQ_FT__c} ${unitLabel}`;
                        record.CD_Bedrooms__c = `${u.CD_Bedrooms__c || ''} ${u.Space__c || ''}`.trim();
                        return record;
                    });
                }
                this.updateUnitStatusCounts(allUnitData);
                if (offsetUnitData.length && this.columns.length === 0) {
                    this.buildColumns(offsetUnitData[0]);
                }
                this.disableNext = offsetUnitData.length < this.pageSize;
                this.disablePrev = this.pageNumber == 1;
            })
            .catch(error => console.error('Unit Load Error:', error));
    }

    get showNoUnitsMessage() {
        return (this.selectedProject || this.selectedDeveloper) && this.units?.length === 0;
    }

    updateUnitStatusCounts(allUnitData) {
        const counts = {};
        const salesByStatus = {};
        allUnitData.forEach(unit => {
            const status = unit.Status__c || 'Unknown';
            counts[status] = (counts[status] || 0) + 1;
            const price = parseFloat(unit.CD_Sales_Price__c);
            if (!isNaN(price)) salesByStatus[status] = (salesByStatus[status] || 0) + price;
        });

        const selectedStatus = this.unit_Status_Input || (this.filters && this.filters.Status__c);
        const isFilteredByStatus = selectedStatus && selectedStatus !== 'All';

        const targetStatuses = isFilteredByStatus
            ? [selectedStatus]
            : this.statusOptions.filter(opt => opt.value !== 'All' && opt.value !== '').map(opt => opt.value);

        this.statusCounts = targetStatuses.map(status => ({
            label: status,
            count: counts[status] || 0,
            showPrice: true,
            formattedSoldPrice: this.formatCurrency(salesByStatus[status] || 0)
        }));

        const normalize = val => val ? val.trim() : null;
        const projectId = normalize(this.selectedProject);
        const developer = normalize(this.selectedDeveloper);
        const location = normalize(this.selectedLocation);

        const hasAnyFilter = projectId || developer || location;
        this.showBanner = !hasAnyFilter;

        if (hasAnyFilter) {
            Promise.all([
                getTotalUnitCount({ projectId, developer, location }),
                getTotalSAR({ projectId, developer, location })
            ])
                .then(([unitCount, sarTotal]) => {
                    this.totalUnits = unitCount;
                    this.totalSalesPrice = sarTotal;
                })
                .catch(error => {
                    console.error('Error fetching totals:', error);
                    this.totalUnits = 0;
                    this.totalSalesPrice = 0;
                });
        } else {
            this.totalUnits = 0;
            this.totalSalesPrice = 0;
        }
    }

    buildColumns(sample) {
        let cols = Object.keys(sample)
            .filter(key => key !== 'Id' && key !== 'Name' && key !== 'Project__c' && key !== 'Space__c' && key !== 'SQM__c')
            .map(key => {
                const label = this.fieldLabelMap[key] || key.replace(/__/g, '').replace(/_/g, ' ');
                const column = { label: label, fieldName: key, type: 'text' };
                if (key === 'Status__c') column.cellAttributes = { class: { fieldName: 'statusClass' } };
                if (this.isMobile && key === 'Unit_Number__c') {
                    column.type = 'button';
                    column.typeAttributes = { label: { fieldName: 'Unit_Number__c' }, variant: 'base' };
                }
                if (key === 'CD_Sales_Price__c') {
                    column.type = 'currency';
                    column.typeAttributes = {
                        currencyCode: { fieldName: 'CurrencyIsoCode' },
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2
                    };
                    column.cellAttributes = { alignment: 'left' };
                }
                return column;
            });

        getUserProfileName()
            .then(profileName => {
                if (profileName !== 'Sales Agent') {
                    cols = [...cols, {
                        type: 'action',
                        typeAttributes: {
                            rowActions: [
                                { label: 'Express Interest', name: 'inquiry', iconName: 'utility:agent_session' },
                                { label: 'Generate Sales Offer', name: 'brochures', iconName: 'utility:store' },
                                { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
                                { label: 'Details', name: 'view', iconName: 'utility:preview' }
                            ]
                        }
                    }];
                }
                this.columns = cols;
                if (this.isMobile) this.mobileColumns = cols.slice(0, 3);
            })
            .catch(error => {
                console.error('Error fetching profile:', error);
                this.columns = cols;
                if (this.isMobile) this.mobileColumns = cols.slice(0, 3);
            });
    }

    getStatusClass(status) {
        switch (status) {
            case 'Available': return 'slds-text-color_success slds-text-title_bold';
            case 'Sold': return 'slds-text-color_error slds-text-title_bold';
            case 'On Hold': return 'slds-text-color_warning slds-text-title_bold';
            default: return 'slds-text-color_weak';
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'inquiry':
                this.selectedUnitId = row.Id;
                this.isModalOpen = true;
                break;
            case 'edit':
                this.editRecord = {
                    id: row.Id,
                    projectName: row.Project__r?.Name || '',
                    unitName: row.Unit_Number__c || '',
                    internalArea: row.Internal_Area__c ? parseFloat(row.Internal_Area__c) : '',
                    externalArea: row.Balcony_Area__c ? parseFloat(row.Balcony_Area__c) : '',
                    totalPrice: row.Unit_Price_AED__c ? parseFloat(row.Unit_Price_AED__c) : ''
                };
                this.isEditModalOpen = true;
                break;
            case 'view':
                this.viewUnitId = row.Id;
                this.isViewModalOpen = true;
                break;
            case 'brochures':
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: { url: '/apex/UnitCard?propertyId=' + row.Id }
                });
                break;
        }
    }

    @track isViewModalOpen = false;
    @track viewUnitId;
    @track recordDetailName;
    @track recordDetails = [];

    viewRecord(event) {
        const row = event.detail.row;
        this.recordDetailName = row.Name;
        const foundRecord = this.units.find(record => record.Id === row.Id);
        let labelValueList = [];
        if (foundRecord) {
            labelValueList = Object.entries(foundRecord)
                .filter(([key]) => key !== 'Id' && key !== 'statusClass' && key !== 'Name' && key !== 'Project__c')
                .map(([key, value]) => {
                    const ukey = this.fieldLabelMap[key] || key.replace(/__/g, '').replace(/_/g, ' ');
                    return { label: ukey, value: value };
                });
            this.recordDetails = [...labelValueList];
        } else {
            this.recordDetails = [];
        }
        if (this.isMobile) this.mobileRecordDetail = true;
        document.body.style.overflow = 'hidden';
        document.body.style.position = 'fixed';
    }

    closeRecordPanel() {
        this.mobileRecordDetail = false;
        document.body.style.overflow = '';
        document.body.style.position = '';
    }

    closeModal() {
        this.selectedUnitId = null;
        this.isModalOpen = false;
    }

    handleSuccess() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Inquiry submitted successfully!',
            variant: 'success'
        }));
        this.closeModal();
    }

    handleError() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: 'Something went wrong.',
            variant: 'error'
        }));
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadUnits();
        }
    }

    handleNext() {
        this.pageNumber++;
        this.loadUnits();
    }

    @wire(getRecord, { recordId: '$selectedUnitId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.unitDetails = {
                name: data.fields.Name.value,
                internalArea: data.fields.Internal_Area__c?.value,
                externalArea: data.fields.Balcony_Area__c?.value,
                totalPrice: data.fields.Unit_Price_AED__c?.value,
                status: data.fields.Status__c?.value,
                project: data.fields.Project__r?.displayValue,
                totalSqft: data.fields.Total_Area_SQ_FT__c?.value,
                size: data.fields.CD_Size_pb__c?.value,
                unitType: data.fields.CD_Unit_Type__c?.value
            };
        } else if (error) {
            console.error('Record Wire Error:', error);
        }
    }

    get formattedInternalArea() {
        return this.unitDetails.internalArea ? `${this.unitDetails.internalArea} Sq.ft` : '';
    }
    get formattedExternalArea() {
        return this.unitDetails.externalArea ? `${this.unitDetails.externalArea} Sq.ft` : '';
    }
    get formattedTotalSqft() {
        return this.unitDetails.totalSqft ? `${this.unitDetails.totalSqft} Sq.ft` : '';
    }

    @track isEditModalOpen = false;
    @track editRecord = { id: '' };

    openEditModal(record) {
        this.editRecord = { ...record };
        this.isEditModalOpen = true;
    }
    closeEditModal() {
        this.isEditModalOpen = false;
    }
    handleSuccess(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Record updated successfully',
            variant: 'success'
        }));
        this.closeEditModal();
    }
    handleError(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error updating record',
            message: event.detail.message,
            variant: 'error'
        }));
    }
    closeViewModal() {
        this.viewUnitId = null;
        this.isViewModalOpen = false;
    }
}
