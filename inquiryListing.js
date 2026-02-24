import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import getPropertyMedia from '@salesforce/apex/PropertyMediaController.getPropertyMedia';

const INQUIRY_FIELDS = ['Inquiry__c.Initial_Inquiry_Listing__c'];
const LISTING_FIELDS = [
    'Listing__c.Name',
    'Listing__c.os_ListingPrice_pb__c',
    'Listing__c.Property_Type__c',
    'Listing__c.Status__c',
    'Listing__c.Owner.Name',
    'Listing__c.os_ListingAgentName__c',
    'Listing__c.Auto_Generated_broker_reference_ID__c',
    'Listing__c.Sub_Community_Propertyfinder__c',
    'Listing__c.Community_Propertyfinder__c',
    'Listing__c.Bedrooms__c',
    'Listing__c.Bathrooms__c'
];

export default class InquiryListing extends NavigationMixin(LightningElement) {
    @api recordId;

    @track listingData = { images: [] };
    listingId;
    currentImageIndex = 0;

    // Load Inquiry to get Listing Id
    @wire(getRecord, { recordId: '$recordId', fields: INQUIRY_FIELDS })
    wiredInquiry({ error, data }) {
        if (data) {
            this.listingId = data.fields.Initial_Inquiry_Listing__c?.value || null;
        } else if (error) {
            console.error('Error loading inquiry:', error);
        }
    }

    // Load Listing details
    @wire(getRecord, { recordId: '$listingId', fields: LISTING_FIELDS })
    wiredListing({ error, data }) {
        if (error) {
            console.error('Error loading listing:', error);
            return;
        }
        if (!data || !data.fields) {
            console.warn('No listing data returned');
            return;
        }

        const fields = data.fields;

        this.listingData = {
            ...this.listingData,
            name: fields.Name?.value,
            price: fields.os_ListingPrice_pb__c?.value,
            propertyType: fields.Property_Type__c?.value,
            status: fields.Status__c?.value,
            ownerName: fields.Owner?.value?.fields?.Name?.value || '',
            agentName: fields.os_ListingAgentName__c?.value,
            brokerRefId: fields.Auto_Generated_broker_reference_ID__c?.value || '',
            subCommunityName: fields.Sub_Community_Propertyfinder__c?.value || '',
            communityName: fields.Community_Propertyfinder__c?.value || '',
            bedrooms: fields.Bedrooms__c?.value || 0,
            bathrooms: fields.Bathrooms__c?.value || 0
        };

        if (this.listingId) {
            this.loadMedia();
        }
    }

    // Load media images related to listing via Apex
    async loadMedia() {
        if (!this.listingId) {
            this.listingData.images = [];
            return;
        }
        try {
            const media = await getPropertyMedia({ propertyId: this.listingId });

            if (media && media.length > 0) {
                this.listingData.images = media.map(item => ({
                    id: item.PropMediaId,               // Use correct field from Apex DTO
                    url: item.Public_URL,               // ✅ Fixed: use Public_URL instead of Public_URL__c
                    alt: item.Tag || 'Listing Image'    // Fallback alt text
                }));
                this.currentImageIndex = 0;
            } else {
                this.listingData.images = [];
            }
        } catch (error) {
            console.error('Error loading media:', error);
        }
    }

    get currentImage() {
        return this.listingData.images.length
            ? this.listingData.images[this.currentImageIndex]
            : { url: '', alt: 'No image available' };
    }

    prevImage() {
        if (this.listingData.images.length) {
            this.currentImageIndex =
                (this.currentImageIndex - 1 + this.listingData.images.length) % this.listingData.images.length;
        }
    }

    nextImage() {
        if (this.listingData.images.length) {
            this.currentImageIndex = (this.currentImageIndex + 1) % this.listingData.images.length;
        }
    }

    get statusClass() {
        switch (this.listingData.status?.toLowerCase()) {
            case 'active':
                return 'status-active';
            case 'pending':
                return 'status-pending';
            case 'sold':
                return 'status-sold';
            case 'published':
                return 'status-published';
            default:
                return 'status-default';
        }
    }

    navigateToListing() {
        if (this.listingId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.listingId,
                    objectApiName: 'Listing__c',
                    actionName: 'view'
                }
            });
        }
    }
}