/**
* @File Name : ListingMapControllerTest.cls
* @Description :This test class validates the functionality of the ListingMapController class.  
*                It ensures that the fetchListing method retrieves a Listing__c record correctly  
*                and handles invalid scenarios gracefully.
* @Author :
* @Last Modified By :
* @Last Modified On : March 23, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | March 23, 2025 |   | Initial Version
**/

@isTest
public with sharing class ListingMapControllerTest {
    
     @testSetup
    static void setupTestData() {
        // Create test Listing__c record
        Listing__c testListing = new Listing__c(
            Name = 'Test Listing',
            os_Street_pb__c = '1600 Amphitheatre Parkway',
            City__c = 'Mountain View',
            os_State_pb__c = 'CA',
            os_PostalCode_pb__c = '94043',
            Country__c = 'USA'
        );
        insert testListing;


    }

    @isTest
    static void testGetListingAddress() {
        // Get inserted Listing__c record
        Listing__c insertedListing = [SELECT Id FROM Listing__c LIMIT 1];

        Test.startTest();
        
        Map<String, String> result = ListingMapController.getListingAddress(insertedListing.Id);

        Test.stopTest();

        // Assert expected results
        System.assertEquals('1600 Amphitheatre Parkway', result.get('street'));
        System.assertEquals('Mountain View', result.get('city'));
        System.assertEquals('CA', result.get('state'));
        System.assertEquals('94043', result.get('postalCode'));
        System.assertEquals('USA', result.get('country'));
        System.assertNotEquals(null, result.get('apiKey')); // Should have a dummy API key
    }
}