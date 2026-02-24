/**
* @File Name : PropertyMediaControllerTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : June 25, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | June 25, 2025 |   | Initial Version
**/

@isTest
public class PropertyMediaControllerTest {

   @testSetup
    static void setupData() {
        // Create a test Listing
        Listing__c listing = new Listing__c(
            Name = 'Test Listing',
            Watermark_Enabled__c = true
        );
        insert listing;

        // Create a ContentVersion (simulate file upload)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.jpg',
            VersionData = Blob.valueOf('Test File Content')
        );
        insert cv;

        // Get ContentDocumentId
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        // Create a test Property_Media__c record
        Property_Media__c pm = new Property_Media__c(
            Listing__c = listing.Id,
            Tag__c = 'Exterior',
            Sort_on_Website__c = 1,
            Public_URL__c = 'https://example.com/public.jpg',
            Watermark_URL__c = 'https://example.com/watermark.jpg',
            ContentDocumentId__c = contentDocumentId
        );
        insert pm;
    }

    @isTest
    static void testGetPropertyMedia() {
        // Get listing
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

        Test.startTest();
        List<PropertyMediaController.PropertyMediaDTO> mediaList = PropertyMediaController.getPropertyMedia(listing.Id);
        Test.stopTest();

        System.assertNotEquals(null, mediaList);
        System.assertEquals(1, mediaList.size());
        System.assertEquals('Exterior', mediaList[0].Tag);
        System.assert(mediaList[0].Public_URL.contains('watermark.jpg'), 'Watermark URL should be used');
    }

    @isTest
    static void testGetCDLink() {
        // Get listing
        Listing__c listing = [SELECT Id FROM Listing__c LIMIT 1];

        Test.startTest();
        List<PropertyMediaController.PropertyMediaDTO> mediaList = PropertyMediaController.getCDLink(listing.Id);
        Test.stopTest();

        System.assertNotEquals(null, mediaList);
        System.assertEquals(1, mediaList.size());
        System.assertNotEquals(null, mediaList[0].versionData);
    }

    @isTest
    static void testGetCDLink_noMedia_shouldThrow() {
        // Create a listing without media
        Listing__c newListing = new Listing__c(Name = 'No Media Listing', Watermark_Enabled__c = false);
        insert newListing;

        Test.startTest();
        try {
            PropertyMediaController.getCDLink(newListing.Id);
            System.assert(false, 'Expected exception was not thrown.');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}