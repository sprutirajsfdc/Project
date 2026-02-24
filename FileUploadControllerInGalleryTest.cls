@isTest
private class FileUploadControllerInGalleryTest {

    static testMethod void testUploadFile() {
        Listing__c testListing = new Listing__c(Name = 'Test Listing');
        insert testListing;

        String fileName = 'TestImage.png';
        String sampleBase64Data = EncodingUtil.base64Encode(Blob.valueOf('Sample Image Content'));

        Test.startTest();
        FileUploadControllerInGallery.uploadFile(fileName, sampleBase64Data, testListing.Id);
        Test.stopTest();

        Listing__c updatedListing = [SELECT Property__c FROM Listing__c WHERE Id = :testListing.Id LIMIT 1];
        System.assertNotEquals(null, updatedListing.Property__c, 'Property__c should be populated');

        Property_Media__c media = [
            SELECT Id, Public_URL__c, Listing__c, Property__c, Sort_On_Website__c
            FROM Property_Media__c
            WHERE Listing__c = :testListing.Id
            LIMIT 1
        ];

        System.assertEquals(testListing.Id, media.Listing__c);
        System.assertEquals(updatedListing.Property__c, media.Property__c);
    }

    static testMethod void testGetUploadedImages() {
        Property__c testProperty = new Property__c(Name = 'Test Property');
        insert testProperty;

        Listing__c testListing = new Listing__c(Name = 'Test Listing', Property__c = testProperty.Id);
        insert testListing;

        Property_Media__c media = new Property_Media__c();
        media.Property__c = testProperty.Id;
        media.Listing__c = testListing.Id;
        media.Name = 'Test Media';
        media.Sort_On_Website__c = 1;
        insert media;

        Test.startTest();
        List<Property_Media__c> images = FileUploadControllerInGallery.getUploadedImages(testListing.Id);
        Test.stopTest();

        System.assertEquals(1, images.size());
        System.assertEquals(media.Id, images[0].Id);
        System.assertEquals(1, images[0].Sort_On_Website__c);
    }

    static testMethod void testUpdateImageOrder() {
        Property__c testProperty = new Property__c(Name = 'Test Property');
        insert testProperty;

        Listing__c testListing = new Listing__c(Name = 'Test Listing', Property__c = testProperty.Id);
        insert testListing;

        Property_Media__c media1 = new Property_Media__c(Property__c = testProperty.Id, Listing__c = testListing.Id, Name = 'Media 1', Sort_On_Website__c = 1);
        Property_Media__c media2 = new Property_Media__c(Property__c = testProperty.Id, Listing__c = testListing.Id, Name = 'Media 2', Sort_On_Website__c = 2);
        insert new List<Property_Media__c>{media1, media2};

        List<Map<String, Object>> updateList = new List<Map<String, Object>>();
        updateList.add(new Map<String, Object>{ 'id' => media1.Id, 'serialNumber' => 2 });
        updateList.add(new Map<String, Object>{ 'id' => media2.Id, 'serialNumber' => 1 });

        Test.startTest();
        FileUploadControllerInGallery.updateImageOrder(updateList);
        Test.stopTest();

        List<Property_Media__c> updatedMedia = [
            SELECT Id, Sort_On_Website__c
            FROM Property_Media__c
            WHERE Property__c = :testProperty.Id
            ORDER BY Sort_On_Website__c ASC
        ];

        System.assertEquals(media2.Id, updatedMedia[0].Id);
        System.assertEquals(media1.Id, updatedMedia[1].Id);
    }

    static testMethod void testDeleteMediaRecord() {
        Property__c testProperty = new Property__c(Name = 'Test Property');
        insert testProperty;

        Listing__c testListing = new Listing__c(Name = 'Test Listing', Property__c = testProperty.Id);
        insert testListing;

        Property_Media__c media = new Property_Media__c(
            Name = 'Test Media To Delete',
            Property__c = testProperty.Id,
            Listing__c = testListing.Id,
            Sort_On_Website__c = 1
        );
        insert media;

        System.assertNotEquals(null, media.Id);

        Test.startTest();
        FileUploadControllerInGallery.deleteMediaRecord(media.Id);
        Test.stopTest();

        // Confirm record is deleted
        List<Property_Media__c> result = [SELECT Id FROM Property_Media__c WHERE Id = :media.Id];
        System.assertEquals(0, result.size(), 'Media should be deleted');
    }

    @isTest
    static void testUploadFileWaterMark() {
        Listing__c listing = new Listing__c(
            Name = 'Test Listing'
        );
        insert listing;

        Property_Media__c media = new Property_Media__c(
            Listing__c = listing.Id,
            Public_URL__c = 'https://dummy.com/image.jpg'
        );
        insert media;

        String fileName = 'testWatermark.jpg';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy image data'));
        String recordId = listing.Id;
        String propMediaId = media.Id;

        Test.startTest();
        FileUploadControllerInGallery.uploadFileWaterMark(fileName, base64Data, recordId, propMediaId);
        Test.stopTest();

        Property_Media__c updatedMedia = [
            SELECT Watermark_URL__c FROM Property_Media__c WHERE Id = :media.Id
        ];

    }
}