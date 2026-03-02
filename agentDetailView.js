import { LightningElement, api, wire, track } from 'lwc';
import getAgentListingData from '@salesforce/apex/AgentDirectoryController.getAgentListingData';
import getAllMediaForListing from '@salesforce/apex/AgentDirectoryController.getAllMediaForListing';
import { NavigationMixin } from 'lightning/navigation';

export default class AgentDetailView extends NavigationMixin(LightningElement) {
    @api agentId;

    @track agent = {};
    @track listings = [];
    @track selectedType = 'Sale';
    @track isLoading = true;
    @track showDashboard = false; // New property to toggle views

    @track totalPropertyValue = 0;
    @track activeListingsCount = 0;
    @track closedDealsCount = 0;
    @track totalClosedAmount = 0;

    // --- NAVIGATION HANDLERS ---
    
    // // Triggered by "Log Call" button
    // handleLogCallClick() {
    //     this.showDashboard = true;
    // }

    // Triggered by 'onclose' event from c-agentactivity-dashboard
    handleBackFromDashboard() {
        this.showDashboard = false;
    }

    goBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // --- GETTERS ---

    get formattedTotalPropertyValue() {
        return '$' + (this.totalPropertyValue || 0).toLocaleString();
    }

    get formattedTotalClosedAmount() {
        return '$' + (this.totalClosedAmount || 0).toLocaleString();
    }

    get filteredListings() {
        if (!this.listings) return [];
        return this.listings.filter(item => {
            if (!item.Listing_Type__c) return false;
            return item.Listing_Type__c
                .toLowerCase()
                .includes(this.selectedType.toLowerCase());
        });
    }

    get saleTabClass() {
        return this.selectedType === 'Sale' ? 'active-tab' : 'inactive-tab';
    }

    get rentTabClass() {
        return this.selectedType === 'Rent'
            ? 'active-tab slds-m-left_medium'
            : 'inactive-tab slds-m-left_medium';
    }

    // --- DATA FETCHING ---

    @wire(getAgentListingData, { agentId: '$agentId' })
    async wiredData({ error, data }) {
        if (data) {
            this.agent = data.agent[0] || {};
            const rawListings = data.listings || [];

            try {
                // Fetch images for all listings simultaneously
                this.listings = await Promise.all(rawListings.map(async (item) => {
                    const createdDate = new Date(item.CreatedDate);
                    const today = new Date();
                    const diffDays = Math.floor((today - createdDate) / (1000 * 60 * 60 * 24));

                    const mediaRecords = await getAllMediaForListing({ listingId: item.Id });
                    
                    const thumbnailUrl = (mediaRecords && mediaRecords.length > 0) 
                        ? mediaRecords[0].Public_URL__c 
                        : 'https://via.placeholder.com/150';

                    return {
                        ...item,
                        daysAgo: diffDays,
                        thumbnail: thumbnailUrl,
                        formattedPrice: item.os_ListingPrice_pb__c
                            ? '$' + item.os_ListingPrice_pb__c.toLocaleString()
                            : '$0'
                    };
                }));
            } catch (err) {
                console.error('Error fetching property media:', err);
            }

            this.totalPropertyValue = data.totalPropertyValue || 0;
            this.activeListingsCount = data.activeListingsCount || 0;
            this.closedDealsCount = data.closedDealsCount || 0;
            this.totalClosedAmount = data.totalClosedAmount || 0;
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading initial data:', error);
            this.isLoading = false;
        }
    }

    showSale() {
        this.selectedType = 'Sale';
    }

    showRent() {
        this.selectedType = 'Rent';
    }

    handleLogCallClick() {
    this[NavigationMixin.Navigate]({
        type: 'standard__navItemPage',
        attributes: {
            apiName: 'Agent_Activity' // <-- Tab API name (check in Setup)
        },
        state: {
            c__agentId: this.agentId
        }
    });
}
 
}