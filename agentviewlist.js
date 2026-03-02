import { LightningElement, wire, track } from 'lwc';
import getActiveAgents from '@salesforce/apex/AgentDirectoryController.getActiveAgents';

export default class Agentviewlist extends LightningElement {
    @track allAgents = [];
    @track filteredAgents = [];
    @track displayedAgents = [];
    @track selectedAgentId;
    
    pageSize = 8;
    currentPage = 1;
    totalPages = 0;
    searchTerm = '';

    @wire(getActiveAgents)
    wiredAgents({ error, data }) {
        if (data) {
            this.allAgents = data;
            this.applyFilters();
        }
    }

    handleViewDetails(event) {
        this.selectedAgentId = event.target.dataset.id;
    }

    handleBack() {
        this.selectedAgentId = null;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.currentPage = 1;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredAgents = this.allAgents.filter(agent => 
            agent.Name.toLowerCase().includes(this.searchTerm)
        );
        this.totalPages = Math.ceil(this.filteredAgents.length / this.pageSize);
        this.updateDisplayedAgents();
    }

    updateDisplayedAgents() {
        const start = (this.currentPage - 1) * this.pageSize;
        this.displayedAgents = this.filteredAgents.slice(start, start + this.pageSize);
    }

    get pages() {
        let pagesArr = [];
        for (let i = 1; i <= this.totalPages; i++) {
            pagesArr.push({ value: i, className: i === this.currentPage ? 'active' : '' });
        }
        return pagesArr;
    }

    goToPage(event) {
        this.currentPage = parseInt(event.target.dataset.id, 10);
        this.updateDisplayedAgents();
    }

    prevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateDisplayedAgents();
        }
    }

    nextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedAgents();
        }
    }
}