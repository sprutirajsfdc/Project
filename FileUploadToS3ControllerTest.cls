@isTest
public class FileUploadToS3ControllerTest {
    
    // Helper method to create a ContentVersion and return it
    private static ContentVersion createContentVersion(String title, String fileExtension, Blob data) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.' + fileExtension,
            VersionData = data,
            IsMajorVersion = true
        );
        insert cv;
        
        return [SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    }
    
    @isTest
    static void testSuccessfulUpload() {
        
        // Set up listing without a property
        Listing__c testListing = new Listing__c(Name = 'Test Listing'); 
        insert testListing;
        
        // Create file smaller than 10 MB (e.g. 1 MB)
        Blob fileBody = Blob.valueOf('a'.repeat(1024 * 1024)); // 1 MB string blob
        ContentVersion cv = createContentVersion('SmallFile', 'txt', fileBody);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new DummyHttpCalloutMock());
        FileUploadToS3Controller.UploadResponse response = FileUploadToS3Controller.uploadToS3FromContentVersion(testListing.Id, cv.ContentDocumentId);
        String jobName = 'Test Job Tracker';
        ID jobId = System.enqueueJob(new S3UploaderQueueable(testListing.Id, 'test1', fileBody));
        FileUploadToS3Controller.getJobStatus(jobId);
        Test.stopTest();
        
        System.assertEquals('SmallFile', response.fileName, 'FileName should match');
        System.assertEquals(false, response.bError, 'bError should be false for small file');
        
        // Confirm ContentDocument is deleted
        Integer countCD = [SELECT count() FROM ContentDocument WHERE Id = :cv.ContentDocumentId];
        System.assertEquals(0, countCD, 'ContentDocument should be deleted');
    }
    
    
    @isTest
    static void testNullContentVersion() {
        // Set up listing without a property
        Listing__c testListing = new Listing__c(Name = 'Test Listing');
        insert testListing;
        
        // Pass invalid ContentDocumentId to simulate no record found
        FileUploadToS3Controller.UploadResponse response = FileUploadToS3Controller.uploadToS3FromContentVersion(testListing.Id, '001');
        
        System.assertEquals(null, response.fileName, 'fileName should be empty');
        System.assertEquals(true, response.bError, 'bError should be true if no ContentVersion found');
    }
    
    // Dummy HTTP Mock if your S3ImageUploader makes HTTP callouts (adjust accordingly) 
    public class DummyHttpCalloutMock implements HttpCalloutMock { 
        public HTTPResponse respond(HTTPRequest req) { 
            HttpResponse res = new HttpResponse(); 
            res.setHeader('Content-Type', 'application/json'); 
            res.setBody('{"url": "https://dummy-s3-url.com/test.jpg"}'); 
            res.setStatusCode(200); return res; 
        } 
    }
}