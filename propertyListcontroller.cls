/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : propertyListcontroller
 * Author          : <YourName>
 * Created Date    : Feb 23, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Feb 23, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 23, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class propertyListcontroller {

	  @AuraEnabled(Cacheable = true)
    public static List<Listing__c> getAccountWithFilters(Integer limitRecords, Map<String, String> filters) {
        try {
            Set<String> selectedFields = new Set<String>();
            selectedFields.add('Id');
            selectedFields.add('OwnerId');
            selectedFields.add('Owner.Name');
            selectedFields.add('Community__c');
            selectedFields.add('Community__r.Name');
            selectedFields.add('Status__c');
            selectedFields.add('Sub_Community__c');
            selectedFields.add('Sub_Community__r.Name');
            selectedFields.add('Feature_Media__c');

            // Include all fields from Field Set: Listing_Set
            for (Schema.FieldSetMember fieldSet : SObjectType.Listing__c.FieldSets.Listing_Set.getFields()) {
                selectedFields.add(fieldSet.getFieldPath());
            }

            // Start SOQL query
            String queryString = 'SELECT ' + String.join(new List<String>(selectedFields), ', ') + ' FROM Listing__c';

            // Add WHERE conditions based on filter values
            List<String> filterConditions = new List<String>();
            for (String fieldName : filters.keySet()) {
                String fieldValue = filters.get(fieldName);
                if (String.isNotBlank(fieldValue)) {
                    Schema.DescribeFieldResult fieldResult = Listing__c.SObjectType.getDescribe().fields.getMap().get(fieldName).getDescribe();
                    Schema.DisplayType fieldType = fieldResult.getType();

                    // Lookup or picklist: Use '='
                    if (fieldType == Schema.DisplayType.Reference || fieldType == Schema.DisplayType.Picklist) {
                    if (fieldValue.contains(',')) {
                        List<String> values = fieldValue.split(',');
                        List<String> quotedValues = new List<String>();
                        for (String val : values) {
                            quotedValues.add('\'' + String.escapeSingleQuotes(val.trim()) + '\'');
                        }
                        filterConditions.add(fieldName + ' IN (' + String.join(quotedValues, ',') + ')');
                    } else {
                        filterConditions.add(fieldName + ' = \'' + String.escapeSingleQuotes(fieldValue) + '\'');
                    }
                }
                }
            }

            // Append WHERE clause if any filters exist
            if (!filterConditions.isEmpty()) {
                queryString += ' WHERE ' + String.join(filterConditions, ' AND ');
            }

            // Add LIMIT clause if specified
            if (limitRecords != null && limitRecords > 0) {
                queryString += ' LIMIT ' + limitRecords;
            }

            System.debug('⚡ Generated SOQL: ' + queryString);
            return Database.query(queryString);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching data: ' + e.getMessage());
        }
    }


    // Get metadata (label, apiName, type, picklist values) for filters from FieldSet: Filter_Listing
    @AuraEnabled(Cacheable = true)
    public static String getFilterFieldLabelAndAPI() {
        List<Map<String, Object>> listOfFieldSet = new List<Map<String, Object>>();
        try {
            for (Schema.FieldSetMember fieldset : SObjectType.Listing__c.FieldSets.Filter_Listing.getFields()) {
                Map<String, Object> fieldMap = new Map<String, Object>();
                String fieldName = fieldset.getFieldPath();
                Schema.DescribeFieldResult fieldResult = Listing__c.SObjectType.getDescribe().fields.getMap().get(fieldName).getDescribe();
                String fieldType = fieldResult.getType().name();

                fieldMap.put('label', fieldset.getLabel());
                fieldMap.put('apiName', fieldName);
                fieldMap.put('type', fieldType);

                // Add picklist options if it's a picklist
                if (fieldResult.getType() == Schema.DisplayType.Picklist) {
                    List<String> picklistValues = new List<String>();
                    for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                        picklistValues.add(entry.getValue());
                    }
                    fieldMap.put('picklistValues', picklistValues);
                }

                listOfFieldSet.add(fieldMap);
            }
        } catch (Exception e) {
            System.debug('❌ Error in getFilterFieldLabelAndAPI: ' + e.getMessage());
            throw new AuraHandledException('Error fetching filter field labels: ' + e.getMessage());
        }
        return JSON.serialize(listOfFieldSet);
    }

    // Get metadata for datatable columns from FieldSet: Listing_Set
    @AuraEnabled(Cacheable = true)
    public static String getTableFieldLabelAndAPI() {
        List<Map<String, String>> listOfFieldSet = new List<Map<String, String>>();
        try {
            for (Schema.FieldSetMember fieldset : SObjectType.Listing__c.FieldSets.Listing_Set.getFields()) {
                Map<String, String> labelAPIMap = new Map<String, String>();
                labelAPIMap.put('label', fieldset.getLabel());
                labelAPIMap.put('apiName', fieldset.getFieldPath());
                listOfFieldSet.add(labelAPIMap);
            }
        } catch (Exception e) {
            System.debug('❌ Error in getTableFieldLabelAndAPI: ' + e.getMessage());
            throw new AuraHandledException('Error fetching table field labels: ' + e.getMessage());
        }
        return JSON.serialize(listOfFieldSet);
    }
    @AuraEnabled(cacheable=true)
    public static List<Community__c> getCommunityOptions() {
        return [SELECT Id, Name FROM Community__c where Type__c='Community' ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<Community__c> getSubCommunityOptions() {
        return [SELECT Id, Name,Type__c FROM Community__c where Type__c='Sub Community' ORDER BY Name];
    }

    @AuraEnabled(Cacheable = true)
    public static List<Listing__c> getFilteredData(Integer limitRecords,String listingType, String propertyType,String status, 
                                        String mandate,  String size,  String bedroom,  String address,String name,String brokerReference,
                                        List<String> community, List<String> subCommunity) {
        try {
            Set<String> selectedFields = new Set<String>();
            selectedFields.add('Id');
            selectedFields.add('OwnerId');
            selectedFields.add('Owner.Name');
            selectedFields.add('Community__c');
            selectedFields.add('Community__r.Name');
            selectedFields.add('Status__c');
            selectedFields.add('Sub_Community__c');
            selectedFields.add('Sub_Community__r.Name');
            selectedFields.add('Feature_Media__c');

            // Include all fields from Field Set: Listing_Set
            for (Schema.FieldSetMember fieldSet : SObjectType.Listing__c.FieldSets.Listing_Set.getFields()) {
                selectedFields.add(fieldSet.getFieldPath());
            }

            // Start SOQL query
            String queryString = 'SELECT ' + String.join(new List<String>(selectedFields), ', ') + ' FROM Listing__c';

            // Dynamic filter conditions
            List<String> filterConditions = new List<String>();

            if (!String.isBlank(brokerReference)) {
                filterConditions.add('Auto_Generated_broker_reference_ID__c  LIKE \'%' + String.escapeSingleQuotes(brokerReference) + '%\'');
            }
            if (!String.isBlank(propertyType)) {
                filterConditions.add('Property_Type__c = \'' + String.escapeSingleQuotes(propertyType) + '\'');
            }
            if (!String.isBlank(status)) {
                filterConditions.add('Status__c = \'' + String.escapeSingleQuotes(status) + '\'');
            }
            if (!String.isBlank(mandate)) {
                filterConditions.add('Listing_Type__c = \'' + String.escapeSingleQuotes(mandate) + '\'');
            }
            if (!String.isBlank(size)) {
                filterConditions.add('os_TotalArea_pb__c  >= ' + size);
            }
            if (!String.isBlank(bedroom)) {
                filterConditions.add('Bedrooms__c = ' + bedroom);
            }
            if (!String.isBlank(address)) {
                filterConditions.add('(address__c = ' + address);
            }
            if (!String.isBlank(listingType)) {
                filterConditions.add('Listing_Type__c = \'' + String.escapeSingleQuotes(listingType) + '\'');
            }
            if (!community.isEmpty()) {
                filterConditions.add('Community__c IN :community');
            }
            if (!subCommunity.isEmpty()) {
                filterConditions.add('Sub_Community__c IN :subCommunity');
            }

            // Append WHERE clause if any filters exist
            if (!filterConditions.isEmpty()) {
                queryString += ' WHERE ' + String.join(filterConditions, ' AND ');
            }

            // Add LIMIT clause if specified
            if (limitRecords != null && limitRecords > 0) {
                queryString += ' LIMIT ' + limitRecords;
            }

            System.debug('⚡ Generated SOQL: ' + queryString);
            return Database.query(queryString);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching data: ' + e.getMessage());
        }
    }
@AuraEnabled(cacheable=true)
public static Map<Id, String> getThumbnailsForListings(List<Id> listingIds) {
    Map<Id, String> thumbnailMap = new Map<Id, String>();
    // We fetch the first media record for each listing to use as a thumbnail
    for (Property_Media__c media : [
        SELECT Listing__c, Public_URL__c 
        FROM Property_Media__c 
        WHERE Listing__c IN :listingIds 
        ORDER BY Sort_on_Website__c ASC
    ]) {
        if (!thumbnailMap.containsKey(media.Listing__c)) {
            thumbnailMap.put(media.Listing__c, media.Public_URL__c);
        }
    }
    return thumbnailMap;
}
@AuraEnabled(cacheable=true)
public static List<Property_Media__c> getAllMediaForListing(Id listingId) {
    return [	
        SELECT Public_URL__c 
        FROM Property_Media__c 
        WHERE Listing__c = :listingId 
        ORDER BY Sort_on_Website__c ASC
    ];
}
@AuraEnabled(cacheable=true)
    public static Map<Id, String> getOwnerProfileUrls(List<Id> ownerIds) {
        Map<Id, String> result = new Map<Id, String>();

        if (ownerIds == null || ownerIds.isEmpty()) {
            return result;
        }

        // Query only users
        for (User u : [
            SELECT Id, AWS_Profile_Url__c
            FROM User
            WHERE Id IN :ownerIds
        ]) {
            result.put(u.Id, u.AWS_Profile_Url__c);
        }

        return result;
    }
}
