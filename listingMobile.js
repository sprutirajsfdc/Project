import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import benton from '@salesforce/resourceUrl/BentonSans';
import freight from '@salesforce/resourceUrl/FreightBigProBook3';
import getView from '@salesforce/apex/ListingMobileCtrl.getView';

export default class ListingMobile extends LightningElement {
  @api recordId;

  @track vm = { title: '', description: '' };
  @track images = [];
  active = 0;

  startX = null;
  isMouseDown = false;

  connectedCallback() {
    // Load fonts
    Promise.all([
      loadStyle(this, `${benton}/fonts.css`),
      loadStyle(this, `${freight}/fonts.css`)
    ]).catch(() => {});
  }

  @wire(getView, { recordId: '$recordId' })
  wired({ data, error }) {
    if (data) {
      this.vm = {
        title: data.title ?? '',
        description: data.description ?? '',
        size: data.size ?? '',
        community: data.community ?? '',
        subCommunity: data.subCommunity ?? '',
        price: data.price ?? '',
        brokerListingId: data.brokerListingId ?? data.Auto_Generated_broker_reference_ID__c ?? '',
        name: data.name ?? data.Name ?? '',
        listingType: data.listingType ?? data.Listing_Type__c ?? '',
      };

      const imgs = Array.isArray(data.images) ? data.images : [];
      this.images = imgs.map(i => ({ url: i.url, alt: i.alt || '' }));
      this.active = 0;
    } else if (error) {
      console.error('listingMobile getView error', error);
      this.vm = {};
      this.images = [];
      this.active = 0;
    }
  }

  get hasImages() { return Array.isArray(this.images) && this.images.length > 0; }
  get firstImageUrl() { return this.hasImages ? this.images[this.active].url : ''; }
  get heroStyle() {
    if (!this.firstImageUrl) return '';
    const safe = this.firstImageUrl.replace(/"/g, '\\"');
    return `--hero-image: url("${safe}")`;
  }
  get heroAriaLabel() { return this.vm?.title ? `Hero image for ${this.vm.title}` : 'Listing hero image'; }

  get descText() {
    const raw = this.vm?.description || '';
    const stripped = this.stripHtml(raw).replace(/&nbsp;/gi, ' ').replace(/\s+/g, ' ').trim();
    return this.truncateWords(stripped, 180);
  }

  get sizeTitle() { return this.formatLabel('Size', this.vm?.size); }
  get sizeAria() { return this.sizeTitle; }
  get communityTitle() { return this.formatLabel('Community', this.vm?.community); }
  get communityAria() { return this.communityTitle; }
  get subCommunityTitle() { return this.formatLabel('Sub Community', this.vm?.subCommunity); }
  get subCommunityAria() { return this.subCommunityTitle; }

  formatLabel(label, value) {
    const v = (value ?? '').toString().trim();
    return v ? `${label}: ${v}` : label;
  }

  stripHtml(s) {
    try {
      return s.replace(/<style[\s\S]*?<\/style>/gi, '')
             .replace(/<script[\s\S]*?<\/script>/gi, '')
             .replace(/<[^>]*>/g, '');
    } catch {
      return s || '';
    }
  }
  truncateWords(s, max) {
    if (s.length <= max) return s;
    const cut = s.slice(0, max);
    const lastSpace = cut.lastIndexOf(' ');
    return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut).trim() + '…';
  }

  setActive(idx) {
    if (!this.hasImages) return;
    const n = this.images.length;
    this.active = ((idx % n) + n) % n;
  }
  onTouchStart = (e) => { if (e.touches?.length) this.startX = e.touches[0].clientX; };
  onTouchEnd = (e) => {
    if (this.startX === null) return;
    const endX = e.changedTouches?.length ? e.changedTouches[0].clientX : null;
    if (endX !== null) this.handleSwipe(endX - this.startX);
    this.startX = null;
  };
  onMouseDown = (e) => { this.isMouseDown = true; this.startX = e.clientX; };
  onMouseUp = (e) => {
    if (!this.isMouseDown) return;
    this.handleSwipe(e.clientX - this.startX);
    this.isMouseDown = false; this.startX = null;
  };
  onMouseLeave = () => { this.isMouseDown = false; this.startX = null; };

  handleSwipe(delta) {
    const threshold = 40;
    if (Math.abs(delta) > threshold) this.setActive(this.active + (delta < 0 ? 1 : -1));
  }
}
