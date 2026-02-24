public class FileUploadToS3Controller {
    @AuraEnabled
    public static UploadResponse uploadToS3FromContentVersion(String recordId, String contentDocId) {
        UploadResponse response = new UploadResponse();
        response.bError = false;
        try{
            
            ContentVersion cv = [
                SELECT Id, Title, VersionData, FileExtension, ContentSize
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocId
                LIMIT 1
            ];
            
            if(cv == null){
                response.bError = true;
                response.fileName = '';
                return response;
            }
            
            String fileName = cv.Title + '.' + cv.FileExtension;
            Blob fileBlob = cv.VersionData;
            response.fileName =  cv.Title;
            
            //Give error if image size is greater 10 mb
            if(cv.ContentSize > 10000000){
                response.bError = true;
                deleteContentDoc(contentDocId);
                return response;
            }
            
            // Call your S3 uploader
            Id jobId = System.enqueueJob(new S3UploaderQueueable(recordId, fileName, fileBlob));
            response.jobId = jobId;
            
            //Delete Document
            deleteContentDoc(contentDocId);
        }
        catch(Exception e){
            system.debug('Upload Error: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            response.bError = true;
            return response;
        }
        
        return response;
    }
    
    //Delete the content document
    public static void deleteContentDoc(String sContentDocId){
        List<ContentDocument> lstCD = [Select Id from ContentDocument where Id = :sContentDocId];
        if(!lstCD.isEmpty()){
            Delete lstCD;
        }
    }
    
    public class UploadResponse {
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean bError;
        @AuraEnabled public String jobId;
    }
    
    @AuraEnabled
    public static string getJobStatus(String sJobId){
        AsyncApexJob job = [SELECT Id, Status, JobType, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate
                            FROM AsyncApexJob
                            WHERE Id = :sJobId];
        System.debug('Status: ' + job.Status);
        return job.Status;
    }
}