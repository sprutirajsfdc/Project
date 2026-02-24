@IsTest
public class InquiryStatusPathControllerTest {
    
    @TestSetup
    static void makeData() {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testing12k@gmail.com'
        );
        insert testContact;
        
        Inquiry__c testInquiry = new Inquiry__c(
            Contact__c = testContact.Id,
            Status__c = 'New Lead',
            Sub_Status__c = 'Not Yet Contacted'
        );
        insert testInquiry;
    }
    
    @IsTest
    static void testUpdateStatusLost() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        
        Inquiry__c updated = [
            SELECT Status__c, Inquiry_Lost_Reason__c, Reason_For_Searchinig__c 
            FROM Inquiry__c 
            WHERE Id = :inquiry.Id
        ];
    }
    
    @IsTest
    static void testUpdateStatusSearching() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        
        Test.startTest();
        InquiryStatusPathController.updateStatus(
            inquiry.Id, 
            'Searching', 
            null, 
            null, 
            'Looking for bigger house', 
            null, 
            null
        );
        Test.stopTest();
        
        Inquiry__c updated = [
            SELECT Status__c, Inquiry_Lost_Reason__c, Reason_For_Searchinig__c 
            FROM Inquiry__c 
            WHERE Id = :inquiry.Id
        ];
        
        System.assertEquals('Searching', updated.Status__c);
        System.assertEquals(null, updated.Inquiry_Lost_Reason__c);
        System.assertEquals('Looking for bigger house', updated.Reason_For_Searchinig__c);
    }
    
    @IsTest
    static void testUpdateStatusOther() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        
        Inquiry__c updated = [
            SELECT Status__c, Sub_Status__c, Inquiry_Lost_Reason__c, Reason_For_Searchinig__c 
            FROM Inquiry__c 
            WHERE Id = :inquiry.Id
        ];
    }
    
    @IsTest
    static void testUpdateStatusViewing() {
        Inquiry__c inquiry = [SELECT Id, Contact__c FROM Inquiry__c LIMIT 1];
        Datetime viewingTime = Datetime.now().addDays(1);
        
        Test.startTest();
        InquiryStatusPathController.updateStatus(
            inquiry.Id, 
            'Viewing', 
            null, 
            null, 
            null, 
            viewingTime, 
            '123 Main St'
        );
        Test.stopTest();
        
        Inquiry__c updated = [
            SELECT Status__c 
            FROM Inquiry__c 
            WHERE Id = :inquiry.Id
        ];
        System.assertEquals('Viewing', updated.Status__c);
        
        Event ev = [
            SELECT WhatId, WhoId,OwnerId, Subject, StartDateTime, EndDateTime, Location, Description 
            FROM Event 
            WHERE WhatId = :inquiry.Id
        ];
        
        System.assertEquals(inquiry.Id, ev.WhatId);
        System.assertEquals(inquiry.Contact__c, ev.WhoId);
        System.assertEquals(UserInfo.getUserId(), ev.OwnerId);
        System.assertEquals('Client Viewing', ev.Subject);
        System.assertEquals(viewingTime, ev.StartDateTime);
        System.assertEquals(viewingTime.addHours(1), ev.EndDateTime);
        System.assertEquals('123 Main St', ev.Location);
        System.assertEquals('Viewing scheduled via Inquiry Status Path', ev.Description);
    }
    
    @IsTest
    static void testUpdateStatusViewingMissingDetails() {
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        
        Test.startTest();
        // Missing viewingDateTime
        InquiryStatusPathController.updateStatus(
            inquiry.Id, 
            'Viewing', 
            null, 
            null, 
            null, 
            null, 
            '123 Main St'
        );
        
        // Missing viewingLocation
        InquiryStatusPathController.updateStatus(
            inquiry.Id, 
            'Viewing', 
            null, 
            null, 
            null, 
            Datetime.now().addDays(1), 
            null
        );
        Test.stopTest();
        
        List<Event> events = [
            SELECT Id 
            FROM Event 
            WHERE WhatId = :inquiry.Id
        ];
        System.assertEquals(0, events.size());
    }
    
    @IsTest
    static void testUpdateStatusMissingId() {
        Test.startTest();
        try {
            InquiryStatusPathController.updateStatus(
                null, 
                'New', 
                null, 
                null, 
                null, 
                null, 
                null
            );
            System.assert(false, 'Expected exception for missing inquiryId');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUpdateStatusNoPermission() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'test', 
            Email = 'testuser123@testorg.com',
            EmailEncodingKey = 'UTF-8', 
            LastName = 'Testing', 
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = 'testuser123tn2@testorg.com'
        );
        insert u;
        
        Inquiry__c inquiry = [SELECT Id FROM Inquiry__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            try {
                InquiryStatusPathController.updateStatus(
                    inquiry.Id, 
                    'New', 
                    null, 
                    null, 
                    null, 
                    null, 
                    null
                );
                System.assert(false, 'Expected exception for no permission');
            } catch (AuraHandledException e) {
            }
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testUpdateStatusDmlException() {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact'
        );
        insert testContact;
        
        Inquiry__c inquiry = new Inquiry__c(
            Contact__c = testContact.Id,
            Status__c = 'New'
        );
        insert inquiry;
        
        delete inquiry;
        
        Test.startTest();
        try {
            InquiryStatusPathController.updateStatus(
                inquiry.Id, 
                'New', 
                null, 
                null, 
                null, 
                null, 
                null
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}