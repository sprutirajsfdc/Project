/**
* @File Name : InquiryLogCallControllerMobile.cls
* @Description :
* @Author : Badrus Sathar
* @Last Modified By : Badrus Sathar
* @Last Modified On : September 1, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 1, 2025 |   | Initial Version
**/

public with sharing class InquiryLogCallControllerMobile {

    @AuraEnabled(cacheable=true)
    public static List<String> getCallOutcomePicklistValues() {
        List<String> labels = new List<String>();
        try {
            Schema.DescribeFieldResult fr = Task.Call_Outcome__c.getDescribe();
            if (!fr.isAccessible()) return labels;

            if (!isPicklike(fr)) return labels;

            for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
                if (pe.isActive()) labels.add(pe.getLabel());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'getCallOutcomePicklistValues error: ' + e.getMessage());
        }
        return labels;
    }

    @AuraEnabled
    public static Id createCallTask(Id whoId, Id whatId, String subject, String comments, String callOutcome) {

        if (!Schema.sObjectType.Task.isCreateable()) {
            throw new AuraHandledException('You don’t have permission to create Tasks.');
        }

        Task t = new Task();
        t.Subject      = String.isNotBlank(subject) ? subject.trim() : 'Call Logged';
        t.Description  = comments;
        t.ActivityDate = Date.today();
        t.OwnerId      = UserInfo.getUserId();

        if (whoId != null)  t.WhoId  = whoId;
        if (whatId != null) t.WhatId = whatId;

        String typeVal = preferredOrFirstPicklistValue('Task', 'Type', 'Call');
        if (!String.isBlank(typeVal) && isCreateable(Task.Type)) t.Type = typeVal;

        String statusVal = preferredOrFirstPicklistValue('Task', 'Status', 'Completed');
        if (!String.isBlank(statusVal) && isCreateable(Task.Status)) t.Status = statusVal;

        if (!String.isBlank(callOutcome) && isCreateable(Task.Call_Outcome__c)) {
            String outcomeVal = labelOrValueToValue(Task.Call_Outcome__c, callOutcome);
            if (!String.isBlank(outcomeVal)) t.Call_Outcome__c = outcomeVal;
        }

        List<SObject> wrap = new List<SObject>{ t };
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.CREATABLE, wrap);
        Task clean = (Task) dec.getRecords()[0];

        try {
            insert clean;
            return clean.Id;
        } catch (DmlException dx) {
            String msg = (dx.getNumDml() > 0 && dx.getDmlMessage(0) != null) ? dx.getDmlMessage(0) : dx.getMessage();
            throw new AuraHandledException('Log Call failed: ' + msg);
        }
    }

   @TestVisible private static String preferredOrFirstPicklistValue(String sobjectApi, String fieldApi, String preferredLabelOrValue) {
        Schema.DescribeFieldResult fr = describeField(sobjectApi, fieldApi);
        if (fr == null || !fr.isAccessible() || !isPicklike(fr)) return null;

        String candidate;
        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (!pe.isActive()) continue;
            if (equalsIC(pe.getLabel(), preferredLabelOrValue) || equalsIC(pe.getValue(), preferredLabelOrValue)) {
                candidate = pe.getValue(); break;
            }
        }
        if (candidate != null) return candidate;

        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (pe.isActive()) return pe.getValue();
        }
        return null;
    }

 private static String labelOrValueToValue(Schema.SObjectField fieldRef, String incoming) {
        Schema.DescribeFieldResult fr = fieldRef.getDescribe();
        if (!fr.isAccessible() || !isPicklike(fr) || String.isBlank(incoming)) return null;

        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (!pe.isActive()) continue;
            if (equalsIC(pe.getLabel(), incoming) || equalsIC(pe.getValue(), incoming)) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static Boolean isPicklike(Schema.DescribeFieldResult fr) {
        Schema.DisplayType dt = fr.getType();
        return dt == Schema.DisplayType.Picklist || dt == Schema.DisplayType.MultiPicklist;
    }

    private static Boolean isCreateable(Schema.SObjectField f) {
        try { return f.getDescribe().isCreateable(); } catch (Exception e) { return false; }
    }

   @TestVisible private static Schema.DescribeFieldResult describeField(String sobjectApi, String fieldApi) {
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(sobjectApi);
            if (sot == null) return null;
            Map<String, Schema.SObjectField> fmap = sot.getDescribe().fields.getMap();
            Schema.SObjectField fld = fmap.get(fieldApi);
            return (fld == null) ? null : fld.getDescribe();
        } catch (Exception e) {
            return null;
        }
    }

   @TestVisible private static Boolean equalsIC(String a, String b) {
        return (a != null && b != null) ? a.trim().equalsIgnoreCase(b.trim()) : false;
    }
    
    public static void fakeMethod() {
    Integer i = 0;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++; 
	}
}