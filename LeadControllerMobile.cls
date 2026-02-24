public with sharing class LeadControllerMobile {

    public class UAEFilter {
        @AuraEnabled public String nameOrRef {get; set;}
        @AuraEnabled public List<String> communities {get; set;}
        @AuraEnabled public List<String> subCommunities {get; set;}
        @AuraEnabled public String inquiryType {get; set;}
        @AuraEnabled public String status {get; set;}
        @AuraEnabled public String subStatus {get; set;}
        @AuraEnabled public String propertyType {get; set;}
        @AuraEnabled public Decimal priceMin {get; set;}
        @AuraEnabled public Decimal priceMax {get; set;}
        @AuraEnabled public Decimal bedMin {get; set;}
        @AuraEnabled public Decimal bedMax {get; set;}
        @AuraEnabled public String createdStart {get; set;}
        @AuraEnabled public String createdEnd {get; set;}
        @AuraEnabled public Boolean applyBaseline {get; set;}
    }

    public class PageCursor {
        @AuraEnabled public Datetime lastCreatedDate { get; set; }
        @AuraEnabled public Id lastId { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Boolean forward { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
    }

    public class PageResult {
        @AuraEnabled public List<Inquiry__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Datetime nextCreatedDate { get; set; }
        @AuraEnabled public Id nextId { get; set; }
        @AuraEnabled public Boolean hasMore { get; set; }
    }

    public class ComboOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public ComboOption(String l, String v) { label = l; value = v; }
    }

    public class Facets {
        @AuraEnabled public List<ComboOption> communities { get; set; }
        @AuraEnabled public List<ComboOption> subCommunities { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static PageResult getPropertiesUAEKeyset(UAEFilter f, PageCursor c) {
        System.debug(f.communities);
        Integer ps = (c == null || c.pageSize == null || c.pageSize < 1 || c.pageSize > 200) ? 25 : c.pageSize;
        Integer pageNum = (c == null || c.pageNumber == null) ? 1 : c.pageNumber;

        List<String> wc = new List<String>();
        wc.add('Inquiry_Type__c IN (\'Buyer\', \'Tenant\')');
        wc.add('Do_Not_Call__c != true');
        wc.add('Owner.Name NOT IN (\'Dead Leads UAE\', \'Dead Leads KSA\', \'Dead Leads UK\')');

        // Always hide this specific combination
        //Not show Records where Status__c = 'New Lead' AND Sub_Status__c = 'Not Yet Contacted' — under ANY condition.
        wc.add('(Status__c != \'New Lead\' OR Sub_Status__c != \'Not Yet Contacted\')');
        

        // Boolean applyBaseline = (f == null || f.applyBaseline == null) ? false : f.applyBaseline;
        // if (applyBaseline) {
        //     wc.add('((Status__c = \'Engaged\' AND LastActivityLoggedOn__c < LAST_N_DAYS:7) ' +
        //            'OR (Status__c IN (\'Viewing\', \'Offering\', \'New Lead\') AND LastActivityLoggedOn__c < LAST_N_DAYS:7) ' +
        //            'OR (Status__c = \'Lost\'))');
        // }

        Date dStart = parseDateSafe(f != null ? f.createdStart : null);
        Date dEnd = parseDateSafe(f != null ? f.createdEnd : null);
        Datetime startDT = (dStart == null) ? null : DateTime.newInstance(dStart, Time.newInstance(0,0,0,0));
        Datetime endDT = (dEnd == null) ? null : DateTime.newInstance(dEnd, Time.newInstance(23,59,59,999));

        if (f != null) {
            if (!String.isBlank(f.nameOrRef)) {
                String escaped = String.escapeSingleQuotes(f.nameOrRef.trim());
                String q = '%' + escaped + '%';
                wc.add('Name LIKE \'' + q + '\'');
            }
            if (f.communities != null && !f.communities.isEmpty()) {
                List<String> escapedComms = new List<String>();
                for (String comm : f.communities) {
                    escapedComms.add(String.escapeSingleQuotes(comm));
                }
                String communitiesClause = '(\'' + String.join(escapedComms, '\',\'') + '\')';
                wc.add('Community_Propertyfinder__c IN ' + communitiesClause);
            }

            if (f.subCommunities != null && !f.subCommunities.isEmpty()) {
                List<String> escapedSubs = new List<String>();
                for (String sub : f.subCommunities) {
                    escapedSubs.add(String.escapeSingleQuotes(sub));
                }
                String subCommunitiesClause = '(\'' + String.join(escapedSubs, '\',\'') + '\')';
                wc.add('Sub_Community_Propertyfinder__c IN ' + subCommunitiesClause);
            }
            if (!String.isBlank(f.inquiryType)) {
                String escaped = String.escapeSingleQuotes(f.inquiryType);
                wc.add('Inquiry_Type__c = \'' + escaped + '\'');
            }
            if (!String.isBlank(f.status)) {
                String escaped = String.escapeSingleQuotes(f.status);
                wc.add('Status__c = \'' + escaped + '\'');
            }
            if (!String.isBlank(f.subStatus)) {
                String escaped = String.escapeSingleQuotes(f.subStatus);
                wc.add('Sub_Status__c = \'' + escaped + '\'');
            }
            if (!String.isBlank(f.propertyType)) {
                String escaped = String.escapeSingleQuotes(f.propertyType);
                wc.add('Property_Type__c = \'' + escaped + '\'');
            }
            if (f.priceMin != null) {
                wc.add('Price_min__c >= ' + f.priceMin);
            }
            if (f.priceMax != null) {
                wc.add('Price_max__c <= ' + f.priceMax);
            }
            if (f.bedMin != null) {
                wc.add('Bedrooms_min__c >= ' + f.bedMin);
            }
            if (f.bedMax != null) {
                wc.add('Bedrooms_max__c <= ' + f.bedMax);
            }
            if (startDT != null) {
                String startStr = startDT.format('yyyy-MM-dd\'T\'HH:mm:ss\'.\'SSS\'Z\'');
                wc.add('CreatedDate >= ' + startStr);
            }
            if (endDT != null) {
                String endStr = endDT.format('yyyy-MM-dd\'T\'HH:mm:ss\'.\'SSS\'Z\'');
                wc.add('CreatedDate <= ' + endStr);
            }
        }

        // 🧭 Keyset pagination
        Datetime cursorDate;
        Id cursorId;

        if (c != null) {
            System.debug('c : ' + c);
            cursorDate = c.lastCreatedDate;
            cursorId = c.lastId;

            if (cursorDate != null && cursorId != null) {
                System.debug('cursorId : ' + cursorId);
                if (c.forward == true) {
                    System.debug('c.forward : ' + c.forward);
                    // 👉 NEXT page → move to older records (FIXED: < not <= to avoid overlap)
                    wc.add('(CreatedDate < :cursorDate OR (CreatedDate = :cursorDate AND Id < :cursorId))');
                } else {
                    System.debug('c.forward : ' + c.forward);
                    // 👉 PREVIOUS page → move to newer records
                    wc.add('(CreatedDate > :cursorDate OR (CreatedDate = :cursorDate AND Id > :cursorId))');
                }
            } else {
                System.debug('⚠️ Pagination NOT applied — cursorDate or lastId missing');
            }
        }
        System.debug('WC : ' + wc);

        String whereSoql = wc.isEmpty() ? '' : (' WHERE ' + String.join(wc, ' AND '));
        String orderClause = (c != null && c.forward == false)
            ? ' ORDER BY CreatedDate ASC, Id ASC'
            : ' ORDER BY CreatedDate DESC, Id DESC';

       Integer totalCount = 0;

// Determine TRUE first page (not fake cursor page 1)
Boolean isRealFirstPage =
    (c == null || c.lastCreatedDate == null || c.lastId == null);

if (isRealFirstPage) {
    String countQuery = 'SELECT COUNT() FROM Inquiry__c' + whereSoql;
    totalCount = Database.countQuery(countQuery);
    System.debug('🧮 Total matching records: ' + totalCount);
}


        // String soqlQuery =
        //     'SELECT Id, Name, Inquiry_Type__c, Property_Type__c, Status__c, Sub_Status__c,' +
        //     ' Community_Propertyfinder__c, Sub_Community_Propertyfinder__c,' +
        //     ' Bedrooms_min__c, Bedrooms_max__c, Price_min__c, Price_max__c,' +
        //     ' CreatedDate, LastActivityLoggedOn__c, Sharing_Rule__c, Owner.Name ' +
        //     'FROM Inquiry__c' + whereSoql + orderClause + ' LIMIT ' + ps;

       String soqlQuery =
    'SELECT Id, Name, Inquiry_Type__c, Property_Type__c, Status__c, Sub_Status__c,' +
    ' Community_Propertyfinder__c, Sub_Community_Propertyfinder__c,' +
    ' Bedrooms_min__c, Bedrooms_max__c, Price_min__c, Price_max__c,' +
    ' CreatedDate, LastActivityLoggedOn__c, Sharing_Rule__c, Owner.Name, ' +
    ' Lost_Reason__c ' + // ADD THIS FIELD
    'FROM Inquiry__c' + whereSoql + orderClause + ' LIMIT ' + ps;

        System.debug('🟨 Final SOQL Query: ' + soqlQuery);

        List<Inquiry__c> rows = Database.query(soqlQuery);

        if (!rows.isEmpty()) {
            System.debug('🆔 First record before reverse: ' + rows[0].Id +
                        ' | Last record before reverse: ' + rows[rows.size() - 1].Id);
        }

        // 🔄 Reverse when going backward
        if (c != null && c.forward == false && !rows.isEmpty()) {
            List<Inquiry__c> reversed = new List<Inquiry__c>();
            for (Integer i = rows.size() - 1; i >= 0; i--) {
                reversed.add(rows[i]);
            }
            rows = reversed;
            System.debug('↩️ Reversed list for backward pagination. Now first=' + rows[0].Id +
                        ', last=' + rows[rows.size() - 1].Id);
        }

        // 🧭 Log pagination pointers for JS reference
        if (!rows.isEmpty()) {
            System.debug('🧭 rows :' + rows );
            Datetime nextCreatedDate = rows[rows.size() - 1].CreatedDate;
            Id nextId = rows[rows.size() - 1].Id;
            Datetime prevCreatedDate = rows[0].CreatedDate;
            Id prevId = rows[0].Id;

            System.debug('📌 Pagination pointers calculated — ' +
                        'NEXT: ' + nextId + ' (' + nextCreatedDate + '), ' +
                        'PREV: ' + prevId + ' (' + prevCreatedDate + ')');
        }

        PageResult pr = new PageResult();
        pr.records = rows;
        pr.pageSize = ps;
        pr.totalRecords = totalCount;

        // pr.hasMore = (!rows.isEmpty() && (pageNum == 1 ? rows.size() < totalCount : true));

                    // CORRECTED: HasMore logic for keyset pagination
            if (rows.isEmpty()) {
                pr.hasMore = false;
            } else {
                // If returned rows < page size → no more pages
                pr.hasMore = (rows.size() == ps);
            }


        if (pr.hasMore && !rows.isEmpty()) {
            Inquiry__c tail = rows[rows.size() - 1];

            pr.nextCreatedDate = tail.CreatedDate;
            pr.nextId = tail.Id;
            System.debug('🧭 Next cursor set: CreatedDate=' + tail.CreatedDate + ', Id=' + tail.Id);
        }

        System.debug('🟪 ====== END getPropertiesUAEKeyset() ======');
        return pr;
    }

    @AuraEnabled(cacheable=true)
    public static Facets getCommunityFacets(String communitySearchInput, String subCommunityQuery) {

        try {
            // --- 1. Communities Search ---
            String commSearchKey = (communitySearchInput != null) ?
                                    '%' + communitySearchInput.trim() + '%' :
                                    '%';
            Integer recordLimit = 50;

            List<AggregateResult> commResults = [
                SELECT Community_Propertyfinder__c name, COUNT(Id) inquiriesCount
                FROM Inquiry__c
                WHERE Inquiry_Type__c IN ('Buyer', 'Tenant')
                AND Owner.Name NOT IN ('Dead Leads UAE', 'Dead Leads KSA', 'Dead Leads UK')
                AND Do_Not_Call__c != true
                AND Community_Propertyfinder__c != NULL
                AND Community_Propertyfinder__c LIKE :commSearchKey
                GROUP BY Community_Propertyfinder__c
                ORDER BY Community_Propertyfinder__c ASC, COUNT(Id) DESC
                LIMIT :recordLimit
            ];

            List<ComboOption> commOptions = new List<ComboOption>();
            for (AggregateResult ar : commResults) {
                String name = (String)ar.get('name');
                commOptions.add(new ComboOption(name, name));
            }

            // --- 2. Sub-Communities Search ---
            String subCommSearchKey = (subCommunityQuery != null) ?
                                      '%' + subCommunityQuery.trim() + '%' :
                                      '%';

            List<AggregateResult> subCommResults = [
                SELECT Sub_Community_Propertyfinder__c name, COUNT(Id) inquiriesCount
                FROM Inquiry__c
                WHERE Inquiry_Type__c IN ('Buyer', 'Tenant')
                AND Owner.Name NOT IN ('Dead Leads UAE', 'Dead Leads KSA', 'Dead Leads UK')
                AND Do_Not_Call__c != true
                AND Sub_Community_Propertyfinder__c != NULL
                AND Sub_Community_Propertyfinder__c LIKE :subCommSearchKey
                GROUP BY Sub_Community_Propertyfinder__c
                ORDER BY Sub_Community_Propertyfinder__c ASC, COUNT(Id) DESC
                LIMIT :recordLimit
            ];

            List<ComboOption> subCommOptions = new List<ComboOption>();
            for (AggregateResult ar : subCommResults) {
                String name = (String)ar.get('name');
                subCommOptions.add(new ComboOption(name, name));
            }

            // --- 3. Wrap and Return ---
            Facets fx = new Facets();
            fx.communities = commOptions;
            fx.subCommunities = subCommOptions;

            System.debug('Returned ' + fx.communities.size() + ' communities and ' + fx.subCommunities.size() + ' subcommunities efficiently.');
            return fx;

        } catch (Exception e) {
            // Log the exact error and throw a user-friendly exception
            System.debug('CRITICAL ERROR in getCommunityFacets: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            throw new AuraHandledException('An error occurred in Apex: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ComboOption> getPicklistValues(String objectApiName, String fieldApiName) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) return new List<ComboOption>();

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName)) return new List<ComboOption>();

        Schema.SObjectType sobjType = gd.get(objectApiName);
        Schema.DescribeSObjectResult sdr = sobjType.getDescribe();
        Map<String, Schema.SObjectField> fmap = sdr.fields.getMap();
        if (!fmap.containsKey(fieldApiName)) return new List<ComboOption>();

        Schema.DescribeFieldResult fld = fmap.get(fieldApiName).getDescribe();
        List<ComboOption> opts = new List<ComboOption>();

        for (Schema.PicklistEntry pe : fld.getPicklistValues()) {
            opts.add(new ComboOption(pe.getLabel(), pe.getValue()));
        }
        return opts;
    }

    private static Date parseDateSafe(String ymd) {
        if (String.isBlank(ymd)) return null;
        try {
            return Date.valueOf(ymd);
        } catch (Exception e) {
            return null;
        }
    }
}
