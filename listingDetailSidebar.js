import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
// Update this import to the NEW Apex method
import getAllMediaForListing from '@salesforce/apex/propertyListcontroller.getAllMediaForListing';

export default class ListingDetailSidebar extends NavigationMixin(LightningElement) {
    @api listingDetails;
    @track mediaList = [];
    @track currentIndex = 0;
    @track isPreviewOpen = false;

    // Fetch ALL images for this specific listing
    @wire(getAllMediaForListing, { listingId: '$listingDetails.Id' })
    wiredMedia({ error, data }) {
        if (data) {
            // Data is now a list of Property_Media__c records
            this.mediaList = data;
            this.currentIndex = 0;
        } else if (error) {
            console.error('Error fetching media:', error);
            this.mediaList = [];
        }
    }

    get hasImages() { 
        return this.mediaList && this.mediaList.length > 0; 
    }

    get currentImageUrl() { 
        // Fallback to the thumbnail from the table if no gallery images found
        return this.hasImages ? this.mediaList[this.currentIndex].Public_URL__c : this.listingDetails.Thumbnail; 
    }

    get currentImageIndexDisplay() { return this.currentIndex + 1; }
    get totalImages() { return this.mediaList.length; }
    get listingName() { return this.listingDetails ? this.listingDetails.Name : ''; }

    prevImage(event) {
        event.stopPropagation();
        if (this.totalImages > 1) {
            this.currentIndex = (this.currentIndex === 0) ? this.mediaList.length - 1 : this.currentIndex - 1;
        }
    }

    nextImage(event) {
        event.stopPropagation();
        if (this.totalImages > 1) {
            this.currentIndex = (this.currentIndex === this.mediaList.length - 1) ? 0 : this.currentIndex + 1;
        }
    }

    openFullscreen() { this.isPreviewOpen = true; }
    closeFullscreen() { this.isPreviewOpen = false; }
    closeSidebar() { this.dispatchEvent(new CustomEvent('close')); }

    navigateToRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { 
                recordId: this.listingDetails.Id, 
                actionName: 'view' 
            }
        });
    }
}
