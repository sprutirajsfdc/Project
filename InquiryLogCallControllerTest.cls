@IsTest
private class InquiryLogCallControllerTest {

    @TestSetup
    static void setupData() {
        // Create a contact and account for WhoId / WhatId associations
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;
    }

    @IsTest
    static void testGetCallOutcomePicklistValues() {
        Test.startTest();
        List<String> values = InquiryLogCallController.getCallOutcomePicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, values, 'Returned list should not be null');
        System.assert(values.size() >= 0,
            'List should be empty or contain picklist values'); 
        // No instanceof check needed, Apex guarantees List<String>
    }

    @IsTest
    static void testCreateCallTask_withValidInputs() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Account a = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        InquiryLogCallController.createCallTask(
            c.Id,
            'Follow-up Call',
            'Spoke with customer about new inquiry.',
            'Completed',   // Try using a valid label/value
            a.Id
        );
        Test.stopTest();

        Task t = [
            SELECT Id, Subject, Status, Type, Call_Outcome__c,
                   WhoId, WhatId, OwnerId, ActivityDate
            FROM Task WHERE WhoId = :c.Id LIMIT 1
        ];

        System.assertEquals('Follow-up Call', t.Subject, 'Subject should be set');
        System.assertEquals(UserInfo.getUserId(), t.OwnerId, 'Owner should be current user');
        System.assertEquals(Date.today(), t.ActivityDate, 'ActivityDate should default to today');
        System.assertEquals(c.Id, t.WhoId, 'WhoId should map');
        System.assertEquals(a.Id, t.WhatId, 'WhatId should map');
        System.assertNotEquals(null, t.Status, 'Status should be set');
        System.assertNotEquals(null, t.Type, 'Type should be set');
    }

    @IsTest
    static void testCreateCallTask_withDefaults() {
        Test.startTest();
        // Minimal input, will fallback to defaults
        InquiryLogCallController.createCallTask(null, null, null, null, null);
        Test.stopTest();

        Task t = [
            SELECT Id, Subject, Status, Type, OwnerId, ActivityDate
            FROM Task ORDER BY CreatedDate DESC LIMIT 1
        ];

        System.assertEquals('Call Logged', t.Subject, 'Default subject should be applied');
        System.assertEquals(UserInfo.getUserId(), t.OwnerId, 'Owner should be current user');
        System.assertEquals(Date.today(), t.ActivityDate, 'ActivityDate should default to today');
    }

    @IsTest
    static void testCreateCallTask_invalidOutcomeGraceful() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        InquiryLogCallController.createCallTask(
            c.Id,
            'Bad Outcome Call',
            'Testing invalid outcome mapping',
            'NotARealOutcome', // Should fail gracefully
            null
        );
        Test.stopTest();

        Task t = [
            SELECT Id, Subject, Call_Outcome__c
            FROM Task WHERE Subject = 'Bad Outcome Call' LIMIT 1
        ];

        System.assertEquals(null, t.Call_Outcome__c,
            'Invalid outcome should not assign anything');
    }
}