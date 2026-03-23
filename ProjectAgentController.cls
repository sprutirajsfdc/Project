public with sharing class ProjectAgentController {
    
    // Get all agents
    @AuraEnabled(cacheable=true)
    public static List<Agent__c> getAllAgents() {
        return [SELECT Id, Name FROM Agent__c];
    }
    
    // Search projects by name
    @AuraEnabled(cacheable=true)
    public static List<Project__c> searchProjectsByName(String nameFilter) {
        String searchTerm = '%' + String.escapeSingleQuotes(nameFilter) + '%';
        return [
            SELECT Id, Name
            FROM Project__c
            WHERE Name LIKE :searchTerm
        ];
    }
    
    // Get all projects
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getAllProjects() {
        return [SELECT Id, Name FROM Project__c];
    }
    
    // Assign agent to project (log only, supports multiple agents)
    @AuraEnabled
    public static String assignAgentToProject(Id projectId, Id agentId) {
        try {
            // Check if this agent is already assigned to this project
            List<Agent_Assignment__c> existingAssignments = [
                SELECT Id
                FROM Agent_Assignment__c
                WHERE Projects__c = :projectId AND Agent__c = :agentId
                LIMIT 1
            ];
            
            Project__c project = [SELECT Id, Name FROM Project__c WHERE Id = :projectId];
            Agent__c agent = [SELECT Id, Name FROM Agent__c WHERE Id = :agentId];
            
            if (existingAssignments.isEmpty()) {
                Agent_Assignment__c assignment = new Agent_Assignment__c(
                    Projects__c = projectId,
                    Agent__c = agentId,
                    Description__c = 'Assigned ' + agent.Name + ' to project ' + project.Name
                );
                insert assignment;
                return 'Successfully assigned ' + agent.Name + ' to project ' + project.Name;
            } else {
                return 'Agent ' + agent.Name + ' is already assigned to project ' + project.Name;
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error assigning agent to project: ' + e.getMessage());
        }
    }
    
    // Auto-rotation: Get next available agent
    @AuraEnabled
    public static Id getNextAgentId() {
        try {
            List<Agent__c> agents = [
                SELECT Id, Name, Last_Assigned_Date_Time__c
                FROM Agent__c
                ORDER BY Last_Assigned_Date_Time__c ASC NULLS FIRST
                LIMIT 1
            ];
            
            if (!agents.isEmpty()) {
                Agent__c nextAgent = agents[0];
                nextAgent.Last_Assigned_Date_Time__c = System.now();
                update nextAgent;
                return nextAgent.Id;
            }
            
            return null;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting next agent: ' + e.getMessage());
        }
    }
    
    // ✅ Get mapping of Project Name → List of Agent Names
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getProjectAgentMap() {
        Map<String, List<String>> projectAgents = new Map<String, List<String>>();
        
        List<Agent_Assignment__c> assignments = [
            SELECT Id, Projects__r.Name, Agent__r.Name
            FROM Agent_Assignment__c
            WHERE Projects__c != null
            ORDER BY Projects__r.Name, Agent__r.Name
            LIMIT 1000
        ];
        
        for (Agent_Assignment__c assignment : assignments) {
            String projectName = assignment.Projects__r.Name;
            String agentName = assignment.Agent__r.Name;
            
            if (projectName != null && agentName != null) {
                if (!projectAgents.containsKey(projectName)) {
                    projectAgents.put(projectName, new List<String>());
                }
                projectAgents.get(projectName).add(agentName);
            }
        }
        
        return projectAgents;
    }
    
    // Project assignment report
    @AuraEnabled(cacheable=true)
    public static List<Agent_Assignment__c> getProjectAssignmentReport() {
        return [
            SELECT Id, Projects__r.Name, Agent__r.Name, CreatedDate
            FROM Agent_Assignment__c
            WHERE Agent__c != NULL
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];
    }
    
    // --- Community assignment logic (same as before) ---
    
    @AuraEnabled(cacheable=true)
    public static List<Community__c> getAllCommunities() {
        return [
            SELECT Id, Name, Agent__r.Name
            FROM Community__c
            ORDER BY Name
            LIMIT 100
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Community__c> searchCommunitiesByName(String nameFilter) {
        String searchTerm = '%' + String.escapeSingleQuotes(nameFilter) + '%';
        return [
            SELECT Id, Name, Agent__r.Name
            FROM Community__c
            WHERE Name LIKE :searchTerm
            ORDER BY Country__c, Region__c, Sub_Region__c, Name
        ];
    }
    
    @AuraEnabled
    public static String assignAgentToCommunity(Id communityId, Id agentId) {
        try {
            Community__c community = [
                SELECT Id, Name
                FROM Community__c
                WHERE Id = :communityId
                LIMIT 1
            ];
            
            community.Agent__c = agentId;
            update community;
            
            Agent__c agent = [
                SELECT Id, Name
                FROM Agent__c
                WHERE Id = :agentId
                LIMIT 1
            ];
            
            Agent_Assignment__c assignment = new Agent_Assignment__c();
            assignment.Community__c = communityId;
            assignment.Agent__c = agentId;
            assignment.Description__c = 'Assigned ' + agent.Name + ' to community ' + community.Name;
            insert assignment;
            
            return 'Successfully assigned ' + agent.Name + ' to community ' + community.Name;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error assigning agent to community: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id getNextCommunityAgentId() {
        try {
            List<Agent__c> agents = [
                SELECT Id, Name, Last_Assigned_Date_Time__c
                FROM Agent__c
                ORDER BY Last_Assigned_Date_Time__c ASC NULLS FIRST
                LIMIT 1
            ];
            
            if (!agents.isEmpty()) {
                Agent__c nextAgent = agents[0];
                nextAgent.Last_Assigned_Date_Time__c = System.now();
                update nextAgent;
                return nextAgent.Id;
            }
            
            return null;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting next community agent: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCommunityAgentMap() {
        Map<String, List<String>> communityAgents = new Map<String, List<String>>();
        
        List<Community__c> communities = [
            SELECT Id, Name, Agent__r.Name,Region__c,Sub_Region__c,Country__c
            FROM Community__c
            WHERE Agent__c != null
            ORDER BY Name
            LIMIT 1000
        ];
        
        for (Community__c community : communities) {
            String communityName = community.Name;
            String agentName = community.Agent__r.Name;
            
            if (communityName != null && agentName != null) {
                if (!communityAgents.containsKey(communityName)) {
                    communityAgents.put(communityName, new List<String>());
                }
                communityAgents.get(communityName).add(agentName);
            }
        }
        
        return communityAgents;
    }
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCommunityLocationFilters() {
        Map<String, List<String>> locationMap = new Map<String, List<String>>();
        
        Set<String> countries = new Set<String>();
        Set<String> regions = new Set<String>();
        Set<String> subRegions = new Set<String>();
        
        List<Community__c> communities = [
            SELECT Country__c, Region__c, Sub_Region__c
            FROM Community__c
            WHERE Country__c != null AND Region__c != null AND Sub_Region__c != null
            LIMIT 1000
        ];
        
        for (Community__c c : communities) {
            countries.add(c.Country__c);
            regions.add(c.Region__c);
            subRegions.add(c.Sub_Region__c);
        }
        
        locationMap.put('countries', new List<String>(countries));
        locationMap.put('regions', new List<String>(regions));
        locationMap.put('subRegions', new List<String>(subRegions));
        
        return locationMap;
    }
@AuraEnabled(cacheable=true)
public static Map<String, List<String>> getCommunityLocationPicklistValues() {
    Map<String, List<String>> picklistValuesMap = new Map<String, List<String>>();
    List<String> countries = new List<String>();
    List<String> regions = new List<String>();
    List<String> subRegions = new List<String>();

    try {
        // Get the object's field describe result
        Schema.DescribeSObjectResult objectDescribe = Community__c.SObjectType.getDescribe();

        // Get picklist values for Country__c
        List<Schema.PicklistEntry> countryEntries = objectDescribe.fields.getMap().get('Country__c').getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : countryEntries) {
            if (entry.isActive()) {
                countries.add(entry.getValue());
            }
        }
        picklistValuesMap.put('countries', countries);

        // Get picklist values for Region__c
        List<Schema.PicklistEntry> regionEntries = objectDescribe.fields.getMap().get('Region__c').getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : regionEntries) {
            if (entry.isActive()) {
                regions.add(entry.getValue());
            }
        }
        picklistValuesMap.put('regions', regions);

        // Get picklist values for Sub_Region__c
        List<Schema.PicklistEntry> subRegionEntries = objectDescribe.fields.getMap().get('Sub_Region__c').getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : subRegionEntries) {
            if (entry.isActive()) {
                subRegions.add(entry.getValue());
            }
        }
        picklistValuesMap.put('subRegions', subRegions);

    } catch (Exception e) {
        throw new AuraHandledException('Error getting picklist values: ' + e.getMessage());
    }
    return picklistValuesMap;
}
@AuraEnabled(cacheable=true)
public static List<String> getRegionsByCountry(String country) {
    Set<String> regions = new Set<String>();
    for (Community__c comm : [SELECT Region__c FROM Community__c WHERE Country__c = :country]) {
        if (comm.Region__c != null) {
            regions.add(comm.Region__c);
        }
    }
    List<String> sortedRegions = new List<String>(regions);
    sortedRegions.sort();
    return sortedRegions;
}
    
}