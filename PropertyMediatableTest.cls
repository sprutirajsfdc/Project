@isTest
public class PropertyMediatableTest {
    
    @isTest
    static void testGetMediaRecords() {
        Id listingId = createTestListing();

        Property_Media__c media = new Property_Media__c(
            Name = 'Test Media',
            Listing__c = listingId,
            Tag__c = 'Photo',
            os_ExternalLink__c = 'https://example.com/image.jpg',
            os_IsOnExpose__c = true,
            os_IsOnPortalFeed__c = false,
            os_IsOnWebsite__c = true,
            Public_URL__c = 'https://public.example.com/image.jpg'
        );
        insert media;

        Test.startTest();
        List<Property_Media__c> results = PropertyMediatable.getMediaRecords(listingId);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one media record');
        System.assertEquals(media.Id, results[0].Id, 'Returned media should match inserted one');
    }

    @isTest
    static void testUpdateMedia() {
        Id listingId = createTestListing();

        Property_Media__c media = new Property_Media__c(
            Name = 'Original Media',
            Listing__c = listingId,
            Tag__c = 'Floorplan'
        );
        insert media;

        media.Tag__c = 'Updated Tag';

        Test.startTest();
        PropertyMediatable.updateMedia(media);
        Test.stopTest();

        Property_Media__c updated = [SELECT Tag__c FROM Property_Media__c WHERE Id = :media.Id];
        System.assertEquals('Updated Tag', updated.Tag__c, 'Tag should be updated');
    }

    @isTest
    static void testDeleteMedia() {
        Id listingId = createTestListing();

        Property_Media__c media = new Property_Media__c(
            Name = 'Media to Delete',
            Listing__c = listingId
        );
        insert media;

        Test.startTest();
        PropertyMediatable.deleteMedia(media.Id);
        Test.stopTest();

        Integer count = [SELECT count() FROM Property_Media__c WHERE Id = :media.Id];
        System.assertEquals(0, count, 'Media should be deleted');
    }

    @isTest
    static void testUploadAndCreateMedia() {
        Id listingId = createTestListing();

        String fileName = 'test_video.mp4';
        String fakeBase64 = EncodingUtil.base64Encode(Blob.valueOf('Fake video data'));
        String tag = 'Virtual Tour';

        Test.startTest();
        // Correct parameter order: listingId, fileName, base64Data, tag
        Property_Media__c result = PropertyMediatable.uploadAndCreateMedia(listingId, fileName, fakeBase64, tag);
        Test.stopTest();

        // Verify the media was created
        Property_Media__c createdMedia = [SELECT Id, Name, Tag__c, Listing__c, Public_URL__c, Property__c
                                         FROM Property_Media__c 
                                         WHERE Id = :result.Id];
        
        System.assertEquals(fileName, createdMedia.Name, 'File name should match');
        System.assertEquals(tag, createdMedia.Tag__c, 'Tag should match');
        System.assertEquals(listingId, createdMedia.Listing__c, 'Listing ID should match');
        System.assertNotEquals(null, createdMedia.Public_URL__c, 'Public URL should be set');
        System.assertNotEquals(null, createdMedia.Property__c, 'Property should be created');
    }

    @isTest
    static void testUploadAndCreateMediaWithExistingProperty() {
        // Create a property first
        Property__c property = new Property__c(Name = 'Test Property');
        insert property;
        
        // Create listing with existing property
        Listing__c listing = new Listing__c(Name = 'Test Listing', Property__c = property.Id);
        insert listing;

        String fileName = 'test_image.jpg';
        String fakeBase64 = EncodingUtil.base64Encode(Blob.valueOf('Fake image data'));
        String tag = 'Photo';

        Test.startTest();
        Property_Media__c result = PropertyMediatable.uploadAndCreateMedia(listing.Id, fileName, fakeBase64, tag);
        Test.stopTest();

        Property_Media__c createdMedia = [SELECT Property__c FROM Property_Media__c WHERE Id = :result.Id];
        System.assertEquals(property.Id, createdMedia.Property__c, 'Should use existing property');
    }

    @isTest
    static void testUploadAndCreateMediaListingNotFound() {
        String fakeListingId = 'a006q00000ABCDEAAA'; // Fake ID
        
        Test.startTest();
        try {
            Property_Media__c result = PropertyMediatable.uploadAndCreateMedia(fakeListingId, 'test.jpg', 'fakebase64', 'Photo');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    // Helper to insert a test listing
    private static Id createTestListing() {
        Listing__c listing = new Listing__c(Name = 'Test Listing');
        insert listing;
        return listing.Id;
    }
}