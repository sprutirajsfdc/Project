public with sharing class AgentActivityController {

    // =========================================================
    // FETCH FULL ACTIVITY (TASKS + EVENTS + INQUIRIES + AGENT)
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAgentFullActivity(Id agentId, Date startDate, Date endDate) {

        Map<String, Object> response = new Map<String, Object>();

        // ------------------ AGENT INFO ------------------
        List<User> agentData = [
            SELECT Id, Name, Title, MobilePhone, Email, AWS_Profile_Url__c
            FROM User
            WHERE Id = :agentId
            LIMIT 1
        ];
        response.put('agent', agentData);

        // ------------------ TASK QUERY ------------------
        String taskQuery = 'SELECT Id, Subject, Status, Priority, ActivityDate, WhatId ' +
                           'FROM Task WHERE OwnerId = :agentId';

        if (startDate != null && endDate != null) {
            taskQuery += ' AND ActivityDate >= :startDate AND ActivityDate <= :endDate';
        }

        taskQuery += ' ORDER BY ActivityDate DESC LIMIT 200';

        List<Task> tasks = Database.query(taskQuery);
        response.put('tasks', tasks);

        // ------------------ EVENT QUERY ------------------
        String eventQuery = 'SELECT Id, Subject, ActivityDate, DurationInMinutes ' +
                            'FROM Event WHERE OwnerId = :agentId';

        if (startDate != null && endDate != null) {
            eventQuery += ' AND ActivityDate >= :startDate AND ActivityDate <= :endDate';
        }

        eventQuery += ' ORDER BY ActivityDate DESC LIMIT 200';

        List<Event> events = Database.query(eventQuery);
        response.put('events', events);

        // ------------------ INQUIRY QUERY ------------------
        List<Inquiry__c> inquiries = [
            SELECT Id, Name, Lead_Source__c, Contact__c,Contact__r.Name,
                   Agency_Inquiry_Type__c, Status__c, Sub_Status__c
            FROM Inquiry__c
            WHERE OwnerId = :agentId
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        response.put('inquiries', inquiries);

        return response;
    }


    // =========================================================
    // FETCH ALL ACTIVE SALES AGENTS (FOR DROPDOWN)
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static List<User> getActiveAgents() {
        return [
            SELECT Id, Name, Title, MobilePhone, Email,
                   IsActive, Profile.Name, AWS_Profile_Url__c
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'Sales Agent'
            ORDER BY Name ASC
        ];
    }

}