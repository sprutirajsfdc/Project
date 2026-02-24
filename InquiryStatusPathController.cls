public with sharing class InquiryStatusPathController {

    @AuraEnabled
    public static void updateStatus(
        Id inquiryId,
        String newStatus,
        String newSubStatus,
        String lostReason,
        String searchReason,
        Datetime viewingDateTime,
        String viewingLocation
    ) {
        try {
            if (inquiryId == null) {
                throw new AuraHandledException('Update failed: Missing Inquiry Id.');
            }
            if (!Schema.sObjectType.Inquiry__c.isAccessible()) {
                throw new AuraHandledException('You don’t have access to read Inquiry.');
            }
            if (!Schema.sObjectType.Inquiry__c.isUpdateable()) {
                throw new AuraHandledException('You don’t have permission to update Inquiry.');
            }
            
            Inquiry__c base = [
                SELECT Id, Contact__c
                FROM Inquiry__c
                WHERE Id = :inquiryId
                LIMIT 1
            ];

            String stNorm      = norm(newStatus);
            String subNorm     = norm(newSubStatus);
            String lostNorm    = norm(lostReason);
            String searchNorm  = norm(searchReason);
            String viewLocNorm = norm(viewingLocation);

            String stLower = (stNorm == null) ? '' : stNorm.toLowerCase();
            
            Inquiry__c upd = new Inquiry__c(Id = base.Id);
            upd.Status__c     = stNorm;
            upd.Sub_Status__c = subNorm;

            if (stLower == 'lost') {
                upd.Inquiry_Lost_Reason__c   = lostNorm;
                upd.Reason_For_Searchinig__c = null;
            } else if (stLower == 'searching') {
                upd.Reason_For_Searchinig__c = searchNorm;
                upd.Inquiry_Lost_Reason__c   = null;
            } else {
                upd.Inquiry_Lost_Reason__c   = null;
                upd.Reason_For_Searchinig__c = null;
            }

            List<SObject> wrap = new List<SObject>{ upd };
            SObjectAccessDecision dec = Security.stripInaccessible(AccessType.UPDATABLE, wrap);
            Inquiry__c cleaned = (Inquiry__c) dec.getRecords()[0];

            update cleaned;

            if (stLower == 'viewing'
                && viewingDateTime != null
                && String.isNotBlank(viewLocNorm)
                && Schema.sObjectType.Event.isCreateable()) {

                Event ev = new Event();
                ev.WhatId        = base.Id;
                if (base.Contact__c != null) ev.WhoId = base.Contact__c;
                ev.OwnerId       = UserInfo.getUserId();
                ev.Subject       = 'Client Viewing';
                ev.StartDateTime = viewingDateTime;
                ev.EndDateTime   = viewingDateTime.addHours(1);
                ev.Location      = viewLocNorm;
                ev.Description   = 'Viewing scheduled via Inquiry Status Path';

                List<SObject> ewrap = new List<SObject>{ ev };
                SObjectAccessDecision edec = Security.stripInaccessible(AccessType.CREATABLE, ewrap);
                Event evClean = (Event) edec.getRecords()[0];
                insert evClean;
            }

        } catch (DmlException dx) {
            String msg = (dx.getNumDml() > 0 && dx.getDmlMessage(0) != null)
                ? dx.getDmlMessage(0)
                : dx.getMessage();
            throw new AuraHandledException('Update failed: ' + msg);
        } catch (Exception ex) {
            throw new AuraHandledException('Update failed: ' + ex.getMessage());
        }
    }

    private static String norm(String s) {
        return String.isBlank(s) ? null : s.trim();
    }
}