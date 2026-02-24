import { LightningElement, api, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import benton from '@salesforce/resourceUrl/BentonSans';
import freight from '@salesforce/resourceUrl/FreightBigProBook3';
import getMedia from '@salesforce/apex/ListingMediaCtrl.getMedia';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ListingMediaMobile extends LightningElement {
  @api recordId;

  media = [];
  index = 0;
  showLightbox = false;
  zoomed = false;

  touch = { startX: 0, deltaX: 0, dragging: false };
  isDragging = false;
  dragX = 0;

  connectedCallback() {
    // Load fonts
    Promise.all([
      loadStyle(this, `${benton}/fonts.css`),
      loadStyle(this, `${freight}/fonts.css`)
    ]).catch(() => {});
  }

  @wire(getMedia, { recordId: '$recordId' })
  wiredMedia({ data, error }) {
    if (data) {
      this.media = Array.isArray(data) ? data : [];
      this.index = 0;
    } else if (error) {
      this.media = [];
      this.index = 0;
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Failed to load images',
          message:
            (error && error.body && (error.body.message || error.body.pageErrors?.[0]?.message)) ||
            'Unknown error',
          variant: 'error'
        })
      );
    }
  }

  get hasMedia() {
    return this.media && this.media.length > 0;
  }
  get current() {
    return this.hasMedia ? this.media[this.index] : {};
  }
  get displayIndex() {
    return this.hasMedia ? `${this.index + 1} / ${this.media.length}` : '';
  }

  get indicators() {
    const len = this.media?.length || 0;
    return Array.from({ length: len || 1 }, (_, i) => ({
      key: `p-${i}`,
      class: 'pager-dot' + (i === this.index ? ' current' : ''),
      char: i === this.index ? '_' : '.'
    }));
  }

  get heroImgClass() {
    return 'hero-img' + (this.isDragging ? ' is-dragging' : '');
  }
  get heroImgStyle() {
    const x = this.dragX || 0;
    const scale = 1.02;
    return `transform: translate3d(${x}px,0,0) scale(${scale});`;
  }

  next = () => {
    if (!this.hasMedia) return;
    this.index = (this.index + 1) % this.media.length;
  };
  prev = () => {
    if (!this.hasMedia) return;
    this.index = (this.index - 1 + this.media.length) % this.media.length;
  };

  onTouchStart = (e) => {
    this.touch.startX = e.touches[0].clientX;
    this.touch.deltaX = 0;
    this.touch.dragging = true;
    this.isDragging = true;
    this.dragX = 0;
  };
  onTouchMove = (e) => {
    if (!this.touch.dragging) return;
    this.touch.deltaX = e.touches[0].clientX - this.touch.startX;
    this.dragX = this.touch.deltaX * 0.06;
  };
  onTouchEnd = () => {
    this.finishSwipe();
  };

  onMouseDown = (e) => {
    this.touch.startX = e.clientX;
    this.touch.deltaX = 0;
    this.touch.dragging = true;
    this.isDragging = true;
    this.dragX = 0;
  };
  onMouseMove = (e) => {
    if (!this.touch.dragging) return;
    this.touch.deltaX = e.clientX - this.touch.startX;
    this.dragX = this.touch.deltaX * 0.06;
  };
  onMouseUp = () => {
    this.finishSwipe();
  };

  finishSwipe() {
    if (!this.touch.dragging) return;
    const threshold = 40;
    if (this.touch.deltaX <= -threshold) this.next();
    else if (this.touch.deltaX >= threshold) this.prev();

    this.touch.dragging = false;
    this.isDragging = false;
    this.dragX = 0;
    this.touch.deltaX = 0;
  }

  openLightbox = () => {
    if (!this.hasMedia) return;
    this.showLightbox = true;
    this.zoomed = false;
    try { document.body.style.overflow = 'hidden'; } catch (e) {}
  };
  closeLightbox = () => {
    this.showLightbox = false;
    this.zoomed = false;
    try { document.body.style.overflow = ''; } catch (e) {}
  };
  onLightboxBackdrop = (e) => {
    const tag = e.target.tagName;
    if (tag !== 'IMG' && tag !== 'BUTTON') this.closeLightbox();
  };
  toggleZoom = () => { this.zoomed = !this.zoomed; };
  onLightboxImgLoad() { /* hook */ }
}
