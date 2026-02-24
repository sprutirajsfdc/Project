public with sharing class ListingFilterMobileCtrl {
    /* ===================== Config (edit if your API names differ) ===================== */
    private static final String COMMUNITY_API   = 'Community_Propertyfinder__c';
    private static final String SUBCOMM_API     = 'Sub_Community_Propertyfinder__c';

    /* ===================== DTOs ===================== */
    public class PickOpt {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
    public class UiField {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String dataType;
        @AuraEnabled public String relationshipName;
        @AuraEnabled public String readPath;
        @AuraEnabled public List<PickOpt> picklistOptions;
    }
    public class QueryResult {
        @AuraEnabled public List<Listing__c> rows;
        @AuraEnabled public Integer total;
        @AuraEnabled public Map<String, String> media;                // latest image per listing
        @AuraEnabled public Map<String, List<String>> mediaList;      // all image URLs per listing
    }

    /* carry the client filter spec so buildClause can see 'mode' (e.g., IN) */
    public static Map<String, Map<String, String>> requestSpec;

    /* ===================== Field Set Describe ===================== */

    @AuraEnabled(cacheable=true)
    public static List<UiField> getFieldSetFields() {
        Schema.DescribeSObjectResult sdr = Listing__c.SObjectType.getDescribe();
        Schema.FieldSet fs = sdr.fieldSets.getMap().get('Filter_Listing');
        if (fs == null) {
            throw new AuraHandledException('Field Set "Filter_Listing" not found on Listing__c.');
        }
        Map<String, Schema.SObjectField> fmap = sdr.fields.getMap();
        List<UiField> outList = new List<UiField>();
        for (Schema.FieldSetMember m : fs.getFields()) {
            String api = m.getFieldPath();
            if (!fmap.containsKey(api)) continue;
            Schema.DescribeFieldResult fdr = fmap.get(api).getDescribe();

            UiField ui = new UiField();
            ui.apiName  = api;
            ui.label    = m.getLabel();
            ui.dataType = String.valueOf(fdr.getType());
            ui.relationshipName = fdr.getRelationshipName();
            ui.readPath = (fdr.getType() == Schema.DisplayType.Reference && !String.isBlank(ui.relationshipName))
                ? ui.relationshipName + '.Name'
                : ui.apiName;

            if (fdr.getType() == Schema.DisplayType.Picklist || fdr.getType() == Schema.DisplayType.MultiPicklist) {
                ui.picklistOptions = new List<PickOpt>();
                for (Schema.PicklistEntry pe : fdr.getPicklistValues()) {
                    if (!pe.isActive()) continue;
                    PickOpt po = new PickOpt();
                    po.label = pe.getLabel();
                    po.value = pe.getValue();
                    ui.picklistOptions.add(po);
                }
            }
            outList.add(ui);
        }
        return outList;
    }

    @AuraEnabled(cacheable=true)
    public static List<UiField> getListingSetFields() {
        Schema.DescribeSObjectResult sdr = Listing__c.SObjectType.getDescribe();
        Schema.FieldSet fs = sdr.fieldSets.getMap().get('Listing_Set');
        if (fs == null) {
            throw new AuraHandledException('Field Set "Listing_Set" not found on Listing__c.');
        }
        Map<String, Schema.SObjectField> fmap = sdr.fields.getMap();
        List<UiField> outList = new List<UiField>();
        for (Schema.FieldSetMember m : fs.getFields()) {
            String api = m.getFieldPath();
            if (!fmap.containsKey(api)) continue;
            Schema.DescribeFieldResult fdr = fmap.get(api).getDescribe();

            UiField ui = new UiField();
            ui.apiName  = api;
            ui.label    = m.getLabel();
            ui.dataType = String.valueOf(fdr.getType());
            ui.relationshipName = fdr.getRelationshipName();
            ui.readPath = (fdr.getType() == Schema.DisplayType.Reference && !String.isBlank(ui.relationshipName))
                ? ui.relationshipName + '.Name'
                : ui.apiName;

            outList.add(ui);
        }
        return outList;
    }

    /* ===================== Listings Query ===================== */

    @AuraEnabled(cacheable=true)
    public static QueryResult getListings(Map<String, Map<String, String>> filters, Integer pageSize, Integer offsetRows) {
        if (pageSize == null || pageSize <= 0) pageSize = 20;
        if (offsetRows == null || offsetRows < 0) offsetRows = 0;

        requestSpec = filters;

        Schema.DescribeSObjectResult sdr = Listing__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fmap = sdr.fields.getMap();

        List<String> whereParts = new List<String>();
        if (filters != null && !filters.isEmpty()) {
            for (String api : filters.keySet()) {
                if (String.isBlank(api) || !fmap.containsKey(api)) continue;
                Map<String, String> spec = filters.get(api);
                if (spec == null) continue;
                String raw = spec.containsKey('value') ? String.valueOf(spec.get('value')) : null;
                if (String.isBlank(raw)) continue;
                Schema.DescribeFieldResult fdr = fmap.get(api).getDescribe();
                String clause = buildClause(api, fdr, raw);
                if (!String.isBlank(clause)) whereParts.add(clause);
            }
        }

        List<UiField> displayFields = getListingSetFields();
        Set<String> selectSet = new Set<String>{ 'Id', 'Name' };
        for (UiField df : displayFields) {
            if (!String.isBlank(df.readPath)) selectSet.add(df.readPath);
        }
        String selectSql = 'SELECT ' + String.join(new List<String>(selectSet), ', ') + ' FROM Listing__c';
        String whereSql  = whereParts.isEmpty() ? '' : (' WHERE ' + String.join(whereParts, ' AND '));
        String orderBy   = ' ORDER BY LastModifiedDate DESC NULLS LAST';
        String limOff    = ' LIMIT ' + pageSize + ' OFFSET ' + offsetRows;

        String soql = selectSql + whereSql + orderBy + limOff;
        List<Listing__c> rows = Database.query(soql);

        String countSoql = 'SELECT COUNT() FROM Listing__c' + whereSql;
        Integer total = Database.countQuery(countSoql);

        // Media: single latest per listing + all URLs per listing (for scroller)
        Map<String,String> latestMedia = new Map<String,String>();
        Map<String, List<String>> allMedia = new Map<String, List<String>>();
        if (!rows.isEmpty()) {
            Set<Id> ids = new Set<Id>();
            for (Listing__c r : rows) ids.add(r.Id);

            // Get all public images per listing, newest first
            for (Property_Media__c pm : [
                SELECT Listing__c, Public_URL__c, CreatedDate
                FROM Property_Media__c
                WHERE Listing__c IN :ids AND Public_URL__c != null
                ORDER BY Listing__c, CreatedDate DESC
            ]) {
                String lid = (String) pm.Listing__c;
                if (!allMedia.containsKey(lid)) {
                    allMedia.put(lid, new List<String>());
                }
                if (pm.Public_URL__c != null) {
                    allMedia.get(lid).add(pm.Public_URL__c);
                    if (!latestMedia.containsKey(lid)) {
                        latestMedia.put(lid, pm.Public_URL__c); // first one is latest due to DESC
                    }
                }
            }
        }

        QueryResult out = new QueryResult();
        out.rows = rows;
        out.total = total;
        out.media = latestMedia;
        out.mediaList = allMedia;

        requestSpec = null;
        return out;
    }

    /* ===================== Header / Lookups ===================== */

    @AuraEnabled(cacheable=true)
    public static List<String> getHeaderMediaUrls(Integer limitSize) {
        if (limitSize == null || limitSize <= 0) limitSize = 100;
        List<String> out = new List<String>();
        for (Property_Media__c pm : [
            SELECT Public_URL__c
            FROM Property_Media__c
            WHERE Public_URL__c != null
            ORDER BY CreatedDate DESC
            LIMIT :limitSize
        ]) {
            out.add(pm.Public_URL__c);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<PickOpt> lookupOptions(String fieldApi, String searchTerm, Integer limitSize) {
        if (String.isBlank(fieldApi)) return new List<PickOpt>();
        if (limitSize == null || limitSize <= 0) limitSize = 25;

        Schema.DescribeSObjectResult sdr = Listing__c.SObjectType.getDescribe();
        Schema.SObjectField sof = sdr.fields.getMap().get(fieldApi);
        if (sof == null) return new List<PickOpt>();
        Schema.DescribeFieldResult fdr = sof.getDescribe();
        if (fdr.getType() != Schema.DisplayType.Reference) return new List<PickOpt>();

        String searchStr = '%' + (searchTerm == null ? '' : searchTerm.trim()) + '%';
        List<PickOpt> out = new List<PickOpt>();

        if (fieldApi == 'OwnerId') {
            for (User u : [
                SELECT Id, Name FROM User
                WHERE IsActive = true AND Name LIKE :searchStr
                ORDER BY Name
                LIMIT :limitSize
            ]) {
                PickOpt po = new PickOpt(); po.label = u.Name; po.value = u.Id; out.add(po);
            }
            for (Group g : [
                SELECT Id, Name FROM Group
                WHERE Type = 'Queue' AND Name LIKE :searchStr
                ORDER BY Name
                LIMIT :limitSize
            ]) {
                PickOpt po = new PickOpt(); po.label = g.Name + ' (Queue)'; po.value = g.Id; out.add(po);
            }
            return out;
        }

        List<Schema.SObjectType> rts = fdr.getReferenceTo();
        if (!rts.isEmpty()) {
            String target = String.valueOf(rts[0]);
            String soql = 'SELECT Id, Name FROM ' + target +
                          ' WHERE Name LIKE :searchStr ORDER BY Name LIMIT ' + limitSize;
            for (SObject rec : Database.query(soql)) {
                PickOpt po = new PickOpt();
                po.label = (String)rec.get('Name');
                po.value = (String)rec.get('Id');
                out.add(po);
            }
        }
        return out;
    }

    /* ===================== Distinct values (Text/Picklist/Reference) ===================== */

    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctFieldValues(String fieldApi, String searchTerm, Integer limitSize) {
        if (String.isBlank(fieldApi)) return new List<String>();
        if (limitSize == null || limitSize <= 0) limitSize = 500;

        Schema.DescribeSObjectResult sdr = Listing__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fmap = sdr.fields.getMap();
        if (!fmap.containsKey(fieldApi)) return new List<String>();

        Schema.DescribeFieldResult fdr = fmap.get(fieldApi).getDescribe();
        String valuePath = resolveValuePathForDistinct(fieldApi, fdr); // e.g., Community__r.Name
        if (String.isBlank(valuePath)) return new List<String>();

        String labelPath = valuePath; // use same path for LIKE
        String pattern = '%' + (searchTerm == null ? '' : searchTerm.trim())
            .replace('%','\\%').replace('_','\\_') + '%';

        String soql =
            'SELECT ' + valuePath + ' v, COUNT(Id) c ' +
            'FROM Listing__c ' +
            'WHERE ' + fieldApi + ' != null ' +
            (String.isBlank(searchTerm) ? '' : 'AND ' + labelPath + ' LIKE :pattern ESCAPE \'\\\\\' ') +
            'GROUP BY ' + valuePath + ' ' +
            'ORDER BY c DESC, v ' +
            'LIMIT ' + limitSize;

        List<String> out = new List<String>();
        for (SObject r : Database.query(soql)) {
            String v = (String) r.get('v');
            if (!String.isBlank(v)) out.add(v.trim());
        }
        return out;
    }

    /* Sub Communities scoped by selected Communities (works for Text or Reference Community) */
    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctSubCommunitiesForCommunities(List<String> communities, String searchTerm, Integer limitSize) {
        if (limitSize == null || limitSize <= 0) limitSize = 500;

        Schema.DescribeSObjectResult sdr = Listing__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fmap = sdr.fields.getMap();

        if (!fmap.containsKey(SUBCOMM_API)) return new List<String>();

        Schema.DescribeFieldResult subFdr = fmap.get(SUBCOMM_API).getDescribe();
        Schema.DescribeFieldResult comFdr = fmap.containsKey(COMMUNITY_API) ? fmap.get(COMMUNITY_API).getDescribe() : null;

        String subValuePath = resolveValuePathForDistinct(SUBCOMM_API, subFdr);
        if (String.isBlank(subValuePath)) return new List<String>();

        String communityFilterPath;
        if (comFdr != null && comFdr.getType() == Schema.DisplayType.Reference) {
            String rel = relationshipNameOrGuess(COMMUNITY_API, comFdr);
            communityFilterPath = rel + '.Name';
        } else {
            communityFilterPath = COMMUNITY_API;
        }

        String whereClause = 'WHERE ' + SUBCOMM_API + ' != null ';
        if (communities != null && !communities.isEmpty()) {
            whereClause += 'AND ' + communityFilterPath + ' IN :communities ';
        }

        String pattern = '%' + (searchTerm == null ? '' : searchTerm.trim())
            .replace('%','\\%').replace('_','\\_') + '%';
        if (!String.isBlank(searchTerm)) {
            whereClause += 'AND ' + subValuePath + ' LIKE :pattern ESCAPE \'\\\\\' ';
        }

        String soql =
            'SELECT ' + subValuePath + ' v, COUNT(Id) c ' +
            'FROM Listing__c ' +
            whereClause +
            'GROUP BY ' + subValuePath + ' ' +
            'ORDER BY c DESC, v ' +
            'LIMIT ' + limitSize;

        List<String> out = new List<String>();
        for (SObject r : Database.query(soql)) {
            String v = (String) r.get('v');
            if (!String.isBlank(v)) out.add(v.trim());
        }
        return out;
    }

    /* ===================== Helpers ===================== */

    // Resolve a safe GROUP BY path:
    // - Reference -> relationshipName.Name (or guessed __r / Id-stripped)
    // - Text/Picklist/TextArea/EncryptedString -> the field itself
    private static String resolveValuePathForDistinct(String fieldApi, Schema.DescribeFieldResult fdr) {
        Schema.DisplayType t = fdr.getType();
        if (t == Schema.DisplayType.Reference) {
            String rel = relationshipNameOrGuess(fieldApi, fdr);
            return String.isBlank(rel) ? null : (rel + '.Name');
        }
        Set<Schema.DisplayType> ok = new Set<Schema.DisplayType>{
            Schema.DisplayType.String, Schema.DisplayType.TextArea,
            Schema.DisplayType.Picklist, Schema.DisplayType.EncryptedString
        };
        return ok.contains(t) ? fieldApi : null;
    }

    private static String relationshipNameOrGuess(String fieldApi, Schema.DescribeFieldResult fdr) {
        String rel = fdr.getRelationshipName();
        if (!String.isBlank(rel)) return rel;
        if (fieldApi.endsWith('__c')) return fieldApi.substring(0, fieldApi.length()-3) + '__r';
        if (fieldApi.endsWith('Id'))   return fieldApi.substring(0, fieldApi.length()-2);
        return null;
    }

    private static String buildClause(String api, Schema.DescribeFieldResult fdr, String userText) {
        Schema.DisplayType t = fdr.getType();
        String v = userText != null ? userText.trim() : null;
        if (String.isBlank(v)) return null;
        Boolean looksLikeId = isLikelyId(v);

        String mode = null;
        if (requestSpec != null && requestSpec.containsKey(api)) {
            Map<String, String> spec = requestSpec.get(api);
            if (spec != null && spec.containsKey('mode')) mode = String.valueOf(spec.get('mode'));
        }
        if ('in'.equalsIgnoreCase(mode)) {
            List<String> vals = new List<String>();
            for (String s : v.split('\\|')) {
                String sv = s == null ? '' : s.trim();
                if (!String.isBlank(sv)) vals.add(quote(sv));
            }
            if (!vals.isEmpty()) return api + ' IN (' + String.join(vals, ',') + ')';
        }

        if (t == Schema.DisplayType.Reference) {
            if (looksLikeId) return api + ' = ' + quote(v);
            String rel = relationshipNameOrGuess(api, fdr);
            if (String.isBlank(rel)) return null;
            return rel + '.Name LIKE ' + quotedLike(v);
        }
        if (t == Schema.DisplayType.Boolean) {
            Boolean b = parseBool(v);
            if (b == null) return null;
            return api + ' = ' + (b ? 'true' : 'false');
        }
        if (isNumericType(t)) {
            Decimal d = parseDecimal(v);
            if (d == null) return null;
            return api + ' = ' + String.valueOf(d);
        }
        if (t == Schema.DisplayType.Date) {
            Date d = parseDate(v);
            if (d == null) return null;
            return api + ' = ' + quote(DateToIso(d));
        }
        if (t == Schema.DisplayType.Datetime) {
            Datetime dt = parseDatetime(v);
            if (dt == null) return null;
            return api + ' = ' + quote(DatetimeToIso(dt));
        }
        if (t == Schema.DisplayType.Picklist) {
            return api + ' = ' + quote(v);
        }
        if (t == Schema.DisplayType.MultiPicklist) {
            List<String> parts = new List<String>();
            for (String s : v.split(';')) {
                String sv = s != null ? s.trim() : '';
                if (!String.isBlank(sv)) parts.add(api + ' INCLUDES ' + quote(sv));
            }
            if (parts.isEmpty()) return null;
            return '(' + String.join(parts, ' AND ') + ')';
        }
        if (isStringLike(t)) {
            return api + ' LIKE ' + quotedLike(v);
        }
        if (looksLikeId) {
            return api + ' = ' + quote(v);
        }
        return api + ' LIKE ' + quotedLike(v);
    }

    private static Boolean isNumericType(Schema.DisplayType t) {
        return t == Schema.DisplayType.Currency ||
               t == Schema.DisplayType.Double   ||
               t == Schema.DisplayType.Integer  ||
               t == Schema.DisplayType.Long     ||
               t == Schema.DisplayType.Percent;
    }
    private static Boolean isStringLike(Schema.DisplayType t) {
        return t == Schema.DisplayType.String ||
               t == Schema.DisplayType.TextArea ||
               t == Schema.DisplayType.Email ||
               t == Schema.DisplayType.Phone ||
               t == Schema.DisplayType.Url ||
               t == Schema.DisplayType.EncryptedString;
    }

    /* ===================== Parsers & format helpers ===================== */
    private static Boolean parseBool(String v) {
        String s = v != null ? v.trim().toLowerCase() : '';
        if (s == 'true' || s == '1' || s == 'yes' || s == 'y')  return true;
        if (s == 'false' || s == '0' || s == 'no'  || s == 'n')  return false;
        return null;
    }
    private static Decimal parseDecimal(String v) {
        try { return Decimal.valueOf(v); } catch (Exception e) { return null; }
    }
    private static Date parseDate(String v) {
        try { return Date.valueOf(v); } catch (Exception e) { return null; }
    }
    private static Datetime parseDatetime(String v) {
        try { return Datetime.valueOf(v); } catch (Exception e) {
            try { return Datetime.valueOfGmt(v); } catch (Exception ex) { return null; }
        }
    }
    private static String quotedLike(String raw) {
        return quote('%' + raw.replace('%','\\%').replace('_','\\_') + '%');
    }
    private static String quote(String s) {
        return '\'' + String.escapeSingleQuotes(s) + '\'';
    }
    private static String DateToIso(Date d) {
        String mm = String.valueOf(d.month()).leftPad(2, '0');
        String dd = String.valueOf(d.day()).leftPad(2, '0');
        return d.year() + '-' + mm + '-' + dd;
    }
    private static String DatetimeToIso(Datetime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
    private static Boolean isLikelyId(String s) {
        Integer n = s != null ? s.length() : 0;
        return n == 15 || n == 18;
    }
}