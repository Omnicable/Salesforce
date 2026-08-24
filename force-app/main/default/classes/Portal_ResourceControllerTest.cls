/**
 * @description       : portal test methods
 * @author            : chrisw@launchdm.com
 * @group             : LaunchDM
 * @last modified on  : 01-12-2023
 * @last modified by  : chrisw@launchdm.com
 **/

@isTest
public class Portal_ResourceControllerTest {
    @testSetup
    public static void setup() {
        Account account = Portal_ResourceControllerTest.createAccount();
        Contact contact = Portal_ResourceControllerTest.createContact(account, '1', 'contact1@omnicable.com');
        Contact otherContact = Portal_ResourceControllerTest.createContact(account, '2', 'contact2@omnicable.com');
        User user = Portal_ResourceControllerTest.createUser(contact);
        List<Inventory_Item__c> inventory = createInventory(account, 5);
        List<Job_Area__c> areas = Portal_ResourceControllerTest.createJobAreas(account, user, 5);
        List<Delivery_Address__c> address = Portal_ResourceControllerTest.createDeliveryAddresses(Contact, 5);
        Part_Numbers__c partNumber = Portal_ResourceControllerTest.createPartNumber(account);
        List<Alternative_Part_Number__c> altParts = Portal_ResourceControllerTest.createAltParts(account, 5, partNumber);
        List<QuotesOrdersCredits_Header__c> myReleases = Portal_ResourceControllerTest.createReleases(
            account,
            contact,
            'Release',
            'Blanket',
            5
        );
        List<QuotesOrdersCredits_Header__c> otherReleases = Portal_ResourceControllerTest.createReleases(
            account,
            otherContact,
            'Release',
            'Blanket',
            5
        );
        List<QuotesOrdersCredits_Header__c> masterOrders = Portal_ResourceControllerTest.createReleases(
            account,
            otherContact,
            'Order',
            'Blanket',
            5
        );
        List<OCC_ContactSlider__c> sliders = Portal_ResourceControllerTest.createSliders(contact, 5);
    }

    public static List<OCC_ContactSlider__c> createSliders(Contact contact, Integer count) {
        List<OCC_ContactSlider__c> contactSliders = new List<OCC_ContactSlider__c>();
        for (Integer i = 0; i < count; i++) {
            OCC_ContactSlider__c slider = new OCC_ContactSlider__c();
            slider.Name = 'Slider';
            slider.URL__c = 'www.omnicable.com';
            slider.LinkUrl__c = 'www.omnicable.com';
            slider.Contact__c = contact.Id;
            slider.Index__c = i;
            contactSliders.add(slider);
        }
        insert contactSliders;
        return contactSliders;
    }

    public static Account createAccount() {
        Account account = new Account(
            Name = 'Test Account',
            Portal_PO_Selector__c = '979602',
            Portal_POs__c = '193108-1137-22000',
            Account_Number__c = '123456'
        );
        insert account;
        return account;
    }

    public static Contact createContact(Account account, String sequence, String email) {
        String newId = account.Account_Number__c + ':' + sequence;
        Contact contact = new Contact(
            Contact_Title__c = 'Accounting',
            Email = email,
            AccountId = account.Id,
            Sequence__c = Decimal.valueOf(sequence),
            FirstName = 'Test',
            LastName = 'Test',
            Ext_Id__c = newId
        );
        insert contact;
        return contact;
    }

    public static List<Inventory_Item__c> createInventory(Account account, Integer count) {
        List<Inventory_Item__c> records = new List<Inventory_Item__c>();
        for (Integer i = 0; i < count; i++) {
            Inventory_Item__c record = new Inventory_Item__c(
                Name = 'Iventory' + i,
                Customer_PO__c = '',
                Available__c = 20,
                On_Hand__c = 20,
                Account__c = account.Id,
                Weight_Per_Foot__c = i
            );
            records.add(record);
        }
        insert records;
        return records;
    }

    public static List<Job_Area__c> createJobAreas(Account account, User user, Integer count) {
        List<Job_Area__c> areas = new List<Job_Area__c>();

        for (Integer i = 0; i < count; i++) {
            Job_Area__c area = new Job_Area__c(Name = 'Area ' + i, Account__c = account.Id, Area_Account_Manager__c = user.Id);
            areas.add(area);
        }
        insert areas;
        return areas;
    }

    public static List<Delivery_Address__c> createDeliveryAddresses(Contact contact, Integer count) {
        List<Delivery_Address__c> addresses = new List<Delivery_Address__c>();
        for (Integer i = 0; i < count; i++) {
            Delivery_Address__c address = new Delivery_Address__c(
                Name = 'Address' + i,
                Street_Address__c = String.valueOf(i),
                City__c = 'Reading',
                State__c = 'PA',
                Zip_Code__c = '12345',
                Contact__c = contact.Id
            );
            addresses.add(address);
        }
        insert addresses;
        return addresses;
    }

    public static Part_Numbers__c createPartNumber(Account account) {
        Spec_Sheet__c sheet = new Spec_Sheet__c(Name = 'Spec Sheet');
        insert sheet;

        Part_Numbers__c partNumber = new Part_Numbers__c(
            Name = 'Part Number',
            Item_Description_OPUS__c = 'Description',
            Spec_Sheet__c = sheet.Id
        );
        insert partNumber;
        return partNumber;
    }

    public static List<Alternative_Part_Number__c> createAltParts(Account account, Integer count, Part_Numbers__c partNumber) {
        List<Alternative_Part_Number__c> parts = new List<Alternative_Part_Number__c>();
        for (Integer i = 0; i < count; i++) {
            Alternative_Part_Number__c part = new Alternative_Part_Number__c(
                Name = 'Part' + i,
                Closed__c = false,
                Part_Numbers__c = partNumber.Id,
                Account__c = account.Id
            );
            parts.add(part);
        }
        insert parts;
        return parts;
    }

    public static List<QuotesOrdersCredits_Header__c> createReleases(
        Account account,
        Contact contact,
        String type,
        String subType,
        Integer count
    ) {
        List<QuotesOrdersCredits_Header__c> headers = new List<QuotesOrdersCredits_Header__c>();

        for (Integer i = 0; i < count; i++) {
            QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(
                RewardOverride__c = 1,
                Customer__c = account.Id,
                Buyer__c = contact.Id,
                Date__c = system.today(),
                Type__c = type,
                Sub_Type__c = subType,
                Name = 'Header ' + i
            );
            headers.add(header);
        }
        insert headers;

        List<QuoteOrderCredit_Details__c> details = new List<QuoteOrderCredit_Details__c>();
        for (QuotesOrdersCredits_Header__c header : headers) {
            QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(
                Order_Header__c = header.Id,
                Qty_Ordered__c = 2,
                Dollars__c = 300
            );
            details.add(detail);
        }

        insert details;
        return headers;
    }

    public static User createUser(Contact contact) {
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Portal Login%' LIMIT 1];
        UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
        Profile profile1 = [SELECT Id FROM Profile WHERE name = 'System Administrator'];

        User user = new User(
            Username = System.now().millisecond() + '2test12345@test.com',
            ContactId = contact.Id,
            ProfileId = portalProfile.Id,
            Alias = 'test123',
            Email = 'test12345@omnicable.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'McTesty',
            CommunityNickname = 'test12345',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        );
        Database.insert(user);
        return user;
    }

    @isTest
    public static void getReleasesTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();

        System.runAs(user) {
            Map<String, Portal_ResourceController.QOCResults> getReleaseResultsMap = Portal_ResourceController.getReleases('', 0);
            Map<String, Portal_ResourceController.QOCResults> searchReleaseResultsMap = Portal_ResourceController.getReleases(
                'Gibberish',
                0
            );

            Portal_ResourceController.QOCResults getReleaseResults = getReleaseResultsMap.get('myRecords');
            Portal_ResourceController.QOCResults searchReleaseResults = searchReleaseResultsMap.get('myRecords');

            System.assert(getReleaseResults.recordCount == 5);
            System.assert(searchReleaseResults.recordCount == 0);
        }

        test.stopTest();
    }

    @isTest
    public static void getHomePageDataTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();

        System.runAs(user) {
            Map<String, Object> results = Portal_ResourceController.getHomePageData();
            Portal_ResourceController.QOCResults releases = (Portal_ResourceController.QOCResults) results.get('releases');
            List<OCC_ContactSlider__c> sliderImages = (List<OCC_ContactSlider__c>) results.get('carouselImages');

            System.assert(releases.recordCount == 5);
            System.assert(sliderImages.size() == 5);
        }

        test.stopTest();
    }

    @isTest
    public static void getOrdersTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();

        System.runAs(user) {
            Map<String, Portal_ResourceController.QOCResults> getReleaseResultsMap = Portal_ResourceController.getOrders('', 0);
            Map<String, Portal_ResourceController.QOCResults> searchReleaseResultsMap = Portal_ResourceController.getOrders('Gibberish', 0);

            Portal_ResourceController.QOCResults getReleaseResults = getReleaseResultsMap.get('masterOrders');
            Portal_ResourceController.QOCResults searchReleaseResults = searchReleaseResultsMap.get('masterOrders');

            System.assert(getReleaseResults.recordCount == 5);
            System.assert(searchReleaseResults.recordCount == 0);
        }

        test.stopTest();
    }

    @isTest
    public static void toggleReleaseReceiveTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();
        System.runAs(user) {
            QuoteOrderCredit_Details__c detail = [SELECT Id FROM QuoteOrderCredit_Details__c LIMIT 1];
            Boolean received = Portal_ResourceController.toggleReleaseReceive(detail.Id, true);
            System.assert(received);
        }
        test.stopTest();
    }

    @isTest
    public static void getRequestReleaseDataTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();
        System.runAs(user) {
            Map<String, Object> results = Portal_ResourceController.getRequestReleaseData();

            List<Job_Area__c> areas = (List<Job_Area__c>) results.get('jobAreas');
            // List<String> rmfPOValues = (List<String>) results.get('rmfPOValues');
            Contact contact = (Contact) results.get('contact');
            List<Delivery_Address__c> addresses = (List<Delivery_Address__c>) results.get('deliveryAddresses');
            List<Alternative_Part_Number__c> altParts = (List<Alternative_Part_Number__c>) results.get('defaultPartList');

            System.assert(areas.size() == 5);
            // System.assert(rmfPOValues.size() == 0);
            System.assert(addresses.size() == 5);
            System.assert(altParts.size() == 5);
            System.assert(contact != null);
        }
        test.stopTest();
    }

    @isTest
    public static void getDefaultFilteredPartsTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();
        System.runAs(user) {
            List<Alternative_Part_Number__c> parts = Portal_ResourceController.getDefaultFilteredParts();
            System.assert(parts.size() == 5);
        }
        test.stopTest();
    }

    @isTest
    public static void searchAlternatePartsTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();
        System.runAs(user) {
            List<Alternative_Part_Number__c> parts = Portal_ResourceController.searchAlternateParts('Gibberish');
            System.assert(parts.size() == 0);
        }
        test.stopTest();
    }

    @isTest
    public static void getDeliveryAddressesTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :user.ContactId];
        test.startTest();
        System.runAs(user) {
            List<sObject> res = Portal_ResourceController.getDeliveryAddresses(contact.AccountId);
            System.assert(res.size() == 5);
        }
        test.stopTest();
    }

    @isTest
    public static void sendRFQTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :user.ContactId];
        test.startTest();
        System.runAs(user) {
            Map<String, Object> request = new Map<String, Object>();
            List<Map<String, Object>> releaseItems = new List<Map<String, Object>>();
            Map<String, Object> releaseItem = new Map<String, Object>();
            Map<Object, Object> deliveryAddress = new Map<Object, Object>();
            deliveryAddress.put('Street__c', '');
            deliveryAddress.put('City__c', '');
            deliveryAddress.put('State__c', '');
            deliveryAddress.put('Zip_Code__c', '');

            releaseItem.put('qty', 'qty');
            releaseItem.put('lengthValue', 'lengthValue');
            releaseItem.put('cableNumber', 'cableNumber');
            releaseItem.put('description', 'description');
            releaseItem.put('itemNumber', 'itemNumber');
            releaseItem.put('info', 'info');
            releaseItem.put('area', 'area');
            releaseItem.put('Paralleling', 'Paralleling');
            releaseItem.put('pullingHeads', 'pullingHeads');
            releaseItems.add(releaseItem);

            request.put('specialInstructions', 'specialInstructions');
            request.put('rmfPO', 'rmfPO');
            request.put('jobReference', 'jobReference');
            request.put('deliveryAddress', deliveryAddress);
            request.put('deliveryContact', 'deliveryContact');
            request.put('deliveryDate', 'deliveryDate');
            request.put('rawDeliveryDate', '2023-09-09');
            request.put('specialInstructions', 'specialInstructions');

            Map<String, Object> res = Portal_ResourceController.sendRFQ('Release', request, releaseItems, new List<String>());
            System.assert(res != null);
        }
        test.stopTest();
    }

    @isTest
    public static void getAccountTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :user.ContactId];
        test.startTest();
        System.runAs(user) {
            Map<String, Object> res = Portal_ResourceController.getAccount();
            System.assert(res != null);
        }
        test.stopTest();
    }

    @isTest
    public static void getAvailableInventoryTest() {
        User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
        test.startTest();
        System.runAs(user) {
            Portal_ResourceController.QOCResults res = Portal_ResourceController.getAvailableInventory('', 0, 5);
            Portal_ResourceController.QOCResults searchRes = Portal_ResourceController.getAvailableInventory('Gibberish', 0, 5);
            System.assert(res.records.size() == 5);
            System.assert(searchRes.records.size() == 0);
        }
        test.stopTest();
    }

    // @isTest
    // public static void createDeliveryAddressTest() {
    //     User user = [SELECT Id, ContactId FROM User WHERE LastName = 'McTesty'];
    //     Contact contact = [
    //         SELECT
    //             Region__c,
    //             Email,
    //             Name,
    //             OCC_Hide_Account_Access_Panel__c,
    //             Phone,
    //             FirstName,
    //             LastName,
    //             Buyer__c,
    //             PhotoUrl,
    //             OCC_Photo__c,
    //             OCC_ViewAll__c,
    //             OCC_ViewApproved__c,
    //             OCC_Rewards__c,
    //             Birthdate,
    //             OCC_RewardsValue__c,
    //             AccountId
    //         FROM Contact
    //         WHERE Id = :user.ContactId
    //         LIMIT 1
    //     ];

    //     test.startTest();
    //     System.runAs(user) {
    //         Boolean res = Portal_ResourceController.createDeliveryAddress('NEW_ADDRESS', contact.AccountId);
    //         System.assert(res);
    //     }
    //     test.stopTest();
    // }
}