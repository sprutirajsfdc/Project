public with sharing class ListingMapController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getListingAddress(Id listingId) {
        Listing__c listing = [
            SELECT City__c, Country__c, os_State_pb__c, os_PostalCode_pb__c, os_Street_pb__c,
                   os_Latitude_pb__c, os_Longitude_pb__c
            FROM Listing__c
            WHERE Id = :listingId
            LIMIT 1
        ];

        // Fetch API Key from Custom Metadata
        GoogleMapsConfig__mdt apiKeyMetadata = [
            SELECT API_Key__c FROM GoogleMapsConfig__mdt WHERE DeveloperName = 'GoogleMaps' LIMIT 1
        ];

        Map<String, String> result = new Map<String, String>();
        result.put('street', listing.os_Street_pb__c);
        result.put('city', listing.City__c);
        result.put('state', listing.os_State_pb__c);
        result.put('postalCode', listing.os_PostalCode_pb__c);
        result.put('country', listing.Country__c);
        result.put('apiKey', apiKeyMetadata.API_Key__c);

        // Only include lat/lng if not null
        if (listing.os_Latitude_pb__c != null) {
            result.put('latitude', String.valueOf(listing.os_Latitude_pb__c));
        }
        if (listing.os_Longitude_pb__c != null) {
            result.put('longitude', String.valueOf(listing.os_Longitude_pb__c));
        }

        return result;
    }
}