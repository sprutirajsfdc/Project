import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFilteredData from '@salesforce/apex/propertyListcontroller.getFilteredData';
import getThumbnailsForListings from '@salesforce/apex/propertyListcontroller.getThumbnailsForListings';
import getFilterFieldLabelAndAPI from '@salesforce/apex/propertyListcontroller.getFilterFieldLabelAndAPI';

export default class ListingExplorer extends NavigationMixin(LightningElement) {
    @track listings = [];
    @track thumbnailMap = {}; 
    @track selectedListing = null;
    @track isSidebarOpen = false;
    
    // Track filter options
    @track statusOptions = [];
    @track typeOptions = [];
    @track recordTypeOptions = [];

    // Reactive filter properties - these map to your Apex parameters
    @track listingName = '';
@track brokerRef = '';
@track propType = '';
@track listingType = '';
@track minSize = '';
@track status = '';

    // 1. Updated Wire: Reactive to filter changes using '$variableName'
    @wire(getFilteredData, { 
    limitRecords: 50, 
    name: '$listingName',
    brokerReference: '$brokerRef',
    propertyType: '$propType',
    listingType: '$listingType',
   status: '$status' 
})
wiredData({ error, data }) {
    if (data) {
        this.listings = data;
        const listingIds = data.map(item => item.Id);
        this.fetchThumbnails(listingIds);
    } else if (error) {
        console.error('Error fetching listings:', error);
    }
}

    // 2. Map Picklist values for Type, Status, and Record Type (Listing Type)
    @wire(getFilterFieldLabelAndAPI)
    wiredFilters({ error, data }) {
        if (data) {
            let filters = JSON.parse(data);
            
            // Map Status
            let statusField = filters.find(f => f.apiName === 'Status__c');
            if (statusField) this.statusOptions = this.formatOptions(statusField.picklistValues);

            // Map Property Type
            let typeField = filters.find(f => f.apiName === 'Property_Type__c');
            if (typeField) this.typeOptions = this.formatOptions(typeField.picklistValues);

            // Map Listing Type (Sales/Rent)
            let recordTypeField = filters.find(f => f.apiName === 'Listing_Type__c');
            if (recordTypeField) this.recordTypeOptions = this.formatOptions(recordTypeField.picklistValues);
        }
    }

    // Helper to add "All" option to picklists
    formatOptions(values) {
        if (!values) return [];
        let opts = values.map(val => ({ label: val, value: val }));
        opts.unshift({ label: 'All', value: '' });
        return opts;
    }

    // 3. Handle Changes from UI
    handleFilterChange(event) {
    const field = event.target.dataset.name;
    const value = event.target.value;

    switch(field) {
        case 'name':
            this.listingName = value;
            break;
        case 'brokerRef':
            this.brokerRef = value;
            break;
        case 'type':
            this.propType = value;
            break;
        case 'listingType':
            this.listingType = value;
            break;
        case 'status':
            this.status = value;
            break;
    }
}

    handleClearAll() {
    this.listingName = '';
    this.brokerRef = '';
    this.propType = '';
    this.listingType = '';
    this.status = '';
}

    // --- EXISTING LOGIC ---

    async fetchThumbnails(listingIds) {
        try {
            const result = await getThumbnailsForListings({ listingIds: listingIds });
            this.thumbnailMap = result;
        } catch (error) {
            console.error('Error fetching thumbnails:', error);
        }
    }

    get processedListings() {
        return this.listings.map(item => {
            const imageUrl = this.thumbnailMap && this.thumbnailMap[item.Id] 
                             ? this.thumbnailMap[item.Id] 
                             : 'https://via.placeholder.com/150';

            let statusClass = 'status-badge ';
            const statusVal = item.Status__c ? item.Status__c.toLowerCase() : '';
            
            if (statusVal === 'sold') statusClass += 'badge-sold';
            else if (statusVal === 'published' || statusVal === 'active') statusClass += 'badge-published';
            else if (statusVal === 'draft') statusClass += 'badge-draft';
            else if (statusVal === 'pending') statusClass += 'badge-pending';
            else statusClass += 'badge-default';

            return {
                ...item,
                OwnerName: item.Owner ? item.Owner.Name : 'N/A',
                FormattedPrice: new Intl.NumberFormat('en-US', { 
                    style: 'currency', currency: 'USD', maximumFractionDigits: 0 
                }).format(item.os_ListingPrice_pb__c || 0),
                Thumbnail: imageUrl,
                StatusBadgeClass: statusClass
            };
        });
    }

    get tableWidthClass() {
        return this.isSidebarOpen ? 'slds-col slds-size_2-of-3' : 'slds-col slds-size_1-of-1';
    }

    handleOpenSidebar(event) {
        const id = event.target.dataset.id;
        this.selectedListing = this.processedListings.find(l => l.Id === id);
        this.isSidebarOpen = true;
    }

    handleCloseSidebar() {
        this.isSidebarOpen = false;
        this.selectedListing = null;
    }

    navigateToRecordView(event) {
        const recordId = event.detail.recordId; 
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: recordId, actionName: 'view' }
        });
    }
    get formattedTotalFilteredPrice() {
    const total = this.totalFilteredPrice;
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(total);
}
get totalFilteredPrice() {
    if (!this.processedListings || this.processedListings.length === 0) {
        return 0;
    }

    return this.processedListings.reduce((total, listing) => {
        return total + (listing.os_ListingPrice_pb__c || 0);
    }, 0);
}
}
