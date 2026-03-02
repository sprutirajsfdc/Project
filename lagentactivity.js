import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';
import { CurrentPageReference } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/chartjs';
import getAgentFullActivity from '@salesforce/apex/AgentActivityController.getAgentFullActivity';

export default class Lagentactivity extends NavigationMixin(LightningElement) {
    chartJsInitialized = false;
    leadSourceChart;
    statusChart;

    selectedFilter = 'today';

    filterOptions = [
        { label: 'Today', value: 'today' },
        { label: 'Last 7 Days', value: '7days' },
        { label: 'This Month', value: 'month' },
        { label: 'Custom Range', value: 'custom' }
    ];

    @api agentId;

    agent;
    tasks = [];
    events = [];
    inquiries = [];

    startDate = null;
    endDate = null;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__agentId) {
            this.agentId = currentPageReference.state.c__agentId;
        }

        if (!this.agentId) {
            this.agentId = USER_ID;
        }

        this.loadData();
    }

    renderedCallback() {
        if (this.chartJsInitialized) return;

        this.chartJsInitialized = true;

        loadScript(this, chartjs)
            .then(() => {
                console.log('ChartJS loaded');
            })
            .catch(error => {
                console.error('ChartJS load error', error);
            });
    }

    connectedCallback() {
        setTimeout(() => {
            if (!this.agentId) this.agentId = USER_ID;
            this.loadData();
        }, 0);
    }

    // ================= LOAD DATA =================
    loadData() {
        getAgentFullActivity({ 
            agentId: this.agentId, 
            startDate: this.startDate, 
            endDate: this.endDate,
            filterOption: this.selectedFilter
        })
        .then(result => {
            this.agent = result?.agent?.[0] || null;
            this.tasks = result?.tasks || [];
            this.events = result?.events || [];
            this.inquiries = (result?.inquiries || []).map(inq => ({
                ...inq,
                ContactName: inq.Contact__r ? inq.Contact__r.Name : ''
            }));

            if (this.chartJsInitialized) {
                this.buildLeadSourceChart();
                this.buildStatusChart();
            }
        })
        .catch(error => console.error('Error:', error));
    }

    // ================= CHARTS =================
    buildLeadSourceChart() {
        if (!this.inquiries || this.inquiries.length === 0) return;

        const sourceCounts = {};
        this.inquiries.forEach(inq => {
            const source = inq.Lead_Source__c || 'Unknown';
            sourceCounts[source] = (sourceCounts[source] || 0) + 1;
        });

        const labels = Object.keys(sourceCounts);
        const data = Object.values(sourceCounts);
        const ctx = this.template.querySelector('.leadSourceChart')?.getContext('2d');
        if (!ctx) return;

        if (this.leadSourceChart) this.leadSourceChart.destroy();

        this.leadSourceChart = new Chart(ctx, {
            type: 'bar',
            data: { labels, datasets: [{ label: 'Lead Source Count', data, backgroundColor: '#4e73df' }] },
            options: { responsive: true, plugins: { legend: { display: false } }, maintainAspectRatio: false }
        });
    }

    buildStatusChart() {
        if (!this.inquiries || this.inquiries.length === 0) return;

        const statusCounts = {};
        this.inquiries.forEach(inq => {
            const status = inq.Status__c || 'Unknown';
            statusCounts[status] = (statusCounts[status] || 0) + 1;
        });

        const labels = Object.keys(statusCounts);
        const data = Object.values(statusCounts);
        const ctx = this.template.querySelector('.statusChart')?.getContext('2d');
        if (!ctx) return;

        if (this.statusChart) this.statusChart.destroy();

        this.statusChart = new Chart(ctx, {
            type: 'doughnut',
            data: { labels, datasets: [{ data, backgroundColor: ['#1cc88a', '#36b9cc', '#f6c23e', '#e74a3b', '#858796'] }] },
            options: { responsive: true, plugins: { legend: { position: 'bottom' } }, maintainAspectRatio: false }
        });
    }

    get agentImage() {
        return this.agent?.AWS_Profile_Url__c ? this.agent.AWS_Profile_Url__c : 'https://my-dubai-real-estate.s3.eu-north-1.amazonaws.com/Listing_s3/user.jpeg';
    }

    handleStartDate(event) {
        this.startDate = event.target.value;
        this.selectedFilter = 'custom';
    }

    handleEndDate(event) {
        this.endDate = event.target.value;
        this.selectedFilter = 'custom';
    }

    goBack() { window.history.back(); }

    // ================= NAVIGATION =================
    navigateToInquiry(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Inquiry__c', actionName: 'view' }
        });
    }

    // ================= QUICK FILTER HANDLER =================
    handleQuickFilter(event) {
        this.selectedFilter = event.detail.value;

        // Reset dates for non-custom filters
        if (this.selectedFilter !== 'custom') {
            this.startDate = null;
            this.endDate = null;
        }

        this.loadData();
    }
}