/**
 * Class Name      : AgencyRegistrationController
 * Description     : Handles agency registration and file uploads
 */

public with sharing class AgencyRegistrationController {

   @AuraEnabled
public static Agency_Details__c createAgencyRecord(Map<String, Object> formData) {

    if(formData == null){
        throw new AuraHandledException('Form data is missing');
    }

    Agency_Details__c agency = new Agency_Details__c();

    for(String key : formData.keySet()){
        try {
            agency.put(key, formData.get(key));
        } catch (Exception e) {
            System.debug('Skipping invalid field: ' + key);
        }
    }

    insert agency;

    return [
        SELECT Id, Name
        FROM Agency_Details__c
        WHERE Id = :agency.Id
    ];
}

   @AuraEnabled
public static void uploadFiles(Id recordId, List<FileWrapper> files) {

    List<ContentVersion> versions = new List<ContentVersion>();

    for(FileWrapper file : files){
        ContentVersion cv = new ContentVersion();
        cv.Title = file.fileName;
        cv.PathOnClient = file.fileName;
        cv.VersionData = EncodingUtil.base64Decode(file.base64);
        versions.add(cv);
    }

    insert versions;

    // Fetch all ContentDocumentIds in ONE query
    Map<Id, Id> versionToDocMap = new Map<Id, Id>();

    for(ContentVersion cv : [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id IN :versions
    ]) {
        versionToDocMap.put(cv.Id, cv.ContentDocumentId);
    }

    List<ContentDocumentLink> links = new List<ContentDocumentLink>();

    for(ContentVersion cv : versions){
        ContentDocumentLink link = new ContentDocumentLink();
        link.LinkedEntityId = recordId;
        link.ContentDocumentId = versionToDocMap.get(cv.Id);
        link.ShareType = 'V';
        links.add(link);
    }

    insert links;
}

    public class FileWrapper{

        @AuraEnabled public String fileName;
        @AuraEnabled public String base64;

    }

}