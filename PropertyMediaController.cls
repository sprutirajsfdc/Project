/**
* @File Name : PropertyMediaController.cls
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

public class PropertyMediaController {
    @AuraEnabled(cacheable=true)
    public static List<PropertyMediaDTO> getPropertyMedia(Id propertyId) {

        Listing__c listing = [SELECT Watermark_Enabled__c FROM Listing__c WHERE Id = :propertyId LIMIT 1];

        List<PropertyMediaDTO> lstPropertyMediaDTO = new List<PropertyMediaDTO>();

        List<Property_Media__c> lstPM = [
                SELECT Id, Tag__c, Sort_on_Website__c, Public_URL__c, Watermark_URL__c
                FROM Property_Media__c
                WHERE Listing__c = :propertyId
            ];
        
        for(Property_Media__c objPM:lstPM){
            String ImageURL = (listing.Watermark_Enabled__c && String.isNotBlank(objPM.Watermark_URL__c)) ? objPM.Watermark_URL__c : objPM.Public_URL__c;
            lstPropertyMediaDTO.add(new PropertyMediaDTO(objPM.Id, objPM.Tag__c, objPM.Sort_on_Website__c, ImageURL, '',''));
        }

        return lstPropertyMediaDTO;
    }

    // DTO (Data Transfer Object) for LWC
    public class PropertyMediaDTO {
        @AuraEnabled public String PropMediaId;
        @AuraEnabled public String Tag;
        @AuraEnabled public Decimal Sort_On_Website;
        @AuraEnabled public String Public_URL;
        @AuraEnabled public String WaterMark_URL;
        @AuraEnabled public String versionData;

        public PropertyMediaDTO(String PropMediaId, String Tag, Decimal Sort_On_Website, String Public_URL, String WaterMark_URL, String versionData) {
            this.PropMediaId = PropMediaId;
            this.Tag = Tag;
            this.Sort_On_Website = Sort_On_Website;
            this.Public_URL = Public_URL;
            this.WaterMark_URL = WaterMark_URL;
            this.versionData = versionData;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PropertyMediaDTO> getCDLink(Id propertyId){
        try {
            // Step 1: Get all Property_Media__c for propertyId
            List<Property_Media__c> lstContentDocumentIds = [
                SELECT Id, Tag__c, Sort_on_Website__c, Public_URL__c, Watermark_URL__c, ContentDocumentId__c
                FROM Property_Media__c
                WHERE Listing__c = :propertyId
            ];

            if (lstContentDocumentIds.isEmpty()) {
                throw new AuraHandledException('No Media file found on the record.');
            }

            set<string> setContentIds = new set<string>();
            for(Property_Media__c objPM:lstContentDocumentIds){
                setContentIds.add(objPM.ContentDocumentId__c);
            }
            // Step 2: Get latest ContentVersion for all documents
            List<ContentVersion> lstVersion = [
                SELECT VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId = :setContentIds
                ORDER BY VersionNumber
            ];

            if (lstVersion.isEmpty()) {
                throw new AuraHandledException('No Media Versions found for the document.');
            }

            //List<string> lstVersionData = new List<string>();
            List<PropertyMediaDTO> lstPropertyMediaDTO = new List<PropertyMediaDTO>();
            map<string,string> mapContIdvsVersionData = new map<string,string>();

            for(ContentVersion objCV:lstVersion){
                //lstVersionData.add(EncodingUtil.base64Encode(objCV.VersionData));
                mapContIdvsVersionData.put(objCV.ContentDocumentId,EncodingUtil.base64Encode(objCV.VersionData));
            }

            for(Property_Media__c objPM:lstContentDocumentIds){
                if(mapContIdvsVersionData.containskey(objPM.ContentDocumentId__c)){
                    lstPropertyMediaDTO.add(new PropertyMediaDTO(objPM.Id, objPM.Tag__c, objPM.Sort_on_Website__c, objPM.Public_URL__c, objPM.Watermark_URL__c,mapContIdvsVersionData.get(objPM.ContentDocumentId__c)));
                }
            }

            // Step 3: Return data
            return lstPropertyMediaDTO;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}