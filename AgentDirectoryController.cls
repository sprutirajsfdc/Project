public with sharing class AgentDirectoryController {

    @AuraEnabled(cacheable=true)
    public static List<User> getActiveAgents() {
        return [
            SELECT Id, Name, Title, MobilePhone, Email, IsActive, Profile.Name, AWS_Profile_Url__c 
            FROM User 
            WHERE IsActive = true 
            AND Profile.Name = 'Sales Agent' 
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAgentListingData(Id agentId) {
        Map<String, Object> result = new Map<String, Object>();

        // Agent Info
        List<User> agentData = [
            SELECT Id, Name, Title, MobilePhone, Email, AWS_Profile_Url__c 
            FROM User 
            WHERE Id = :agentId
        ];
        result.put('agent', agentData);

        // All Listings
        List<Listing__c> listings = [
            SELECT Id, Name, Auto_Generated_broker_reference_ID__c,
                   Status__c, Address__c, os_TotalArea_pb__c,
                   Bedrooms__c, Bathrooms__c,
                   OwnerId, Owner.Name,
                   os_ListingPrice_pb__c,
                   Listing_Type__c,
                   CreatedDate
            FROM Listing__c
            WHERE OwnerId = :agentId
        ];
        result.put('listings', listings);

        // Aggregations
        Decimal totalPropertyValue = 0;
        Decimal totalClosedAmount = 0;
        Integer activeListingsCount = 0;
        Integer closedDealsCount = 0;

        for (Listing__c l : listings) {
            if (l.os_ListingPrice_pb__c != null) {
                totalPropertyValue += l.os_ListingPrice_pb__c;
            }

            if (l.Status__c == 'Published') {
                activeListingsCount++;
            }

            if (l.Status__c == 'Sold') {
                closedDealsCount++;
                if (l.os_ListingPrice_pb__c != null) {
                    totalClosedAmount += l.os_ListingPrice_pb__c;
                }
            }
        }

        result.put('totalPropertyValue', totalPropertyValue);
        result.put('activeListingsCount', activeListingsCount);
        result.put('closedDealsCount', closedDealsCount);
        result.put('totalClosedAmount', totalClosedAmount);

        return result;
    }

	@AuraEnabled(cacheable=true)
public static List<Property_Media__c> getAllMediaForListing(Id listingId) {
    return [	
        SELECT Public_URL__c 
        FROM Property_Media__c 
        WHERE Listing__c = :listingId 
        ORDER BY Sort_on_Website__c ASC Limit 1
    ];
}

}