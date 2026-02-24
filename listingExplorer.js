import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFilteredData from '@salesforce/apex/propertyListcontroller.getFilteredData';
import getThumbnailsForListings from '@salesforce/apex/propertyListcontroller.getThumbnailsForListings';
import getFilterFieldLabelAndAPI from '@salesforce/apex/propertyListcontroller.getFilterFieldLabelAndAPI';
import getOwnerProfileUrls from '@salesforce/apex/propertyListcontroller.getOwnerProfileUrls';

export default class ListingExplorer extends NavigationMixin(LightningElement) {
    @track listings = [];
    @track thumbnailMap = {}; 
    @track selectedListing = null;
    @track isSidebarOpen = false;
    @track selectedListingId = '';
    @track brokerRef = '';
    @track ownerUrlMap = {};
    
    // --- NEW: View Mode Tracking ---
    @track viewMode = 'grid'; // Default to 'grid' to match your image

    @track statusOptions = [];
    @track typeOptions = [];
    @track recordTypeOptions = [];

    @track listingName = '';
    @track brokerRef = '';
    @track propType = '';
    @track listingType = '';
    @track status = '';

    // --- NEW: View Mode Getters ---
    get isTableView() {
        return this.viewMode === 'table';
    }

    get gridButtonVariant() {
        return this.viewMode === 'grid' ? 'brand' : 'border-filled';
    }

    get tableButtonVariant() {
        return this.viewMode === 'table' ? 'brand' : 'border-filled';
    }

    // --- NEW: Toggle Handlers ---
    switchToGrid() {
        this.viewMode = 'grid';
    }

    switchToTable() {
        this.viewMode = 'table';
    }
    
     get ownerProfileUrl() {
        return this.listing && this.listing.Owner 
            ? this.listing.Owner.AWS_Profile_Url__c 
            : 'https://my-dubai-real-estate.s3.eu-north-1.amazonaws.com/Listing_s3/user.jpeg'; 
    }
async fetchOwnerProfiles(listings) {
    try {
        // Get unique OwnerIds from listings
        const ownerIds = listings
            .map(item => item.OwnerId)
            .filter(id => id);

        if (ownerIds.length === 0) return;

        const ownerMap = await getOwnerProfileUrls({ ownerIds });
        this.ownerUrlMap = ownerMap;
    } catch (error) {
        console.error('Error fetching owner profiles:', error);
    }
}
    
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
            this.fetchOwnerProfiles(data);
        } else if (error) {
            console.error('Error fetching listings:', error);
        }
    }

    @wire(getFilterFieldLabelAndAPI)
    wiredFilters({ error, data }) {
        if (data) {
            let filters = JSON.parse(data);
            let statusField = filters.find(f => f.apiName === 'Status__c');
            if (statusField) this.statusOptions = this.formatOptions(statusField.picklistValues);

            let typeField = filters.find(f => f.apiName === 'Property_Type__c');
            if (typeField) this.typeOptions = this.formatOptions(typeField.picklistValues);

            let recordTypeField = filters.find(f => f.apiName === 'Listing_Type__c');
            if (recordTypeField) this.recordTypeOptions = this.formatOptions(recordTypeField.picklistValues);
        }
    }

    formatOptions(values) {
        if (!values) return [];
        let opts = values.map(val => ({ label: val, value: val }));
        opts.unshift({ label: 'All', value: '' });
        return opts;
    }

    handleFilterChange(event) {
        const field = event.target.dataset.name;
        const value = event.target.value;

        switch(field) {
            case 'name': this.listingName = value; break;
            case 'brokerRef': this.brokerRef = value; break;
            case 'type': this.propType = value; break;
            case 'listingType': this.listingType = value; break;
            case 'status': this.status = value; break;
        }
    }

    handleClearAll() {
        this.listingName = '';
        this.brokerRef = '';
        this.propType = '';
        this.listingType = '';
        this.status = '';
    }

    async fetchThumbnails(listingIds) {
        try {
            const result = await getThumbnailsForListings({ listingIds: listingIds });
            this.thumbnailMap = result;
        } catch (error) {
            console.error('Error fetching thumbnails:', error);
        }
    }
    handleNewListing() {
    this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName: 'Listing__c', 
            actionName: 'new'   
        }
    });
}

    get processedListings() {
        return this.listings.map(item => {
            const imageUrl = this.thumbnailMap && this.thumbnailMap[item.Id] 
                             ? this.thumbnailMap[item.Id] 
                             : 'https://via.placeholder.com/150';

           const ownerProfileUrl = this.ownerUrlMap[item.OwnerId]
                ? this.ownerUrlMap[item.OwnerId]
                : 'https://my-dubai-real-estate.s3.eu-north-1.amazonaws.com/Listing_s3/user.jpeg';

            let statusClass = 'status-badge ';
            const statusVal = item.Status__c ? item.Status__c.toLowerCase() : '';
            
            if (statusVal === 'sold') statusClass += 'badge-sold';
            else if (statusVal === 'published' || statusVal === 'active') statusClass += 'badge-published';
            else if (statusVal === 'draft') statusClass += 'badge-draft';
            else if (statusVal === 'pending') statusClass += 'badge-pending';
            else statusClass += 'badge-default';
            
            const isSelected = item.Id === this.selectedListingId;

            return {
                ...item,
                OwnerName: item.Owner ? item.Owner.Name : 'N/A',
               OwnerProfileUrl: ownerProfileUrl,
                FormattedPrice: new Intl.NumberFormat('en-US', { 
                    style: 'currency', currency: 'USD', maximumFractionDigits: 0 
                }).format(item.os_ListingPrice_pb__c || 0),
                Thumbnail: imageUrl,
                StatusBadgeClass: statusClass,
                RowClass: isSelected ? 'table-row selected-row' : 'table-row',
                //  GridCardClass: isSelected ? 'property-card selected-card' : 'property-card',
                IsFeatured: item.Status__c === 'Active', 
                InquiryCount: Math.floor(Math.random() * 25) + 1 
            };
        });
    }

    get tableWidthClass() {
        return this.isSidebarOpen ? 'slds-col slds-size_2-of-3' : 'slds-col slds-size_1-of-1';
    }

    handleOpenSidebar(event) {
        const id = event.target.dataset.id;
        this.selectedListingId = id;
        this.selectedListing = this.processedListings.find(l => l.Id === id);
        this.isSidebarOpen = true;
    }

    handleCloseSidebar() {
        this.isSidebarOpen = false;
        this.selectedListing = null;
        this.selectedListingId = null;
    }

    get formattedTotalFilteredPrice() {
        return new Intl.NumberFormat('en-US', {
            style: 'currency', currency: 'USD'
        }).format(this.totalFilteredPrice);
    }

    get totalFilteredPrice() {
        return this.processedListings.reduce((total, listing) => total + (listing.os_ListingPrice_pb__c || 0), 0);
    }
}
