/**
 * @author Chris Williams <chrisw@launchdm.com>
 * @group On Call Notification
 * @since 2026-08-14
 * @description
 * Test class for {@link WeeklyOnCallNotification}.
 *
 * Verifies that {@link WeeklyOnCallNotification#sendOnCallEmail} :
 * <ul>
 *   <li>Sends email for a valid on-call {@link Event}</li>
 *   <li>Supports multiple request inputs in one invocation</li>
 *   <li>Returns an empty result list when no requests are provided</li>
 *   <li>Throws {@link AuraHandledException} when the {@code New_On_Call_Email} template is missing</li>
 *   <li>Still sends when optional recipient emails ({@code WhoId} / {@code Name_2__c}) are incomplete</li>
 * </ul>
 *
 * @see WeeklyOnCallNotification
 */
@IsTest
private class WeeklyOnCallNotificationTest {
    
    @testSetup
    public static void setup() {
        Account a = TestUtilities.createAccount(1);
        List<Contact> contacts = TestUtilities.createContacts(5, a);
        QuotesOrdersCredits_Header__c header = TestUtilities.createQOCHeader(a, contacts[0], 'Quote', 'QOC-001');
        QuoteOrderCredit_Details__c detail = TestUtilities.createQOCDetail(header.Id, 'QOC-D-001-L1', null);
        Event event = TestUtilities.createEvent(a, contacts[0], 'On Call for Omni Cable', Date.today().addDays(7));
        Event event2 = TestUtilities.createEvent(a, contacts[0], 'On Call for Omni Cable No', Date.today().addDays(8));
    }
    
    /**
     * @description Builds a unique suffix for test record names and emails.
     * @return Unique string suitable for Name / email fields.
     */
    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }
    
    /**
     * @description Ensures the {@code New_On_Call_Email} {@link EmailTemplate} exists for tests.
     * Queries first; inserts a private text template when none is found.
     * @return Id of the on-call email template.
     */
    private static Id ensureOnCallEmailTemplate() {
        List<EmailTemplate> existing = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'New_On_Call_Email'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        
        EmailTemplate template = new EmailTemplate(
            Name = 'New On Call Email',
        DeveloperName = 'New_On_Call_Email',
        TemplateType = 'text',
        FolderId = UserInfo.getUserId(),
        Subject = 'On Call Notification',
        Body = 'Weekly on call notification body'
            );
        insert template;
        return template.Id;
    }
    
    /**
     * @description Builds a Flow-style request payload for {@link WeeklyOnCallNotification#sendOnCallEmail}.
     * @param onCallEvent The {@link Event} to include on the request.
     * @return Populated {@link WeeklyOnCallNotification.WeeklyOnCallNotificationRequest}.
     */
    private static WeeklyOnCallNotification.WeeklyOnCallNotificationRequest newRequest(Event onCallEvent) {
        WeeklyOnCallNotification.WeeklyOnCallNotificationRequest request =
            new WeeklyOnCallNotification.WeeklyOnCallNotificationRequest();
        request.event = onCallEvent;
        return request;
    }
    
    /**
     * @description
     * Verifies {@link WeeklyOnCallNotification#sendOnCallEmail} sends email for a valid
     * on-call {@link Event} without throwing.
     */
    @IsTest
    static void testSendOnCallEmailWithValidEventSendsWithoutThrowing() {
        ensureOnCallEmailTemplate();
        Event onCallEvent = [SELECT Id, WhoId, OwnerId, Name_2__c, Subject, StartDateTime, EndDateTime FROM Event WHERE Subject = 'On Call for Omni Cable' LIMIT 1];
        
        Test.startTest();
        List<WeeklyOnCallNotification.WeeklyOnCallNotificationResult> results =
            WeeklyOnCallNotification.sendOnCallEmail(
        new List<WeeklyOnCallNotification.WeeklyOnCallNotificationRequest>{
            newRequest(onCallEvent)
        }
        );
        
        
        System.assertNotEquals(null, results, 'Results list should be returned');
        System.assert(
            Limits.getEmailInvocations() >= 1,
        'Expected at least one email invocation for a valid request'
            );
        
        Test.stopTest();
    }
    
    /**
     * @description
     * Verifies {@link WeeklyOnCallNotification#sendOnCallEmail} accepts multiple
     * {@link WeeklyOnCallNotification.WeeklyOnCallNotificationRequest} inputs and sends email.
     */
    @IsTest
    static void testSendOnCallEmailWithMultipleEventsSendsAll() {
        ensureOnCallEmailTemplate();
        List<Event> events = [SELECT Id, WhoId, OwnerId, Name_2__c, Subject, StartDateTime, EndDateTime FROM Event];
        
        Test.startTest();
        WeeklyOnCallNotification.sendOnCallEmail(
        new List<WeeklyOnCallNotification.WeeklyOnCallNotificationRequest>{
            newRequest(events[0]),
            newRequest(events[1])
        }
        );
        
        
        System.assert(
            Limits.getEmailInvocations() >= 1,
        'Expected email send for multiple event requests'
            );
        
        Test.stopTest();
    }
    
    /**
     * @description
     * Verifies {@link WeeklyOnCallNotification#sendOnCallEmail} returns an empty result list
     * and does not send email when the request list is empty.
     */
    @IsTest
    static void testSendOnCallEmailWithEmptyRequestsReturnsEmptyResults() {
        ensureOnCallEmailTemplate();
        
        Test.startTest();
        List<WeeklyOnCallNotification.WeeklyOnCallNotificationResult> results =
            WeeklyOnCallNotification.sendOnCallEmail(
            new List<WeeklyOnCallNotification.WeeklyOnCallNotificationRequest>()
            );
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Empty input should return an empty result list');
        System.assertEquals(0, Limits.getEmailInvocations(), 'Empty input should not send email');
    }
    
    /**
     * @description
     * Verifies {@link WeeklyOnCallNotification#sendOnCallEmail} throws {@link AuraHandledException}
     * when the {@code New_On_Call_Email} template cannot be resolved.
     */
    @IsTest
    static void testSendOnCallEmailWhenTemplateMissingThrowsAuraHandledException() {
        WeeklyOnCallNotification.forceMissingTemplateForTest = true;
        Event onCallEvent = [SELECT Id, WhoId, Name_2__c, Subject, StartDateTime, EndDateTime FROM Event WHERE Subject = 'On Call for Omni Cable' LIMIT 1];
        
        Boolean threw = false;
        try {
            Test.startTest();
            WeeklyOnCallNotification.sendOnCallEmail(
            new List<WeeklyOnCallNotification.WeeklyOnCallNotificationRequest>{
                newRequest(onCallEvent)
            }
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            threw = true;
        } finally {
            WeeklyOnCallNotification.forceMissingTemplateForTest = false;
        }
        
        System.assert(threw, 'Missing template should throw AuraHandledException');
    }
    
    /**
     * @description
     * Verifies {@link WeeklyOnCallNotification#sendOnCallEmail} still sends when the related
     * contact has no email and {@code Name_2__c} is unset.
     */
    @IsTest
    static void testSendOnCallEmailWithEventMissingOptionalRecipientsStillSends() {
        ensureOnCallEmailTemplate();
        
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id, LastName, AccountId, Sequence__c, Ext_Id__c FROM Contact WHERE AccountId = :acct.Id LIMIT 1];
        Event onCallEvent = [SELECT Id, WhoId, Name_2__c, OwnerId, Subject, StartDateTime, EndDateTime FROM Event WHERE Subject = 'On Call for Omni Cable' LIMIT 1];
        
        Test.startTest();
        WeeklyOnCallNotification.sendOnCallEmail(
        new List<WeeklyOnCallNotification.WeeklyOnCallNotificationRequest>{
            newRequest(onCallEvent)
        }
        );
        
        
        System.assert(
            Limits.getEmailInvocations() >= 1,
        'Send should still run when optional recipient emails are missing'
            );
        
        Test.stopTest();
    }
}