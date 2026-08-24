@IsTest
private class Vendor_SetDetailFieldsTest {
    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static Id quoteDetailStandardRecordTypeId() {
        return Schema.SObjectType.QuoteOrderCredit_Details__c.getRecordTypeInfosByDeveloperName()
            .get('Standard')
            .getRecordTypeId();
    }

    private static QuoteOrderCredit_Details__c newDetail() {
        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        QuotesOrdersCredits_Header__c header = new QuotesOrdersCredits_Header__c(
            Name = 'Hdr-' + uniqueSuffix(),
            Customer__c = acct.Id
        );
        insert header;

        return new QuoteOrderCredit_Details__c(
            Name = 'Det-' + uniqueSuffix(),
            Order_Header__c = header.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId()
        );
    }

    @IsTest
    static void insertVendor_whenDetailVendorNameNull_copiesVendorFields() {
        QuoteOrderCredit_Details__c detail = newDetail();
        insert detail;

        Vendor__c vendor = new Vendor__c(
            Name = 'Acme Vendor',
            Vendor_Number__c = 'VN-100',
            Vendor_Item__c = 'ITEM-1',
            QuoteOrderCredit_Detail__c = detail.Id
        );

        Test.startTest();
        insert vendor;
        Test.stopTest();

        detail = [
            SELECT Vendor_Name__c, Vendor_Number__c, Vendor_Item__c
            FROM QuoteOrderCredit_Details__c
            WHERE Id = :detail.Id
        ];
        System.assertEquals('Acme Vendor', detail.Vendor_Name__c);
        System.assertEquals('VN-100', detail.Vendor_Number__c);
        System.assertEquals('ITEM-1', detail.Vendor_Item__c);
    }

    @IsTest
    static void insertVendor_whenDetailVendorNamePopulated_overwritesVendorFields() {
        QuoteOrderCredit_Details__c detail = newDetail();
        detail.Vendor_Name__c = 'Existing Vendor';
        detail.Vendor_Number__c = 'EXISTING';
        detail.Vendor_Item__c = 'EXISTING-ITEM';
        insert detail;

        Vendor__c vendor = new Vendor__c(
            Name = 'New Vendor',
            Vendor_Number__c = 'VN-200',
            Vendor_Item__c = 'ITEM-2',
            QuoteOrderCredit_Detail__c = detail.Id
        );

        Test.startTest();
        insert vendor;
        Test.stopTest();

        detail = [
            SELECT Vendor_Name__c, Vendor_Number__c, Vendor_Item__c
            FROM QuoteOrderCredit_Details__c
            WHERE Id = :detail.Id
        ];
        System.assertEquals('New Vendor', detail.Vendor_Name__c);
        System.assertEquals('VN-200', detail.Vendor_Number__c);
        System.assertEquals('ITEM-2', detail.Vendor_Item__c);
    }

    @IsTest
    static void insertVendor_bulkSameDetail_usesFirstVendorOnly() {
        QuoteOrderCredit_Details__c detail = newDetail();
        insert detail;

        Vendor__c firstVendor = new Vendor__c(
            Name = 'First Vendor',
            Vendor_Number__c = 'VN-FIRST',
            Vendor_Item__c = 'ITEM-FIRST',
            QuoteOrderCredit_Detail__c = detail.Id
        );
        Vendor__c secondVendor = new Vendor__c(
            Name = 'Second Vendor',
            Vendor_Number__c = 'VN-SECOND',
            Vendor_Item__c = 'ITEM-SECOND',
            QuoteOrderCredit_Detail__c = detail.Id
        );

        Test.startTest();
        insert new List<Vendor__c>{ firstVendor, secondVendor };
        Test.stopTest();

        detail = [
            SELECT Vendor_Name__c, Vendor_Number__c, Vendor_Item__c
            FROM QuoteOrderCredit_Details__c
            WHERE Id = :detail.Id
        ];
        System.assertEquals('First Vendor', detail.Vendor_Name__c);
        System.assertEquals('VN-FIRST', detail.Vendor_Number__c);
        System.assertEquals('ITEM-FIRST', detail.Vendor_Item__c);
    }

    @IsTest
    static void insertVendor_withoutDetailLink_insertsVendorOnly() {
        Vendor__c vendor = new Vendor__c(
            Name = 'Standalone Vendor',
            Vendor_Number__c = 'VN-300',
            Vendor_Item__c = 'ITEM-3'
        );

        Test.startTest();
        insert vendor;
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Vendor__c WHERE Id = :vendor.Id]);
    }
}