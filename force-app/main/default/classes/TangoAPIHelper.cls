/**
 * @description Persistence and Tango JSON mapping for {@link TangoAPI}. Extracted so
 *              {@link TangoAPI} stays under the class Cognitive Complexity threshold.
 *              Owns Tango response types so {@link TangoAPI} can depend on this class
 *              without a compile cycle.
 * @group Tango
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class TangoAPIHelper {
    /**
     * @description Tango RaaS create-order HTTP result.
     */
    public class TangoResult {
        /** @description Tango HTTP status. */
        public Integer httpStatus { get; set; }
        /** @description Parsed order when Tango returns 2xx; otherwise null. */
        public TangoOrderResult order { get; set; }
        /** @description Parsed error when Tango returns non-2xx JSON; otherwise null. */
        public TangoServiceError error { get; set; }
    }

    /**
     * @description Tango RaaS v2 create-order success fields used by this API.
     */
    public class TangoOrderResult {
        /** @description Tango {@code referenceOrderID}. */
        public String referenceOrderID { get; set; }
        /** @description Tango order status. */
        public String status { get; set; }
        /** @description Catalog {@code utid}. */
        public String utid { get; set; }
        /** @description Reward product name. */
        public String rewardName { get; set; }
    }

    /**
     * @description Tango RaaS v2 error body (HTTP 400 and other non-2xx JSON).
     */
    public class TangoServiceError {
        /** @description Tango error timestamp. */
        public String timestamp { get; set; }
        /** @description Tango request identifier. */
        public String requestId { get; set; }
        /** @description Request path that failed. */
        public String path { get; set; }
        /** @description Tango HTTP status code. */
        public Integer httpCode { get; set; }
        /** @description Tango HTTP reason phrase. */
        public String httpPhrase { get; set; }
        /** @description Tango i18n key. */
        public String i18nKey { get; set; }
        /** @description Tango error message. */
        public String message { get; set; }
        /** @description Field or item-level errors from Tango. */
        public List<TangoServiceErrorDetail> errors { get; set; }
    }

    /**
     * @description One entry in {@link TangoServiceError#errors}.
     */
    public class TangoServiceErrorDetail {
        /** @description JSON path of the invalid field. */
        public String path { get; set; }
        /** @description Tango error code. */
        public String code { get; set; }
        /** @description Tango i18n key. */
        public String i18nKey { get; set; }
        /** @description Detail message. */
        public String message { get; set; }
    }

    /**
     * @description Builds {@link TangoResult} from a Tango HTTP response.
     * @param tangoHttp Tango create-order response.
     * @return Parsed Tango result.
     */
    public static TangoResult toTangoResult(HttpResponse tangoHttp) {
        TangoResult result = new TangoResult();
        if (tangoHttp == null) {
            return result;
        }
        result.httpStatus = tangoHttp.getStatusCode();
        String body = tangoHttp.getBody();
        if (isSuccessStatus(result.httpStatus)) {
            result.order = parseTangoOrder(body);
        } else {
            result.error = parseTangoServiceError(body);
        }
        return result;
    }

    /**
     * @description Tango HTTP status, or 502 when the result is missing.
     * @param tango Parsed Tango result.
     * @return Status to store on the redeem envelope.
     */
    public static Integer tangoHttpStatus(TangoResult tango) {
        if (tango == null || tango.httpStatus == null) {
            return 502;
        }
        return tango.httpStatus;
    }

    /**
     * @description Tango error message, or a generic fallback.
     * @param tango Parsed Tango result.
     * @return Client-facing Tango failure text.
     */
    public static String tangoErrorMessage(TangoResult tango) {
        if (tango == null || tango.error == null || String.isBlank(tango.error.message)) {
            return 'Tango order failed';
        }
        return tango.error.message;
    }

    /**
     * @description Whether an HTTP status is 2xx.
     * @param statusCode HTTP status.
     * @return True for 200–299.
     */
    public static Boolean isSuccessStatus(Integer statusCode) {
        return statusCode != null && String.valueOf(statusCode).startsWith('2');
    }

    /**
     * @description Inserts the redeem log and related order items. Failures are logged and not rethrown.
     * @param log Header log row.
     * @param items Order-level log rows.
     */
    public static void persistLog(Tango_Reward_Log__c log, List<Tango_Reward_Item__c> items) {
        if (log == null) {
            return;
        }
        truncateLogName(log);
        try {
            insert log;
            insertItems(log.Id, items);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Tango reward log persist failed: ' + e.getMessage());
        }
    }

    /**
     * @description Maps Order update results to {@link Tango_Reward_Item__c} rows.
     * @param orders Orders that were updated.
     * @param results Parallel save results.
     * @return Items to insert after the log.
     */
    public static List<Tango_Reward_Item__c> toRewardItems(List<Order> orders, Database.SaveResult[] results) {
        List<Tango_Reward_Item__c> items = new List<Tango_Reward_Item__c>();
        if (orders == null || results == null) {
            return items;
        }
        for (Integer i = 0; i < results.size(); i++) {
            Tango_Reward_Item__c item = new Tango_Reward_Item__c();
            item.Name = orders[i].Name;
            item.Order__c = orders[i].Id;
            item.Error__c = !results[i].isSuccess();
            items.add(item);
        }
        return items;
    }

    /**
     * @description Caps {@link Tango_Reward_Log__c#Name} at 80 characters.
     * @param log Log row to truncate in place.
     */
    private static void truncateLogName(Tango_Reward_Log__c log) {
        if (log.Name != null && log.Name.length() > 80) {
            log.Name = log.Name.substring(0, 80);
        }
    }

    /**
     * @description Inserts item rows after the log Id is known.
     * @param logId Parent log Id.
     * @param items Order-level log rows.
     */
    private static void insertItems(Id logId, List<Tango_Reward_Item__c> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        for (Tango_Reward_Item__c item : items) {
            item.Tango_Reward_Log__c = logId;
        }
        insert items;
    }

    /**
     * @description Parses Tango create-order success JSON.
     * @param body Tango response body.
     * @return Order fields, or null when the body is not an object.
     */
    private static TangoOrderResult parseTangoOrder(String body) {
        Map<String, Object> raw = parseJsonMap(body);
        if (raw.isEmpty()) {
            return null;
        }
        TangoOrderResult order = new TangoOrderResult();
        order.referenceOrderID = toStringValue(raw.get('referenceOrderID'));
        order.status = toStringValue(raw.get('status'));
        order.utid = toStringValue(raw.get('utid'));
        order.rewardName = toStringValue(raw.get('rewardName'));
        return order;
    }

    /**
     * @description Parses Tango RaaS error JSON.
     * @param body Tango response body.
     * @return Parsed error, or null when the body is blank or not an object.
     */
    private static TangoServiceError parseTangoServiceError(String body) {
        Map<String, Object> raw = parseJsonMap(body);
        if (raw.isEmpty()) {
            return null;
        }
        TangoServiceError tangoError = new TangoServiceError();
        tangoError.timestamp = toStringValue(raw.get('timestamp'));
        tangoError.requestId = toStringValue(raw.get('requestId'));
        tangoError.path = toStringValue(raw.get('path'));
        tangoError.httpPhrase = toStringValue(raw.get('httpPhrase'));
        tangoError.i18nKey = toStringValue(raw.get('i18nKey'));
        tangoError.message = toStringValue(raw.get('message'));
        Object httpCode = raw.get('httpCode');
        if (httpCode != null) {
            tangoError.httpCode = Integer.valueOf(String.valueOf(httpCode));
        }
        tangoError.errors = parseTangoErrorDetails(raw.get('errors'));
        return tangoError;
    }

    /**
     * @description Maps Tango {@code errors} array entries; null items are skipped.
     * @param errorsObj Value of the {@code errors} property.
     * @return Detail rows.
     */
    private static List<TangoServiceErrorDetail> parseTangoErrorDetails(Object errorsObj) {
        List<TangoServiceErrorDetail> details = new List<TangoServiceErrorDetail>();
        if (!(errorsObj instanceof List<Object>)) {
            return details;
        }
        for (Object item : (List<Object>) errorsObj) {
            TangoServiceErrorDetail detail = toErrorDetail(item);
            if (detail != null) {
                details.add(detail);
            }
        }
        return details;
    }

    /**
     * @description Maps one Tango {@code errors} entry.
     * @param item Raw array element.
     * @return Detail row, or null when {@code item} is null.
     */
    private static TangoServiceErrorDetail toErrorDetail(Object item) {
        if (item == null) {
            return null;
        }
        TangoServiceErrorDetail detail = new TangoServiceErrorDetail();
        if (!(item instanceof Map<String, Object>)) {
            detail.message = String.valueOf(item);
            return detail;
        }
        Map<String, Object> fields = (Map<String, Object>) item;
        detail.path = toStringValue(fields.get('path'));
        detail.code = toStringValue(fields.get('code'));
        detail.i18nKey = toStringValue(fields.get('i18nKey'));
        detail.message = toStringValue(fields.get('message'));
        return detail;
    }

    /**
     * @description String form of an untyped JSON value. Null stays null so missing fields are not
     *              stored as the literal {@code "null"}.
     * @param value Untyped JSON value.
     * @return String representation, or null.
     */
    private static String toStringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    /**
     * @description Parses a JSON object body; empty or non-object bodies become an empty map.
     * @param body Response body.
     * @return Deserialized map.
     */
    private static Map<String, Object> parseJsonMap(String body) {
        if (String.isBlank(body)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(body);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
        } catch (Exception e) {
            return new Map<String, Object>();
        }
        return new Map<String, Object>();
    }
}