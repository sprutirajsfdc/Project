/**
* @File Name : PropertyMediatable.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : August 1, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | August 1, 2025 |   | Initial Version
**/

public class PropertyMediatable {
    
    @AuraEnabled(cacheable=true)
    public static List<Property_Media__c> getMediaRecords(Id listingId) {
        return [
            SELECT Id, Name, Tag__c, os_ExternalLink__c, 
            os_IsOnExpose__c, os_IsOnPortalFeed__c, os_IsOnWebsite__c,
            Public_URL__c
            FROM Property_Media__c 
            WHERE Listing__c = :listingId 
            ORDER BY Sort_on_Website__c ASC NULLS LAST
        ];
    }
    
    @AuraEnabled
    public static void updateMedia(Property_Media__c updatedMedia) {
        update updatedMedia;
    }
    
    @AuraEnabled
    public static void deleteMedia(Id mediaId) {
        delete [SELECT Id FROM Property_Media__c WHERE Id = :mediaId];
    }
    
    @AuraEnabled
    public static Property_Media__c uploadAndCreateMedia(String listingId, String fileNameWithExtension, String base64Data, String tag) {
        String fileUrl;
        
        // Retrieve the listing safely
        List<Listing__c> listings = [SELECT Id, Name, Property__c FROM Listing__c WHERE Id = :listingId LIMIT 1];
        if (listings.isEmpty()) {
            throw new AuraHandledException('Listing not found for Id: ' + listingId);
        }
        Listing__c listing = listings[0];
        
        // Convert base64 string to Blob
        Blob fileBlob = EncodingUtil.base64Decode(base64Data);
        
        if (Test.isRunningTest()) {
            fileUrl = 'https://ksamedia.s3.eu-north-1.amazonaws.com/Listing_s3/' + fileNameWithExtension;
        } else {
            // Pass the Blob to S3ImageUploader instead of base64 string
            fileUrl = S3ImageUploader.filePUT(listingId, fileNameWithExtension, fileBlob);
        }
        
        // If Property__c is null, create a new Property__c record
        Id propertyId;
        if (listing.Property__c == null) {
            Property__c newProperty = new Property__c(Name = 'New Property for ' + listing.Name);
            insert newProperty;
            propertyId = newProperty.Id;
            
            listing.Property__c = propertyId;
            update listing;
        } else {
            propertyId = listing.Property__c;
        }
        
        Property_Media__c media = new Property_Media__c(
            Name = fileNameWithExtension,
            Listing__c = listingId,
            Property__c = propertyId,
            Public_URL__c = fileUrl,
            Tag__c = tag
        );
        insert media;
        
        return media;
    }
    
    
}