/**
 * @author Chris Williams <chrisw@launchdm.com>
 * @group Test Utilities
 * @since 2022-09-06
 * @description
 * Shared test-data helpers for OmniCable unit tests.
 *
 * {@link #setup} seeds a baseline Account, Contacts, QOC header/detail, and Event.
 * Individual factory methods can also be called directly from other test classes.
 *
 * @see QOCSyncTest
 * @see WeeklyOnCallNotificationTest
 */
@IsTest

@SuppressWarnings('PMD.ExcessiveParameterList')
public class TestUtilities {

    /**
     * @description
     * Seeds common test records used across dependent test classes:
     * one Account, five Contacts, one QOC header/detail, and one Event.
     */
    @TestSetup
    public static void setup() {
        Account a = createAccount(1);
        List<Contact> contacts = createContacts(5, a);
        QuotesOrdersCredits_Header__c header = createQOCHeader(a, contacts[0], 'Quote', 'QOC-001');
        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-001-001', null);
        Event event = createEvent(a, contacts[0], 'On Call for Omni Cable', Date.today().addDays(7));
    }

    /**
     * @description
     * Creates and inserts a Potential Distributor {@link Account} suitable for sync and portal tests.
     *
     * @param count Reserved for future multi-account creation; currently unused (one Account is created).
     * @return Inserted {@link Account}.
     */
    public static Account createAccount(Integer count) {
        Id stExam = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Potential Distributor').getRecordTypeId();
        Account account = new Account(
            Name = 'Test Account',
            Account_Number__c = '123456',
            RecordtypeId = stExam,
            Buying_Group__c = 'Test Buying Group',
            Region__c = '6',
            Company_Name__c = 'Test Company',
            Active__c = 'A',
            Price_Book_Email_Day__c = Date.today().day()
        );
        insert account;
        return account;
    }

    /**
     * @description
     * Creates and inserts Contacts for the given Account, with unique {@code Ext_Id__c} values
     * ({@code Account_Number__c:sequence}) and fields that satisfy contact validations.
     *
     * @param size Number of {@link Contact} records to create.
     * @param a Parent {@link Account} for {@code AccountId} and Ext Id generation.
     * @return Inserted list of {@link Contact} records.
     */
    public static List<Contact> createContacts(Integer size, Account a) {
        List<Contact> contacts = new List<Contact>();

        for (Integer i = 0; i < size; i++) {
            String newId = a.Account_Number__c + ':' + i;
            Contact contact = new Contact(
                LastName = 'My Contact',
                Contact_Title__c = 'Accounting',
                Email = 'test@omnicable.com',
                AccountId = a.Id,
                Sequence__c = i,
                FirstName = 'Test',
                Ext_Id__c = newId,
                DSP_Purchaser__c = true
            );
            contacts.add(contact);
        }

        insert contacts;
        return contacts;
    }

    /**
     * @description
     * Creates and inserts a {@link QuotesOrdersCredits_Header__c} for sync / QOC tests.
     *
     * @param customer Parent {@link Account} for {@code Customer__c}.
     * @param buyer Optional buyer {@link Contact} for {@code Buyer__c}; may be {@code null}.
     * @param typeValue Header {@code Type__c} value (for example {@code Quote} or {@code Order}).
     * @param orderNumber Value for {@code Name} and {@code Order_Number__c}.
     * @return Inserted {@link QuotesOrdersCredits_Header__c}.
     */
    public static QuotesOrdersCredits_Header__c createQOCHeader(
        Account customer,
        Contact buyer,
        String typeValue,
        String orderNumber
    ) {
        QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(
            Name = orderNumber,
            Customer__c = customer.Id,
            Buyer__c = buyer != null ? buyer.Id : null,
            Order_Number__c = orderNumber,
            Type__c = typeValue,
            Date__c = Date.today(),
            Status__c = typeValue == 'Order' ? 'Open' : null,
            Notes__c = 'Test Note'
        );
        insert header;
        return header;
    }

    /**
     * @description
     * Creates and inserts a {@link QuoteOrderCredit_Details__c} linked to a QOC header.
     *
     * @param headerId Parent {@link QuotesOrdersCredits_Header__c} Id for {@code Order_Header__c}.
     * @param extId Unique external Id for {@code Ext_Id__c}.
     * @param partNumberId Optional {@link Part_Numbers__c} Id for {@code Item_Number__c}; may be {@code null}.
     * @return Inserted {@link QuoteOrderCredit_Details__c}.
     */
    public static QuoteOrderCredit_Details__c createQOCDetail(
        Id headerId,
        String extId,
        Id partNumberId
    ) {
        QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(
            Order_Header__c = headerId,
            Ext_Id__c = extId,
            Item_Number__c = partNumberId,
            Qty_Ordered__c = 1,
            Dollars__c = 100
        );
        insert detail;
        return detail;
    }

    /**
     * @description
     * Builds an unsaved on-call {@link Event} related to the given Contact.
     * Caller is responsible for insert when persistence is required.
     *
     * @param a Related {@link Account} (reserved for future use / WhatId linking).
     * @param contact Contact used for {@code WhoId}.
     * @param subject Event subject.
     * @param startDate Start date/time string accepted by {@link Datetime#parse}.
     * @return Unsaved {@link Event}.
     */
    public static Event createEvent(Account a, Contact contact, String subject, DateTime startDateTime) {
        Event event = new Event(
            Subject = subject,
            StartDateTime = startDateTime,
            EndDateTime = startDateTime.addHours(1),
            OwnerId = UserInfo.getUserId(),
            WhoId = contact.Id,
            Name_2__c = UserInfo.getUserId()
        );

        insert event;
        return event;
    }
}