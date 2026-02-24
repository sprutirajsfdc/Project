/**
 * =============================================================
 * Class Name    : PortalController
 * Description   : 
 * This controller manages portal visibility and publishing
 * functionality for Listings. It dynamically determines
 * available portals based on Listing Region, fetches portal
 * publish status, publish/withdraw dates, and allows
 * publish/unpublish actions per portal.
 *
 * It also performs:
 *  - Media validation before publishing
 *  - User profile permission checks
 *
 * Author        : Sprutiraj 

 * =============================================================
 */
public with sharing class PortalController {

    /* ============================================================
       PORTAL WRAPPER
       ============================================================ */
    public class PortalsWrapper {
        @AuraEnabled public String portalId;
        @AuraEnabled public String portalName;
        @AuraEnabled public String portalStatus;
        @AuraEnabled public String portalImage;

        @AuraEnabled public Boolean isPublishedOnPortal;
        @AuraEnabled public Date publishedDate;
        @AuraEnabled public Date withdrawnDate;
    }

    /* ============================================================
       GET PORTALS BY REGION
       ============================================================ */
    @AuraEnabled(cacheable=true)
    public static List<PortalsWrapper> getPortalsByRegion(Id recordId) {

        System.debug('[PortalController] getPortalsByRegion started. ListingId = ' + recordId);

        if (recordId == null) {
            System.debug('[PortalController] ERROR: Listing ID is null');
            throw new AuraHandledException('Listing ID cannot be blank.');
        }

        /* ---- Fetch Listing Region ---- */
        Listing__c baseListing = [
            SELECT Id, Listing_Region__c
            FROM Listing__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        System.debug('[PortalController] Listing Region = ' + baseListing.Listing_Region__c);

        if (String.isBlank(baseListing.Listing_Region__c)) {
            System.debug('[PortalController] No Listing Region found. Returning empty list.');
            return new List<PortalsWrapper>();
        }

        String mappedRegion = mapListingRegion(baseListing.Listing_Region__c);
        System.debug('[PortalController] Mapped Region = ' + mappedRegion);

        if (String.isBlank(mappedRegion)) {
            System.debug('[PortalController] Region mapping failed. Returning empty list.');
            return new List<PortalsWrapper>();
        }

        /* ---- Fetch Portals for Region ---- */
        List<Portals_Custom__c> portals = [
            SELECT Id, Name, isActive__c, URL__c,
                   Publish_Field__c,
                   Publish_Date_Field__c,
                   Withdraw_Date_Field__c
            FROM Portals_Custom__c
            WHERE Allowed_for_Regions__c INCLUDES (:mappedRegion)
        ];

        System.debug('[PortalController] Portals found for region: ' + portals.size());

        if (portals.isEmpty()) {
            System.debug('[PortalController] No portals configured for this region.');
            return new List<PortalsWrapper>();
        }

        /* ---- Build Dynamic Listing Query ---- */
        Set<String> listingFields = new Set<String>{ 'Id' };

        for (Portals_Custom__c p : portals) {
            if (!String.isBlank(p.Publish_Field__c)) {
                listingFields.add(p.Publish_Field__c);
            }
            if (!String.isBlank(p.Publish_Date_Field__c)) {
                listingFields.add(p.Publish_Date_Field__c);
            }
            if (!String.isBlank(p.Withdraw_Date_Field__c)) {
                listingFields.add(p.Withdraw_Date_Field__c);
            }
        }

        System.debug('[PortalController] Dynamic Listing Fields = ' + listingFields);

        String listingQuery =
            'SELECT ' + String.join(new List<String>(listingFields), ',') +
            ' FROM Listing__c WHERE Id = :recordId LIMIT 1';

        System.debug('[PortalController] Listing Query = ' + listingQuery);

        Listing__c listing = (Listing__c) Database.query(listingQuery);

        /* ---- Build Wrapper Response ---- */
        List<PortalsWrapper> response = new List<PortalsWrapper>();

        for (Portals_Custom__c portal : portals) {

            System.debug('[PortalController] Processing portal: ' + portal.Name);

            PortalsWrapper w = new PortalsWrapper();
            w.portalId = portal.Id;
            w.portalName = portal.Name;
            w.portalImage = portal.URL__c;
            w.portalStatus = portal.isActive__c ? 'Active' : 'Inactive';

            w.isPublishedOnPortal = false;
            w.publishedDate = null;
            w.withdrawnDate = null;

            try {
                if (!String.isBlank(portal.Publish_Field__c)) {
                    w.isPublishedOnPortal =
                        (Boolean) listing.get(portal.Publish_Field__c);

                    System.debug('[PortalController] Publish Flag (' +
                        portal.Publish_Field__c + ') = ' + w.isPublishedOnPortal);
                }

                if (!String.isBlank(portal.Publish_Date_Field__c)) {
                    w.publishedDate =
                        (Date) listing.get(portal.Publish_Date_Field__c);

                    System.debug('[PortalController] Published Date (' +
                        portal.Publish_Date_Field__c + ') = ' + w.publishedDate);
                }

                if (!String.isBlank(portal.Withdraw_Date_Field__c)) {
                    w.withdrawnDate =
                        (Date) listing.get(portal.Withdraw_Date_Field__c);

                    System.debug('[PortalController] Withdrawn Date (' +
                        portal.Withdraw_Date_Field__c + ') = ' + w.withdrawnDate);
                }

            } catch (Exception ex) {
                System.debug('[PortalController] WARNING: Field read failed for portal '
                    + portal.Name + '. Error: ' + ex.getMessage());
            }

            response.add(w);
        }

        System.debug('[PortalController] getPortalsByRegion completed. Returning ' + response.size() + ' records.');
        return response;
    }

    /* ============================================================
       REGION MAPPING
       ============================================================ */
    private static String mapListingRegion(String listingRegion) {
        System.debug('[PortalController] Mapping Listing Region: ' + listingRegion);

        Map<String, String> regionMapping = new Map<String, String>{
            'Dubai Listing' => 'UAE'
        };

        return regionMapping.containsKey(listingRegion)
            ? regionMapping.get(listingRegion)
            : null;
    }

    /* ============================================================
       PUBLISH / UNPUBLISH LISTING
       ============================================================ */
    @AuraEnabled
    public static void publish_Or_Unpublish(
        Id listingId,
        String portalName,
        Boolean isPublished
    ) {
        System.debug('[PortalController] publish_Or_Unpublish started');
        System.debug('[PortalController] ListingId = ' + listingId);
        System.debug('[PortalController] Portal = ' + portalName);
        System.debug('[PortalController] Action = ' + (isPublished ? 'PUBLISH' : 'UNPUBLISH'));

        try {
            if (listingId == null || String.isBlank(portalName)) {
                throw new AuraHandledException('Listing ID and Portal Name are required.');
            }

            String normalizedPortal = portalName.trim().toLowerCase();
            System.debug('[PortalController] Normalized Portal = ' + normalizedPortal);

            Portals_Custom__c portal = [
                SELECT Publish_Field__c,
                       Publish_Date_Field__c,
                       Withdraw_Date_Field__c
                FROM Portals_Custom__c
                WHERE Normalized_Name__c = :normalizedPortal
                LIMIT 1
            ];

            System.debug('[PortalController] Portal Field Mapping Found');

            String query =
                'SELECT Id,' +
                portal.Publish_Field__c + ',' +
                portal.Publish_Date_Field__c + ',' +
                portal.Withdraw_Date_Field__c +
                ' FROM Listing__c WHERE Id = :listingId LIMIT 1';

            System.debug('[PortalController] Listing Update Query = ' + query);

            Listing__c listing = (Listing__c) Database.query(query);

            Date today = Date.today();
            System.debug('[PortalController] Update Date = ' + today);

            listing.put(portal.Publish_Field__c, isPublished);
            listing.put(portal.Publish_Date_Field__c, isPublished ? today : null);
            listing.put(portal.Withdraw_Date_Field__c, !isPublished ? today : null);

            update listing;

            System.debug('[PortalController] Listing updated successfully.');

        } catch (Exception e) {
            System.debug('[PortalController] ERROR during publish/unpublish: ' + e.getMessage());
            throw new AuraHandledException('Failed to update listing: ' + e.getMessage());
        }
    }

    /* ============================================================
       MEDIA VALIDATION
       ============================================================ */
    @AuraEnabled(cacheable=true)
    public static String fetchPropertyMedia(String listingId) {

        System.debug('[PortalController] fetchPropertyMedia called. ListingId = ' + listingId);

        if (String.isBlank(listingId)) {
            return 'Listing ID is blank';
        }

        Listing__c objListing = [
            SELECT Id, Property__c, Status__c
            FROM Listing__c
            WHERE Id = :listingId
            LIMIT 1
        ];

        System.debug('[PortalController] Listing Status = ' + objListing.Status__c);

        if (objListing.Status__c != 'Published') {
            return 'Please ensure the listing status is set to Published before proceeding.';
        }

        List<Property_Media__c> media = [
            SELECT Id
            FROM Property_Media__c
            WHERE Property__c = :objListing.Property__c
        ];

        System.debug('[PortalController] Media Count = ' + media.size());

        return media.isEmpty()
            ? 'Please upload images before proceeding to publish.'
            : 'Listing has media';
    }

    /* ============================================================
       PROFILE CHECK
       ============================================================ */
    @AuraEnabled(cacheable=true)
    public static Boolean checkUserProfile() {

        String profileName = [
            SELECT Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ].Profile.Name;

        System.debug('[PortalController] User Profile = ' + profileName);

        Boolean canPublish = !(profileName != null && profileName.toLowerCase().contains('agent'));
        System.debug('[PortalController] User Can Publish = ' + canPublish);

        return canPublish;
    }
}