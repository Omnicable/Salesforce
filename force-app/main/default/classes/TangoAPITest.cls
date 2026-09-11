/**
 * @description Unit tests for {@link TangoAPI} redeem outcomes: Salesforce validation, Tango
 *              callouts, Order updates, and {@link Tango_Reward_Log__c} persistence.
 * @group Tango
 * @see TangoAPI
 * @see TangoAPIHelper
 */
@IsTest
@SuppressWarnings('PMD.ApexCRUDViolation')
private without sharing class TangoAPITest {
    /** @description Last name for the contact with redeemable Orders. */
    private static final String LAST_ELIGIBLE = 'TangoEligible';
    /** @description Last name for the contact flagged with a pending redeem issue. */
    private static final String LAST_PENDING = 'TangoPending';
    /** @description Last name for the contact with no Orders. */
    private static final String LAST_NO_ORDERS = 'TangoNoOrders';
    /** @description Successful Tango create-order body. */
    private static final String SUCCESS_BODY =
        '{"referenceOrderID":"RA-TEST-1","status":"COMPLETE","utid":"U561593","rewardName":"Amazon.com"}';
    /** @description Tango insufficient-funds body with a numeric error code. */
    private static final String INSUFFICIENT_FUNDS_BODY =
        '{"timestamp":"2026-09-09T17:24:10.498Z","requestId":"req-1","path":"/raas/v2/orders",'
        + '"httpCode":400,"httpPhrase":"Bad Request","i18nKey":"400.126",'
        + '"message":"The account does not have sufficient funds",'
        + '"errors":[null,{"path":"","code":400126,"i18nKey":"400.126",'
        + '"message":"The account does not have sufficient funds"},"plain"]}';

    /**
     * @description Http mock that returns a fixed Tango status and body and stores the request.
     */
    private class TangoHttpMock implements HttpCalloutMock {
        /** @description Captured Tango request. */
        public HttpRequest request;
        /** @description HTTP status to return. */
        private Integer statusCode;
        /** @description Response body to return. */
        private String body;

        /**
         * @description Creates a mock Tango response.
         * @param statusCode HTTP status.
         * @param body Response body.
         */
        TangoHttpMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        /**
         * @description Stores the request and returns the configured response.
         * @param httpRequest Outbound Tango request.
         * @return Mock HTTP response.
         */
        public HttpResponse respond(HttpRequest httpRequest) {
            this.request = httpRequest;
            HttpResponse httpResponse = new HttpResponse();
            httpResponse.setStatusCode(this.statusCode);
            httpResponse.setBody(this.body);
            return httpResponse;
        }
    }

    /**
     * @description Http mock that throws so {@link TangoAPI#redeemRewards} hits the catch path.
     */
    private class ThrowingHttpMock implements HttpCalloutMock {
        /**
         * @description Always throws.
         * @param httpRequest Outbound Tango request.
         * @return Never returns.
         */
        public HttpResponse respond(HttpRequest httpRequest) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    /**
     * @description Inserts org defaults, contacts, and Orders used by redeem tests.
     */
    @TestSetup
    static void setup() {
        upsertOrgSettings(true, 'Rewards redeemed successfully', 'testApiKey');

        Account account = new Account(
            Name = 'Tango API Test Account',
            Account_Number__c = 'TNG0001',
            Active__c = 'A'
        );
        insert account;

        Contact eligible = newContact(account.Id, LAST_ELIGIBLE, account.Account_Number__c + ':1');
        eligible.Sequence__c = 1;
        Contact pending = newContact(account.Id, LAST_PENDING, account.Account_Number__c + ':2');
        pending.OCC_PendingRedeemIssue__c = true;
        pending.Sequence__c = 2;
        Contact noOrders = newContact(account.Id, LAST_NO_ORDERS, account.Account_Number__c + ':3');
        noOrders.Sequence__c = 3;
        insert new List<Contact>{ eligible, pending, noOrders };

        eligible.Tango_Start_Date__c = Date.today().addYears(-1);
        eligible.Tango_End_Date__c = Date.today().addYears(1);
        update eligible;

        Datetime invoicedAt = Datetime.now();
        Order redeemable = newOrder(account.Id, eligible.Id, 'TangoRedeemable');
        redeemable.Tango_Rewards_Override__c = 25;
        redeemable.Invoiced_Date_Time__c = invoicedAt;
        Order zeroTotal = newOrder(account.Id, eligible.Id, 'TangoZero');
        zeroTotal.Invoiced_Date_Time__c = invoicedAt;
        Order cancelled = newOrder(account.Id, eligible.Id, 'TangoCancelled');
        cancelled.Status__c = 'Cancelled';
        cancelled.Tango_Rewards_Override__c = 100;
        cancelled.Invoiced_Date_Time__c = invoicedAt;
        Order alreadyRedeemed = newOrder(account.Id, eligible.Id, 'TangoAlreadyRedeemed');
        alreadyRedeemed.Tango_Redeemed__c = true;
        alreadyRedeemed.Tango_Rewards_Override__c = 50;
        alreadyRedeemed.Invoiced_Date_Time__c = invoicedAt;
        insert new List<Order>{ redeemable, zeroTotal, cancelled, alreadyRedeemed };
    }

    /**
     * @description Blank identifiers return contact_not_found without calling Tango.
     */
    @IsTest
    static void testContactNotFoundWhenIdentifiersBlank() {
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(null, null);

        assertFailure(response, 'contact_not_found', 404);
        System.assertEquals(null, response.tango, 'Tango should not be called when the contact is missing');
    }

    /**
     * @description An unused Contact Id returns contact_not_found.
     */
    @IsTest
    static void testContactNotFoundByUnknownId() {
        Id missingId = Contact.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(missingId, null);

        assertFailure(response, 'contact_not_found', 404);
        System.assertEquals(null, response.tango, 'Tango should not be called when the contact Id is unknown');
    }

    /**
     * @description A pending redeem issue returns 400 and does not call Tango.
     */
    @IsTest
    static void testPendingRedeemIssue() {
        Contact pending = getContactByLastName(LAST_PENDING);

        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(pending.Id, null);

        assertFailure(response, 'contact_pending_redeem_issue', 400);
        System.assertEquals(null, response.tango, 'Tango should not be called for a pending redeem issue');
    }

    /**
     * @description Inactive ecommerce rewards return 503.
     */
    @IsTest
    static void testRewardsUnavailableWhenInactive() {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        upsertOrgSettings(false, 'Rewards redeemed successfully', 'testApiKey');

        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(eligible.Id, null);

        assertFailure(response, 'rewards_unavailable', 503);
        System.assertEquals(null, response.tango, 'Tango should not be called when rewards are inactive');
    }

    /**
     * @description A contact with no Orders returns no_rewards_available.
     */
    @IsTest
    static void testNoRewardsWhenContactHasNoOrders() {
        Contact noOrders = getContactByLastName(LAST_NO_ORDERS);

        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(noOrders.Id, null);

        assertFailure(response, 'no_rewards_available', 400);
        System.assertEquals(0, response.oldValue, 'Old value should be zero when no Orders exist');
        System.assertEquals(null, response.tango, 'Tango should not be called when no rewards exist');
    }

    /**
     * @description Lookup by Ext_Id__c finds the contact and redeems when Tango succeeds.
     */
    @IsTest
    static void testSuccessfulRedeemByExternalId() {
        TangoHttpMock mock = new TangoHttpMock(201, SUCCESS_BODY);
        Test.setMock(HttpCalloutMock.class, mock);
        initRestContext();

        Test.startTest();
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(null, getContactByLastName(LAST_ELIGIBLE).Ext_Id__c);
        Test.stopTest();

        System.assertEquals(
            true,
            response.success,
            'Redeem should succeed: ' + response.code + ' ' + response.message
        );
        System.assertEquals(200, response.httpStatus, 'Logical status should be 200');
        System.assertEquals(25, response.oldValue, 'Old value should be the unredeemed reward total');
        System.assertEquals(0, response.newValue, 'New value should be zero after a successful redeem');
        System.assertEquals(
            'Rewards redeemed successfully',
            response.message,
            'Confirmation message should come from ecommerce settings'
        );
        System.assertEquals(201, response.tango.httpStatus, 'Tango HTTP status should be returned');
        System.assertEquals(
            'RA-TEST-1',
            response.tango.order.referenceOrderID,
            'Tango order id should be parsed'
        );
        System.assertEquals(200, RestContext.response.statusCode, 'Apex REST status should stay 200');
        System.assert(
            mock.request.getEndpoint().contains('/raas/v2/orders'),
            'Request should post to the Tango orders path'
        );
        System.assertEquals(
            'Basic testApiKey',
            mock.request.getHeader('Authorization'),
            'API key without a Basic prefix should be prefixed'
        );
        System.assert(
            mock.request.getBody().contains('cwilliams@omnicable.com'),
            'Sandbox payload should use the test recipient'
        );
        assertOrdersRedeemed();
        assertLogFulfilled('RA-TEST-1', 25);
    }

    /**
     * @description Contact Id lookup ignores externalId. Blank catalog and sender fields use fallbacks.
     */
    @IsTest
    static void testSuccessfulRedeemUsesSandboxFallbacks() {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        Tango_Credentials__c credentials = Tango_Credentials__c.getOrgDefaults();
        credentials.API_Key__c = 'Basic alreadyPrefixed';
        credentials.ETID__c = null;
        credentials.UTID__c = null;
        update credentials;
        Ecommerce_Rewards__c rewardSettings = Ecommerce_Rewards__c.getOrgDefaults();
        rewardSettings.Confirmation_Message__c = null;
        rewardSettings.Sender_Email__c = null;
        rewardSettings.Sender_First_Name__c = null;
        update rewardSettings;

        TangoHttpMock mock = new TangoHttpMock(200, SUCCESS_BODY);
        Test.setMock(HttpCalloutMock.class, mock);
        initRestContext();

        Test.startTest();
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(eligible.Id, 'wrong-ext-id');
        Test.stopTest();

        System.assertEquals(
            true,
            response.success,
            'Contact Id should win over a mismatched external id: ' + response.code + ' ' + response.message
        );
        System.assertEquals(
            'Rewards redeemed successfully',
            response.message,
            'Blank confirmation message should use the default text'
        );
        System.assertEquals(
            'Basic alreadyPrefixed',
            mock.request.getHeader('Authorization'),
            'API key that already starts with Basic should be left unchanged'
        );
        System.assert(mock.request.getBody().contains('E000000'), 'Blank ETID should use the sandbox default');
        System.assert(mock.request.getBody().contains('U561593'), 'Blank UTID should use the sandbox default');
        System.assert(
            mock.request.getBody().contains('portal@omnicable.com'),
            'Blank sender email should use the default sender'
        );
    }

    /**
     * @description Tango 400 with a numeric error code maps to tango_order_failed.
     */
    @IsTest
    static void testTangoInsufficientFunds() {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        Test.setMock(HttpCalloutMock.class, new TangoHttpMock(400, INSUFFICIENT_FUNDS_BODY));

        Test.startTest();
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(eligible.Id, null);
        Test.stopTest();

        assertFailure(response, 'tango_order_failed', 400);
        System.assertEquals(
            'The account does not have sufficient funds',
            response.message,
            'Envelope message should come from Tango'
        );
        System.assertEquals(400, response.tango.httpStatus, 'Tango status should be preserved');
        System.assertEquals(400126, Integer.valueOf(response.tango.error.errors[0].code), 'Numeric Tango codes should parse');
        System.assertEquals(
            false,
            [SELECT Tango_Redeemed__c FROM Order WHERE Name = 'TangoRedeemable' LIMIT 1].Tango_Redeemed__c,
            'Orders should stay unredeemed when Tango rejects the order'
        );
        Tango_Reward_Log__c log = latestLog(eligible.Id);
        System.assertEquals(false, log.Fulfilled__c, 'Log should not be fulfilled on Tango failure');
        System.assert(
            log.API_Error_Message__c.contains('sufficient funds'),
            'Raw Tango body should be stored on the log'
        );
    }

    /**
     * @description Non-JSON Tango failures still return tango_order_failed with a generic message.
     */
    @IsTest
    static void testTangoFailureWithNonJsonBody() {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        Test.setMock(HttpCalloutMock.class, new TangoHttpMock(502, 'not-json'));

        Test.startTest();
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(eligible.Id, null);
        Test.stopTest();

        assertFailure(response, 'tango_order_failed', 502);
        System.assertEquals('Tango order failed', response.message, 'Missing Tango message should use the fallback');
        System.assertEquals(null, response.tango.error, 'Non-object bodies should not parse as a Tango error');
    }

    /**
     * @description A blank API key still callouts; missing Authorization is allowed.
     */
    @IsTest
    static void testBlankApiKeyOmitsAuthorizationHeader() {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        Tango_Credentials__c credentials = Tango_Credentials__c.getOrgDefaults();
        credentials.API_Key__c = null;
        update credentials;
        TangoHttpMock mock = new TangoHttpMock(200, SUCCESS_BODY);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(eligible.Id, null);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Redeem should succeed without an API key in tests');
        System.assertEquals(null, mock.request.getHeader('Authorization'), 'Blank API key should omit Authorization');
    }

    /**
     * @description Callout exceptions map to internal_server_error.
     */
    @IsTest
    static void testCalloutExceptionReturnsInternalServerError() {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        Test.setMock(HttpCalloutMock.class, new ThrowingHttpMock());

        Test.startTest();
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards(eligible.Id, null);
        Test.stopTest();

        assertFailure(response, 'internal_server_error', 500);
        System.assertEquals(null, response.tango, 'Tango result should be null when the callout throws');
        System.assertEquals(
            'Simulated callout failure',
            latestLog(eligible.Id).API_Error_Message__c,
            'Callout exception text should be stored on the log'
        );
    }

    /**
     * @description A non-Id string is treated as contact_not_found, not an exception.
     */
    @IsTest
    static void testNonIdStringReturnsContactNotFound() {
        TangoAPI.TangoRewardResponse response = TangoAPI.redeemRewards('not-an-id', null);

        assertFailure(response, 'contact_not_found', 404);
        System.assertNotEquals(null, response.message, 'Missing-contact responses should include a message');
    }

    /**
     * @description Upserts hierarchy org defaults for Tango and ecommerce rewards.
     * @param rewardsActive {@link Ecommerce_Rewards__c#Active__c}.
     * @param confirmationMessage {@link Ecommerce_Rewards__c#Confirmation_Message__c}.
     * @param apiKey {@link Tango_Credentials__c#API_Key__c}.
     */
    private static void upsertOrgSettings(Boolean rewardsActive, String confirmationMessage, String apiKey) {
        Tango_Credentials__c credentials = Tango_Credentials__c.getOrgDefaults();
        credentials.SetupOwnerId = UserInfo.getOrganizationId();
        credentials.API_Key__c = apiKey;
        credentials.Account_Identifier__c = 'acct-1';
        credentials.Customer_Identifier__c = 'cust-1';
        credentials.ETID__c = 'E123456';
        credentials.UTID__c = 'U123456';
        credentials.Sandbox_Base_URL__c = 'https://integration-sandbox.tangocard.com';
        credentials.Prod_Base_URL__c = 'https://integration-www.tangocard.com';
        upsert credentials;

        Ecommerce_Rewards__c rewardSettings = Ecommerce_Rewards__c.getOrgDefaults();
        rewardSettings.SetupOwnerId = UserInfo.getOrganizationId();
        rewardSettings.Active__c = rewardsActive;
        rewardSettings.Confirmation_Message__c = confirmationMessage;
        rewardSettings.Redeem_Email_Message__c = 'Enjoy your reward';
        rewardSettings.Sender_Email__c = 'rewards@omnicable.com';
        rewardSettings.Sender_First_Name__c = 'OmniCable';
        upsert rewardSettings;
    }

    /**
     * @description Builds a Contact for testSetup.
     * @param accountId Parent Account Id.
     * @param lastName Last name used as the test key.
     * @param externalId {@link Contact#Ext_Id__c}.
     * @return Uninserted Contact.
     */
    private static Contact newContact(Id accountId, String lastName, String externalId) {
        return new Contact(
            FirstName = 'Tango',
            LastName = lastName,
            Email = lastName.toLowerCase() + '@omnicable.com',
            AccountId = accountId,
            Ext_Id__c = externalId,
            Contact_Title__c = 'Accounting',
            OCC_Rewards__c = true,
            OCC_PendingRedeemIssue__c = false
        );
    }

    /**
     * @description Builds an Order for the given buyer.
     * @param accountId Account Id.
     * @param contactId Bill-to Contact Id.
     * @param name Order name used as the test key.
     * @return Uninserted Order.
     */
    private static Order newOrder(Id accountId, Id contactId, String name) {
        return new Order(
            Name = name,
            AccountId = accountId,
            BillToContactId = contactId,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            Tango_Redeemed__c = false
        );
    }

    /**
     * @description Loads a test Contact by last name.
     * @param lastName Last name from testSetup.
     * @return Matching Contact.
     */
    private static Contact getContactByLastName(String lastName) {
        return [
            SELECT Id, Ext_Id__c
            FROM Contact
            WHERE LastName = :lastName
            LIMIT 1
        ];
    }

    /**
     * @description Sets {@link RestContext} so {@link TangoAPI} can write HTTP 200.
     */
    private static void initRestContext() {
        RestRequest restRequest = new RestRequest();
        restRequest.requestURI = '/services/apexrest/tango/v1/redeemrewards/';
        restRequest.httpMethod = 'POST';
        RestContext.request = restRequest;
        RestContext.response = new RestResponse();
    }

    /**
     * @description Asserts a failed redeem envelope.
     * @param response API response.
     * @param code Expected {@link TangoAPI.TangoRewardResponse#code}.
     * @param httpStatus Expected logical HTTP status.
     */
    private static void assertFailure(TangoAPI.TangoRewardResponse response, String code, Integer httpStatus) {
        System.assertEquals(false, response.success, 'Failure responses should set success to false');
        System.assertEquals(code, response.code, 'Unexpected failure code');
        System.assertEquals(httpStatus, response.httpStatus, 'Unexpected logical HTTP status');
        System.assertNotEquals(null, response.message, 'Failure responses should include a message');
    }

    /**
     * @description Asserts redeemable Orders were marked redeemed and excluded Orders were not updated.
     */
    private static void assertOrdersRedeemed() {
        for (Order orderRecord : [
            SELECT Name, Tango_Redeemed__c, Tango_Redeem_Date__c, Status__c
            FROM Order
            WHERE BillToContactId IN (SELECT Id FROM Contact WHERE LastName = :LAST_ELIGIBLE)
        ]) {
            assertOrderRedeemState(orderRecord);
        }
    }

    /**
     * @description Asserts one Order's redeemed flag after a successful redeem.
     * @param orderRecord Order to inspect.
     */
    private static void assertOrderRedeemState(Order orderRecord) {
        if (orderRecord.Name == 'TangoCancelled') {
            System.assertEquals(false, orderRecord.Tango_Redeemed__c, 'Cancelled Orders should not be redeemed');
            return;
        }
        if (orderRecord.Name == 'TangoAlreadyRedeemed') {
            System.assertEquals(true, orderRecord.Tango_Redeemed__c, 'Already redeemed Orders should stay redeemed');
            return;
        }
        System.assertEquals(true, orderRecord.Tango_Redeemed__c, 'Unredeemed Orders in the query should be marked redeemed');
        System.assertNotEquals(null, orderRecord.Tango_Redeem_Date__c, 'Redeem date should be set');
    }

    /**
     * @description Asserts the latest log is fulfilled with the Tango order id.
     * @param tangoOrderId Expected {@link Tango_Reward_Log__c#Tango_Order_Id__c}.
     * @param amount Expected {@link Tango_Reward_Log__c#Redeem_Amount__c}.
     */
    private static void assertLogFulfilled(String tangoOrderId, Decimal amount) {
        Contact eligible = getContactByLastName(LAST_ELIGIBLE);
        Tango_Reward_Log__c log = latestLog(eligible.Id);
        System.assertEquals(true, log.Fulfilled__c, 'Successful redeem should fulfill the log');
        System.assertEquals(tangoOrderId, log.Tango_Order_Id__c, 'Log should store the Tango order id');
        System.assertEquals(amount, log.Redeem_Amount__c, 'Log should store the redeemed amount');
        System.assertEquals(200, log.Status_Code__c, 'Successful log status should be 200');
        System.assert(
            [SELECT COUNT() FROM Tango_Reward_Item__c WHERE Tango_Reward_Log__c = :log.Id] > 0,
            'Reward items should be inserted for updated Orders'
        );
    }

    /**
     * @description Latest reward log for the contact.
     * @param contactId Contact Id.
     * @return Newest {@link Tango_Reward_Log__c}.
     */
    private static Tango_Reward_Log__c latestLog(Id contactId) {
        return [
            SELECT Fulfilled__c, Tango_Order_Id__c, Redeem_Amount__c, Status_Code__c, API_Error_Message__c
            FROM Tango_Reward_Log__c
            WHERE Contact__c = :contactId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }
}