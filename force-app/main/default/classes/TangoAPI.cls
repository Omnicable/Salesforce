/**
 * @description REST resource that redeems Tango rewards for a Contact. Looks up unredeemed Orders,
 *              creates a Tango RaaS v2 order, marks those Orders redeemed, and writes
 *              {@link Tango_Reward_Log__c} / {@link Tango_Reward_Item__c} rows. Sandbox orgs use a
 *              test recipient and catalog ids so live cards are not issued.
 * @group Tango
 * @see Tango_Credentials__c
 * @see Ecommerce_Rewards__c
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@RestResource(urlMapping='/tango/v1/redeemrewards/*')
global without sharing class TangoAPI {
    /** @description Sandbox Tango recipient email so test redemptions do not email customers. */
    private static final String SANDBOX_TEST_EMAIL = 'cwilliams@omnicable.com';
    /** @description Sandbox Tango recipient first name. */
    private static final String SANDBOX_TEST_FIRST_NAME = 'Chris';
    /** @description Sandbox Tango recipient last name. */
    private static final String SANDBOX_TEST_LAST_NAME = 'Williams';
    /** @description Default sandbox catalog {@code etid} when {@link Tango_Credentials__c#ETID__c} is blank. */
    private static final String SANDBOX_DEFAULT_ETID = 'E000000';
    /** @description Default sandbox catalog {@code utid} when {@link Tango_Credentials__c#UTID__c} is blank. */
    private static final String SANDBOX_DEFAULT_UTID = 'U561593';
    /** @description Fallback sender email when {@link Ecommerce_Rewards__c#Sender_Email__c} is blank. */
    private static final String DEFAULT_SENDER_EMAIL = 'portal@omnicable.com';
    /** @description Fallback sender first name when {@link Ecommerce_Rewards__c#Sender_First_Name__c} is blank. */
    private static final String DEFAULT_SENDER_FIRST_NAME = 'OmniCable';
    /** @description Tango RaaS v2 orders path appended to the configured base URL. */
    private static final String ORDERS_PATH = '/raas/v2/orders';

    /**
     * @description Cached {@link Organization#IsSandbox} for this transaction; null until first
     *              {@link #isSandbox} call.
     */
    private static Boolean sandboxOrg;

    /**
     * @description JSON body returned from {@link #redeemRewards}. Apex REST HTTP status is always
     *              200; {@link #httpStatus} is the logical outcome. {@link #tango} is set only when
     *              Tango was called.
     */
    global class TangoRewardResponse {
        /** @description True only when Tango fulfilled the order and Salesforce Orders were updated. */
        public Boolean success { get; set; }
        /** @description Machine-readable code such as {@code contact_not_found}; null on success. */
        public String code { get; set; }
        /** @description Client-facing status or error text. */
        public String message { get; set; }
        /** @description Logical HTTP status for this outcome (not the Apex REST status). */
        public Integer httpStatus { get; set; }
        /** @description Reward balance before redemption. */
        public Decimal oldValue { get; set; }
        /** @description Reward balance after redemption; {@code 0} on success. */
        public Decimal newValue { get; set; }
        /** @description Tango RaaS result; null when Tango was not called. */
        public TangoAPIHelper.TangoResult tango { get; set; }
    }

    /**
     * @description Tango RaaS v2 recipient or sender.
     */
    private class TangoPerson {
        /** @description Email address. */
        public String email;
        /** @description First name. */
        public String firstName;
        /** @description Last name. */
        public String lastName;

        /**
         * @description Creates a Tango person.
         * @param email Email address.
         * @param firstName First name.
         * @param lastName Last name.
         */
        TangoPerson(String email, String firstName, String lastName) {
            this.email = email;
            this.firstName = firstName;
            this.lastName = lastName;
        }
    }

    /**
     * @description Tango RaaS v2 create-order request body.
     */
    private class TangoOrderPayload {
        /** @description Tango account identifier from {@link Tango_Credentials__c}. */
        public String accountIdentifier;
        /** @description Tango customer identifier from {@link Tango_Credentials__c}. */
        public String customerIdentifier;
        /** @description Reward email message from {@link Ecommerce_Rewards__c#Redeem_Email_Message__c}. */
        public String message;
        /** @description Redemption amount in dollars. */
        public Decimal amount;
        /** @description Whether Tango should email the recipient. */
        public Boolean sendEmail;
        /** @description Tango catalog {@code etid}. */
        public String etid;
        /** @description Tango catalog {@code utid}. */
        public String utid;
        /** @description Reward recipient. */
        public TangoPerson recipient;
        /** @description Reward sender. */
        public TangoPerson sender;
    }

    /**
     * @description Inputs for building a sandbox or production Tango order body.
     */
    private class TangoOrderContext {
        /** @description Production recipient Contact. */
        public Contact contact;
        /** @description Org default ecommerce reward settings. */
        public Ecommerce_Rewards__c rewardSettings;
        /** @description Org default Tango credentials. */
        public Tango_Credentials__c credentials;
        /** @description Redemption amount. */
        public Decimal total;
        /** @description email. */
        public String email;
    }

    /**
     * @description Error details applied by {@link #fail}.
     */
    private class TangoFailDetail {
        /** @description Machine-readable error code. */
        public String code;
        /** @description Client-facing message. */
        public String message;
        /** @description Logical HTTP status stored on the response and log. */
        public Integer httpStatus;

        /**
         * @description Creates fail details for {@link #fail}.
         * @param code Machine-readable error code.
         * @param message Client-facing message.
         * @param httpStatus Logical HTTP status.
         */
        TangoFailDetail(String code, String message, Integer httpStatus) {
            this.code = code;
            this.message = message;
            this.httpStatus = httpStatus;
        }
    }

    /**
     * @description Redeems Tango rewards for the given contact identifiers. Apex REST always
     *              returns HTTP 200 so DML commits; {@link TangoRewardResponse#httpStatus} carries
     *              the logical status. {@link TangoAPIHelper.TangoResult} is present only when Tango was called.
     * @param id Salesforce Contact Id.
     * @param externalId Contact {@code Ext_Id__c}.
     * @return {@link TangoRewardResponse} serialized as the HTTP JSON body.
     */
    @HttpPost
    global static TangoRewardResponse redeemRewards(String id, String externalId, String email) {
        Tango_Reward_Log__c log = new Tango_Reward_Log__c();
        List<Tango_Reward_Item__c> items = new List<Tango_Reward_Item__c>();
        TangoRewardResponse response = new TangoRewardResponse();
        DateTime redeemDate = DateTime.now();

        try {
            Contact contact = getContact(id, externalId);
            log.Contact__c = contact?.Id;
            log.Name = contact?.Name;
            if (contact == null) {
                return fail(
                    response,
                    log,
                    new TangoFailDetail(
                        'contact_not_found',
                        'Contact not found for id: ' + id + ' or externalId: ' + externalId,
                        404
                    )
                );
            }
            if (contact.OCC_PendingRedeemIssue__c) {
                return fail(
                    response,
                    log,
                    new TangoFailDetail('contact_pending_redeem_issue', 'Contact has a pending redeem issue. Please contact support.', 400)
                );
            }

            Ecommerce_Rewards__c rewardSettings = Ecommerce_Rewards__c.getOrgDefaults();
            if (rewardSettings == null || rewardSettings.Active__c == false) {
                return fail(
                    response,
                    log,
                    new TangoFailDetail('rewards_unavailable', 'Rewards are temporarily unavailable', 503)
                );
            }

            List<Order> orders = getUnredeemedOrders(
                contact.Id,
                contact.Tango_Start_Date__c,
                contact.Tango_End_Date__c
            );
            Decimal rewardTotal = sumRewards(orders);
            response.oldValue = rewardTotal;
            response.newValue = rewardTotal;
            log.Redeem_Amount__c = rewardTotal;
            if (rewardTotal <= 0) {
                return fail(response, log, new TangoFailDetail('no_rewards_available', 'No rewards available', 400));
            }

            HttpResponse tangoHttp = createTangoOrder(newOrderContext(contact, rewardSettings, rewardTotal, email));
            System.debug('tangoHttp: ' + tangoHttp.getBody());
            response.tango = TangoAPIHelper.toTangoResult(tangoHttp);
            log.Status_Code__c = tangoHttp.getStatusCode();
            log.API_Error_Message__c = tangoHttp.getBody();
            if (!TangoAPIHelper.isSuccessStatus(tangoHttp.getStatusCode())) {
                return failFromTango(response, log);
            }

            log.Tango_Order_Id__c = response.tango.order == null ? null : response.tango.order.referenceOrderID;
            log.Fulfilled__c = true;
            log.Status_Code__c = 200;

            markRedeemed(orders, redeemDate);
            Database.SaveResult[] orderResults = Database.update(orders, false);
            items.addAll(TangoAPIHelper.toRewardItems(orders, orderResults));

            if (hasSaveError(orderResults)) {
               contact.OCC_PendingRedeemIssue__c = true;
               update contact;
            }

            response.success = true;
            response.httpStatus = 200;
            response.newValue = 0;
            response.message = firstNonBlank(
                rewardSettings.Confirmation_Message__c,
                'Rewards redeemed successfully'
            );
            return response;
        } catch (Exception e) {
            log.API_Error_Message__c = e.getMessage();
            return fail(
                response,
                log,
                new TangoFailDetail('internal_server_error', e.getMessage(), 500)
            );
        } finally {
            TangoAPIHelper.persistLog(log, items);
            applyHttpStatus();
        }
    }

    /**
     * @description Loads a Contact by Salesforce Id, or by {@code Ext_Id__c} when Id is blank.
     * @param id Salesforce Contact Id.
     * @param externalId Contact {@code Ext_Id__c}.
     * @return Matching Contact, or null when neither identifier is usable.
     */
    private static Contact getContact(String id, String externalId) {
        if (String.isNotBlank(id)) {
            return queryContactById(id);
        }
        if (String.isNotBlank(externalId)) {
            return queryContactByExternalId(externalId);
        }
        return null;
    }

    /**
     * @description Loads a Contact by Salesforce Id.
     * @param id Salesforce Contact Id.
     * @return Matching Contact, or null when none exists.
     */
    private static Contact queryContactById(String id) {
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Name, Email, Ext_Id__c, OCC_PendingRedeemIssue__c, Tango_Start_Date__c, Tango_End_Date__c
            FROM Contact
            WHERE Id = :id
            LIMIT 1
        ];
        return firstContact(contacts);
    }

    /**
     * @description Loads a Contact by {@code Ext_Id__c}.
     * @param externalId Contact {@code Ext_Id__c}.
     * @return Matching Contact, or null when none exists.
     */
    private static Contact queryContactByExternalId(String externalId) {
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Name, Email, Ext_Id__c, OCC_PendingRedeemIssue__c, Tango_Start_Date__c, Tango_End_Date__c
            FROM Contact
            WHERE Ext_Id__c = :externalId
            LIMIT 1
        ];
        return firstContact(contacts);
    }

    /**
     * @description First Contact in the list, or null when empty.
     * @param contacts Query results.
     * @return First row or null.
     */
    private static Contact firstContact(List<Contact> contacts) {
        return contacts.isEmpty() ? null : contacts[0];
    }

    /**
     * @description Unredeemed, non-cancelled Orders for the contact, locked for update.
     *              A blank Tango date window does not filter on invoiced datetime.
     * @param contactId Buyer Id.
     * @param startDate Inclusive {@link Contact#Tango_Start_Date__c}; null means no lower bound.
     * @param endDate Inclusive {@link Contact#Tango_End_Date__c}; null means no upper bound.
     * @return Orders whose Tango totals should be redeemed.
     */
    private static List<Order> getUnredeemedOrders(Id contactId, Date startDate, Date endDate) {
        if (startDate == null && endDate == null) {
            return [
                SELECT Id, Name, Tango_Rewards_Total__c, Tango_Rewards_Override__c
                FROM Order
                WHERE BillToContactId = :contactId
                    AND Tango_Redeemed__c = FALSE
                    AND Status__c != 'Cancelled'
                FOR UPDATE
            ];
        }
        Datetime startBound = startDate == null
            ? Datetime.newInstanceGmt(1900, 1, 1)
            : Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime endBound = endDate == null
            ? Datetime.newInstanceGmt(4000, 12, 31, 23, 59, 59)
            : Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0)).addSeconds(-1);
        return [
            SELECT Id, Name, Tango_Rewards_Total__c, Tango_Rewards_Override__c
            FROM Order
            WHERE BillToContactId = :contactId
                AND Tango_Redeemed__c = FALSE
                AND Status__c != 'Cancelled'
                AND Invoiced_Date_Time__c >= :startBound
                AND Invoiced_Date_Time__c <= :endBound
            FOR UPDATE
        ];
    }

    /**
     * @description Sums {@link Order#Tango_Rewards_Total__c} on the given orders.
     * @param orders Unredeemed orders; null totals are skipped.
     * @return Combined reward amount, or {@code 0} when the list is empty.
     */
    private static Decimal sumRewards(List<Order> orders) {
        Decimal total = 0;
        for (Order order : orders) {
            if (order.Tango_Rewards_Total__c != null) {
                total += order.Tango_Rewards_Total__c;
            }
        }
        return total;
    }

    /**
     * @description Sets {@link Order#Tango_Redeemed__c} and {@link Order#Tango_Redeem_Date__c} in memory.
     * @param orders Orders that were included in the redemption.
     * @param redeemDate Timestamp stored on each Order.
     */
    private static void markRedeemed(List<Order> orders, DateTime redeemDate) {
        for (Order order : orders) {
            order.Tango_Redeemed__c = true;
            order.Tango_Redeem_Date__c = redeemDate;
        }
    }

    /**
     * @description POSTs a create-order request to Tango RaaS v2.
     * @param context Contact, settings, credentials, and amount.
     * @return Tango HTTP response.
     */
    private static HttpResponse createTangoOrder(TangoOrderContext context) {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(getEndpoint(context.credentials));
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        String authorization = getAuthorizationHeader(context.credentials);
        if (String.isNotBlank(authorization)) {
            req.setHeader('Authorization', authorization);
        }
        req.setBody(JSON.serialize(buildOrderPayload(context), true));
        return new Http().send(req);
    }

    /**
     * @description Builds callout context from the contact, settings, and amount.
     * @param contact Production recipient.
     * @param rewardSettings Org default ecommerce reward settings.
     * @param total Redemption amount.
     * @return Context passed to {@link #buildOrderPayload}.
     */
    private static TangoOrderContext newOrderContext(
        Contact contact,
        Ecommerce_Rewards__c rewardSettings,
        Decimal total,
        String email
    ) {
        TangoOrderContext context = new TangoOrderContext();
        context.contact = contact;
        context.rewardSettings = rewardSettings;
        context.credentials = Tango_Credentials__c.getOrgDefaults();
        context.total = total;
        context.email = email;
        return context;
    }

    /**
     * @description Builds the Tango create-order body for sandbox or production. Sandbox uses a
     *              test recipient and catalog fallbacks; production uses the Contact and org catalog ids.
     * @param context Shared order inputs.
     * @return Typed payload for {@link JSON#serialize}.
     */
    private static TangoOrderPayload buildOrderPayload(TangoOrderContext context) {
        Ecommerce_Rewards__c rewardSettings = context.rewardSettings;
        Tango_Credentials__c credentials = context.credentials;
        TangoOrderPayload payload = new TangoOrderPayload();
        payload.accountIdentifier = credentials?.Account_Identifier__c;
        payload.customerIdentifier = credentials?.Customer_Identifier__c;
        payload.message = rewardSettings?.Redeem_Email_Message__c;
        payload.amount = context.total;
        payload.sendEmail = true;
        payload.sender = new TangoPerson(
            firstNonBlank(rewardSettings?.Sender_Email__c, DEFAULT_SENDER_EMAIL),
            firstNonBlank(rewardSettings?.Sender_First_Name__c, DEFAULT_SENDER_FIRST_NAME),
            null
        );
        if (isSandbox()) {
            payload.etid = firstNonBlank(credentials?.ETID__c, SANDBOX_DEFAULT_ETID);
            payload.utid = firstNonBlank(credentials?.UTID__c, SANDBOX_DEFAULT_UTID);
            payload.recipient = new TangoPerson(
                context.email == null ? SANDBOX_TEST_EMAIL : context.email,
                SANDBOX_TEST_FIRST_NAME,
                SANDBOX_TEST_LAST_NAME
            );
        } else {
            payload.etid = credentials?.ETID__c;
            payload.utid = credentials?.UTID__c;
            payload.recipient = new TangoPerson(
                context.email == null ? context.contact.Email : context.email,
                context.contact.FirstName,
                context.contact.LastName
            );
        }
        return payload;
    }

    /**
     * @description Tango RaaS v2 orders URL for the current org type.
     * @param credentials Base URLs from org defaults.
     * @return Full orders endpoint.
     */
    private static String getEndpoint(Tango_Credentials__c credentials) {
        String baseUrl = isSandbox() ? credentials.Sandbox_Base_URL__c : credentials.Prod_Base_URL__c;
        return baseUrl + ORDERS_PATH;
    }

    /**
     * @description Authorization header from {@link Tango_Credentials__c#API_Key__c}.
     * @param credentials Org default Tango credentials.
     * @return Basic header, or null when no key is configured.
     */
    private static String getAuthorizationHeader(Tango_Credentials__c credentials) {
        if (credentials == null || String.isBlank(credentials.API_Key__c)) {
            return null;
        }
        return credentials.API_Key__c.startsWithIgnoreCase('Basic ')
            ? credentials.API_Key__c
            : 'Basic ' + credentials.API_Key__c;
    }

    /**
     * @description Whether this org is a sandbox. Result is cached for the transaction.
     * @return True when {@link Organization#IsSandbox} is true.
     */
    private static Boolean isSandbox() {
        if (sandboxOrg == null) {
            sandboxOrg = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        }
        return sandboxOrg;
    }

    /**
     * @description Fills the error envelope and log status for a failed redeem.
     * @param response Response to populate.
     * @param log Log row to populate.
     * @param detail Error code, message, and logical HTTP status.
     * @return The same {@code response} instance.
     */
    private static TangoRewardResponse fail(
        TangoRewardResponse response,
        Tango_Reward_Log__c log,
        TangoFailDetail detail
    ) {
        response.success = false;
        response.code = detail.code;
        response.message = detail.message;
        response.httpStatus = detail.httpStatus;
        log.Status_Code__c = detail.httpStatus;
        if (String.isBlank(log.API_Error_Message__c)) {
            log.API_Error_Message__c = detail.message;
        }
        return response;
    }

    /**
     * @description Maps a failed Tango call onto {@link TangoRewardResponse} and the log.
     * @param response Response whose {@link TangoAPIHelper.TangoResult} is already set.
     * @param log Log row to populate.
     * @return The same {@code response} instance.
     */
    private static TangoRewardResponse failFromTango(TangoRewardResponse response, Tango_Reward_Log__c log) {
        return fail(
            response,
            log,
            new TangoFailDetail(
                'tango_order_failed',
                TangoAPIHelper.tangoErrorMessage(response.tango),
                TangoAPIHelper.tangoHttpStatus(response.tango)
            )
        );
    }

    /**
     * @description Always returns HTTP 200 from Apex REST so DML in this request commits.
     */
    private static void applyHttpStatus() {
        RestResponse restResponse = RestContext.response;
        if (restResponse == null) {
            return;
        }
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.statusCode = 200;
    }

    /**
     * @description Whether any {@link Database.SaveResult} failed.
     * @param results Order update results.
     * @return True when at least one save failed.
     */
    private static Boolean hasSaveError(Database.SaveResult[] results) {
        if (results == null) {
            return false;
        }
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description First non-blank string.
     * @param value Preferred value.
     * @param fallback Used when {@code value} is blank.
     * @return Preferred or fallback.
     */
    private static String firstNonBlank(String value, String fallback) {
        return String.isNotBlank(value) ? value : fallback;
    }
}