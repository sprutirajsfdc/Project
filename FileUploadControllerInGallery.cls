public with sharing class FileUploadControllerInGallery {
    
    // ✅ Upload File from base64 string
    @AuraEnabled
    public static void uploadFile(String fileName, String blobData, String recordId) {
        try {
            // Validation
            if (String.isBlank(blobData)) {
                throw new AuraHandledException('File data is empty.');
            }
            if (String.isBlank(fileName)) {
                throw new AuraHandledException('File name is empty.');
            }	
            if (String.isBlank(recordId)) {
                throw new AuraHandledException('Record ID is required.');
            }
            
            // Decode base64 string to Blob
            Blob decodedBlob = EncodingUtil.base64Decode(blobData);
            
            // Upload to AWS S3 (or handle upload)
            String publicImageURL = S3ImageUploader.filePUT(recordId, fileName, decodedBlob);
            System.debug('Public image: ' + publicImageURL);
            System.debug('RecordId: ' + recordId);
            
            // Fetch or create Property__c
            Listing__c listing = [SELECT Property__c, Name FROM Listing__c WHERE Id = :recordId LIMIT 1];
            
            Id propertyId;
            if (listing.Property__c == null) {
                Property__c newProperty = new Property__c();
                newProperty.Name = 'New Property for ' + listing.Name;
                insert newProperty;
                
                propertyId = newProperty.Id;
                listing.Property__c = propertyId;
                update listing;
            } else {
                propertyId = listing.Property__c;
            }
            // ✅ Now that propertyId is guaranteed, fetch max sort order
            Integer maxSortOrder = 0;
AggregateResult[] results = [
    SELECT MAX(Sort_On_Website__c) maxSort
    FROM Property_Media__c
    WHERE Property__c = :propertyId
];
if (!results.isEmpty() && results[0].get('maxSort') != null) {
    maxSortOrder = Integer.valueOf(String.valueOf(results[0].get('maxSort')));
}
System.debug('Current max Sort_On_Website__c: ' + maxSortOrder);
            
            // Insert Property_Media__c record
            Property_Media__c media = new Property_Media__c();
            media.Property__c = propertyId;
            media.Listing__c = recordId;
            media.Name = fileName;
           media.Sort_On_Website__c = maxSortOrder + 1; 
            media.Public_URL__c = publicImageURL;
            insert media;
            
            // Recalculate sort order
            //recalculateSortOrder(propertyId);
            
        } catch (Exception e) {
            System.debug('Upload Error: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to upload file: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Property_Media__c> getUploadedImages(String recordId) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record ID is required.');
        }
        
        return [
            SELECT Id, Sort_On_Website__c, Public_URL__c, Tag__c, ContentDocumentId__c,Name
            FROM Property_Media__c
            WHERE Listing__c = :recordId
            ORDER BY Sort_On_Website__c ASC
        ];
    }
    
    @AuraEnabled
    public static void updateImageOrder(List<Map<String, Object>> mediaList) {
        if (mediaList != null && !mediaList.isEmpty()) {
            List<Property_Media__c> mediaRecords = new List<Property_Media__c>();
            for (Map<String, Object> item : mediaList) {
                Property_Media__c media = new Property_Media__c();
                media.Id = (String) item.get('id');
                media.Sort_On_Website__c = ((Decimal) item.get('serialNumber')).intValue();
                mediaRecords.add(media);
            }
            
            if (!mediaRecords.isEmpty()) {
                Database.update(mediaRecords, false);
            }
        }
    }
    
    @AuraEnabled
    public static void updateTagForMedia(Id mediaId, String newTag) {
        Property_Media__c media = [SELECT Id, Tag__c FROM Property_Media__c WHERE Id = :mediaId LIMIT 1];
        media.Tag__c = newTag;
        update media;
    }
    
    @AuraEnabled
    public static void deleteMediaRecord(Id mediaId) {
        try {
            Property_Media__c media = [SELECT Id, Property__c FROM Property_Media__c WHERE Id = :mediaId LIMIT 1];
            Id propertyId = media.Property__c;
            
            delete media;
            
            // Recalculate sort order
            recalculateSortOrder(propertyId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting media: ' + e.getMessage());
        }
    }
    
    private static void recalculateSortOrder(Id propertyId) {
        List<Property_Media__c> mediaList = [
            SELECT Id
            FROM Property_Media__c
            WHERE Property__c = :propertyId
            ORDER BY Sort_On_Website__c ASC, CreatedDate ASC
        ];
        
        Integer counter = 1;
        for (Property_Media__c media : mediaList) {
            media.Sort_On_Website__c = counter++;
        }
        
        if (!mediaList.isEmpty()) {
            update mediaList;
        }
    }
    
    // ✅ Upload watermark image using base64
    @AuraEnabled
    public static void uploadFileWaterMark(String fileName, String blobData, String recordId, String propMediaId) {
        try {
            // Validation
            if (String.isBlank(blobData)) {
                throw new AuraHandledException('File data is empty.');
            }
            if (String.isBlank(fileName)) {
                throw new AuraHandledException('File name is empty.');
            }
            
            // Decode base64 string to Blob
            Blob decodedBlob = EncodingUtil.base64Decode(blobData);
            
            // Upload to AWS S3
            String publicImageURL = S3ImageUploader.filePUT(recordId, fileName, decodedBlob);
            System.debug('Public image: ' + publicImageURL);
            System.debug('RecordId: ' + recordId);
            
            // Fetch Property_Media__c to update
            List<Property_Media__c> propMedia = [
                SELECT Id, Watermark_URL__c
                FROM Property_Media__c
                WHERE Id = :propMediaId
            ];
            
            for (Property_Media__c objPM : propMedia) {
                objPM.Watermark_URL__c = publicImageURL;
            }
            
            update propMedia;
            
        } catch (Exception e) {
            System.debug('Upload watermark file Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to upload watermark file: ' + e.getMessage());
        }
    }
}