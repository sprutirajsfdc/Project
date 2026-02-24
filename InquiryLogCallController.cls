/**
* @File Name : InquiryLogCallController.cls
* @Description : Call outcome options + create call task (hardened)
* @Author :
* @Last Modified By :
* @Last Modified On : Aug 12, 2025
* @Modification Log :
*==============================================================================
* Ver | Date        | Author | Modification
*==============================================================================
* 1.2 | Aug 12, 2025|       | Replace isPicklist() with DisplayType checks
* 1.1 | Aug 12, 2025|       | FLS/CRUD, label→value mapping, safe picklists
* 1.0 | July 27, 25 |       | Initial Version
**/
public with sharing class InquiryLogCallController {

    // 🔁 LWC uses this to populate the dropdown (labels for UX)
    @AuraEnabled(cacheable=true)
    public static List<String> getCallOutcomePicklistValues() {
        List<String> labels = new List<String>();
        try {
            Schema.DescribeFieldResult fr = Task.Call_Outcome__c.getDescribe();
            if (!fr.isAccessible()) return labels;
            Schema.DisplayType t = fr.getType();
            if (t != Schema.DisplayType.Picklist && t != Schema.DisplayType.MultiPicklist) return labels;

            for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
                if (pe.isActive()) labels.add(pe.getLabel());
            }
        } catch (Exception ignore) {
            // Quiet fallback: return empty list
        }
        return labels;
    }

    // ✅ Create a new Task (call log) — safe even if admin tweaked picklists
    @AuraEnabled
    public static void createCallTask(Id whoId, String subject, String comments, String callOutcome, Id whatId) {
        // CRUD: must be able to create Task
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

        // 💬 Type = 'Call' if valid
        String typeVal = picklistValueOrFirst('Task', 'Type', 'Call');
        if (!String.isBlank(typeVal) && isFieldUpdateable(Task.Type)) {
            t.Type = typeVal;
        }

        // ✅ Status prefer 'Completed' else first active
        String statusVal = picklistValueOrFirst('Task', 'Status', 'Completed');
        if (!String.isBlank(statusVal) && isFieldUpdateable(Task.Status)) {
            t.Status = statusVal;
        }

        // 🎯 Map incoming label/value → actual API value for Call_Outcome__c
        if (!String.isBlank(callOutcome) && isFieldUpdateable(Task.Call_Outcome__c)) {
            String resolved = mapLabelOrValueToValue(Task.Call_Outcome__c, callOutcome);
            if (!String.isBlank(resolved)) {
                t.Call_Outcome__c = resolved; // assign API value
            }
        }

        // Strip fields user can’t set; then insert
        List<SObject> wrap = new List<SObject>{ t };
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.CREATABLE, wrap);
        Task clean = (Task) dec.getRecords()[0];

        try {
            insert clean;
        } catch (DmlException dx) {
            String msg = (dx.getNumDml() > 0 && dx.getDmlMessage(0) != null) ? dx.getDmlMessage(0) : dx.getMessage();
            throw new AuraHandledException('Log Call failed: ' + msg);
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    // Returns preferred value if valid; else first active; else null
    private static String picklistValueOrFirst(String sobjectApi, String fieldApi, String preferredLabelOrValue) {
        Schema.DescribeFieldResult fr = getDescribe(sobjectApi, fieldApi);
        if (fr == null || !fr.isAccessible()) return null;

        Schema.DisplayType t = fr.getType();
        if (t != Schema.DisplayType.Picklist && t != Schema.DisplayType.MultiPicklist) return null;

        String preferred = null;
        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (!pe.isActive()) continue;
            if (equalsIC(pe.getLabel(), preferredLabelOrValue) || equalsIC(pe.getValue(), preferredLabelOrValue)) {
                preferred = pe.getValue(); break;
            }
        }
        if (preferred != null) return preferred;

        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (pe.isActive()) return pe.getValue();
        }
        return null;
    }

    // Map label OR value → canonical value for a strongly-typed field
    private static String mapLabelOrValueToValue(Schema.SObjectField fieldRef, String incoming) {
        Schema.DescribeFieldResult fr = fieldRef.getDescribe();
        if (!fr.isAccessible()) return null;

        Schema.DisplayType t = fr.getType();
        if (t != Schema.DisplayType.Picklist && t != Schema.DisplayType.MultiPicklist) return null;

        for (Schema.PicklistEntry pe : fr.getPicklistValues()) {
            if (!pe.isActive()) continue;
            if (equalsIC(pe.getLabel(), incoming) || equalsIC(pe.getValue(), incoming)) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static Boolean isFieldUpdateable(Schema.SObjectField f) {
        try { return f.getDescribe().isUpdateable(); } catch (Exception e) { return false; }
    }

    private static Schema.DescribeFieldResult getDescribe(String sobjectApi, String fieldApi) {
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

    private static Boolean equalsIC(String a, String b) {
        return (a == null || b == null) ? false : a.trim().toLowerCase() == b.trim().toLowerCase();
    }
}