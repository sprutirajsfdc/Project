@isTest
private class PortalControllerTest {

    // Helper method to insert test data
    private static void setupTestData() {
        // Create a test portal with real field API names
        Portals_Custom__c portal = new Portals_Custom__c(
            Name = 'Dubai Website',
            isActive__c = true,
            URL__c = 'https://example.com',
            Allowed_for_Regions__c = 'UAE',
            Normalized_Name__c = 'dubai website',
            Publish_Field__c = 'Publish_on_Dubai_SIR_Website__c',
            Publish_Date_Field__c = 'Published_Date_Dubai_SIR_Website__c',
            Withdraw_Date_Field__c = 'Withdrawn_Date_Dubai_SIR_Website__c'
        );
        insert portal;

        // Create a test property
        Property__c prop = new Property__c(Name = 'Test Property');
        insert prop;

        // Create a test listing
        Listing__c listing = new Listing__c(
            Name = 'Test Listing',
            Listing_Region__c = 'Dubai Listing',
            Property__c = prop.Id
        );
        insert listing;

        // Create property media
        Property_Media__c media = new Property_Media__c(Property__c = prop.Id);
        insert media;
    }

    @isTest
    static void testGetPortalsByRegion() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
    @isTest
    static void testGetPortalsByRegionUK() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'UK Website';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
    @isTest
    static void testGetPortalsByRegionAD() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'Abu Dhabi Website';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
    @isTest
    static void testGetPortalsByRegionKSA() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'KSA Website';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
     @isTest
    static void testGetPortalsByRegionprop() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'Properstar';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
    @isTest
    static void testGetPortalsByRegionJE() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'James Edition';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
    @isTest
    static void testGetPortalsByRegionLE() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'Luxury Estate';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }
    
    @isTest
    static void testGetPortalsByRegionPF() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];
        portal.Name = 'Property Finder';
        update portal;

        Test.startTest();
        List<PortalController.PortalsWrapper> portals = PortalController.getPortalsByRegion(listing.Id);
        Test.stopTest();

        System.assertNotEquals(0, portals.size(), 'Should return at least one portal.');
        System.assertEquals('Active', portals[0].portalStatus);
    }



    @isTest
    static void testUpdatePortal() {
        
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        Portals_Custom__c portal = [SELECT Id FROM Portals_Custom__c LIMIT 1];

        Test.startTest();
        PortalController.publish_Or_Unpublish(listing.Id, 'Dubai Website', true);
        Test.stopTest();
        
        Portals_Custom__c updatedPortal = [SELECT Name, isActive__c FROM Portals_Custom__c WHERE Id = :portal.Id];
        System.assertEquals('Dubai Website', updatedPortal.Name);
        System.assertEquals(true, updatedPortal.isActive__c);
    }

    @isTest
    static void testPublishListing() {
        Listing__c listing = new Listing__c(
            Name = 'ListingNoMedia',
            Listing_Region__c = 'Dubai Listing',
            City__c = 'Dubai'
        );
        insert listing;
        
        Test.startTest();
        String result = PortalController.fetchPropertyMedia(listing.Id);
        Test.stopTest();

    }

    @isTest
    static void testFetchPropertyMedia() {
        setupTestData();
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];
        listing.Status__c = 'Published';
        listing.City__c = 'Dubai';
        listing.Country__c = 'UAE';
        listing.Property_Type__c = 'Villa';
        update listing;

        Test.startTest();
        String result = PortalController.fetchPropertyMedia(listing.Id);
        Test.stopTest();

        System.assertEquals('Listing has media', result);
    }

    @isTest
    static void testFetchPropertyMediaWithNoMedia() {
        Property__c prop = new Property__c(Name = 'NoMediaProp');
        insert prop;

        Listing__c listing = new Listing__c(
            Name = 'ListingNoMedia',
            Listing_Region__c = 'Dubai Listing',
            Property__c = prop.Id,
            Status__c = 'Published',
            City__c = 'Dubai',
            Country__c = 'UAE',
            Property_Type__c = 'Villa'
        );
        insert listing;

        Test.startTest();
        String result = PortalController.fetchPropertyMedia(listing.Id);
        Test.stopTest();

        System.assertEquals('Please upload images before proceeding to publish.', result);
    }

@isTest
static void testCheckUserProfile() {
    
    List<Profile> profilesWithAgent = [SELECT Id, Name FROM Profile WHERE Name LIKE '%Agent%' LIMIT 1];
    Profile agentProfile = profilesWithAgent.isEmpty() ? [SELECT Id FROM Profile LIMIT 1] : profilesWithAgent[0];

    
    User agentUser = new User(
        FirstName = 'Test',
        LastName = 'AgentUser',
        Email = 'testagent@example.com',
        Username = 'testagent' + System.currentTimeMillis() + '@example.com',
        Alias = 'tagent',
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        ProfileId = agentProfile.Id,
        LanguageLocaleKey = 'en_US'
    );
    insert agentUser;

    
    List<Profile> profilesWithoutAgent = [SELECT Id, Name FROM Profile WHERE NOT Name LIKE '%Agent%' LIMIT 1];
    Profile managerProfile = profilesWithoutAgent.isEmpty() ? [SELECT Id FROM Profile LIMIT 1] : profilesWithoutAgent[0];

    
    User managerUser = new User(
        FirstName = 'Test',
        LastName = 'ManagerUser',
        Email = 'testmanager@example.com',
        Username = 'testmanager' + System.currentTimeMillis() + '@example.com',
        Alias = 'tman',
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        ProfileId = managerProfile.Id,
        LanguageLocaleKey = 'en_US'
    );
    insert managerUser;

    
    Test.startTest();

    System.runAs(agentUser) {
        Boolean result = PortalController.checkUserProfile();
        System.assertEquals(false, result, 'Agent users should not have publish access.');
    }


    System.runAs(managerUser) {
        Boolean result = PortalController.checkUserProfile();
        System.assertEquals(true, result, 'Non-agent users should have publish access.');
    }

    Test.stopTest();
}


}