/**
 * @description       : Server methods for OCC Portal
 * @author            : chrisw@launchdm.com
 * @group             : Portal
 * @last modified on  : 01-12-2023
 * @last modified by  : chrisw@launchdm.com
 **/
public class Portal_ResourceController {
    public class QOCTypeData {
        @AuraEnabled
        public QuotesOrdersCredits_Header__c header;
        @AuraEnabled
        public List<QuoteOrderCredit_Details__c> details = new List<QuoteOrderCredit_Details__c>();
        @AuraEnabled
        public List<QOCAttachment> attachments = new List<QOCAttachment>();
        @AuraEnabled
        public List<ContentDocumentLink> contentDocs = new List<ContentDocumentLink>();
    }

    public class QOCAttachment {
        @AuraEnabled
        public String image;
        @AuraEnabled
        public String url;
        @AuraEnabled
        public String title;
    }

    public class QOCResults {
        @AuraEnabled
        public List<sObject> records = new List<sObject>();
        @AuraEnabled
        public Integer recordCount = 0;
    }

    /**
     * @description get image sliders for home page
     * @author chrisw@launchdm.com | 11-30-2022
     * @return List<OCC_ContactSlider__c>
     * @status Completed
     **/
    @AuraEnabled
    public static List<OCC_ContactSlider__c> getSliderImages() {
        Contact c = Portal_ResourceController.getContact();
        List<OCC_ContactSlider__c> contactSlider = [
            SELECT Name, URL__c, LinkUrl__c, Index__c
            FROM OCC_ContactSlider__c
            WHERE Contact__c = :c.Id
            ORDER BY OCC_ContactSlider__c.Index__c
        ];

        if (contactSlider.size() == 0) {
            contactSlider = [
                SELECT Name, URL__c, LinkUrl__c, Index__c
                FROM OCC_ContactSlider__c
                WHERE Contact__c = null
                ORDER BY OCC_ContactSlider__c.Index__c
            ];
        }

        return contactSlider;
    }

    /**
     * @description get recent releases for cuontact's account
     * @author chrisw@launchdm.com | 11-30-2022
     * @return QOCResults
     * @status Completed
     **/
    @AuraEnabled
    public static QOCResults getRecentReleases() {
        QOCResults results = new QOCResults();

        Contact contact = Portal_ResourceController.getContact();
        String contactId = contact.Id;
        String fullFileURL = URL.getSalesforceBaseUrl().toExternalForm();

        results.recordCount = [
            SELECT COUNT()
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Buyer__c = :contact.Id
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND (Type__c = 'Release'
                OR Type__c = 'RFQ'
                OR Sub_Type__c = 'Change Order')
        ];

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
                // Delivery_Address__r.Id,
                // Delivery_Address__r.City__c,
                // Delivery_Address__r.Flatbed_Requirements__c,
                // Delivery_Address__r.Lift_Gate__c,
                // Delivery_Address__r.Other_Instructions__c,
                // Delivery_Address__r.Phone_Number__c,
                // Delivery_Address__r.Require_24hr_Notice__c,

            FROM QuotesOrdersCredits_Header__c
            WHERE
                Buyer__c = :contact.Id
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND (Type__c = 'Release'
                OR Type__c = 'RFQ'
                OR Sub_Type__c = 'Change Order')
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 5
        ];

        return results;
    }

    /**
     * @description get home page data, recent releases and image sliders
     * @author chrisw@launchdm.com | 11-30-2022
     * @return Map<String, Object>
     * @status Completed
     **/
    @AuraEnabled
    public static Map<String, Object> getHomePageData() {
        Map<String, Object> results = new Map<String, Object>();
        QOCResults releases = Portal_ResourceController.getRecentReleases();
        List<OCC_ContactSlider__c> sliderImages = Portal_ResourceController.getSliderImages();
        results.put('releases', releases);
        results.put('carouselImages', sliderImages);
        return results;
    }

    /**
     * @description get current contacts information
     * @author chrisw@launchdm.com | 11-30-2022
     * @return Contact
     * @status Completed
     **/
    @AuraEnabled
    public static Contact getContact() {
        User u = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        Contact contact = [
            SELECT
                Region__c,
                Email,
                Name,
                OCC_Hide_Account_Access_Panel__c,
                Phone,
                FirstName,
                LastName,
                Buyer__c,
                PhotoUrl,
                OCC_Photo__c,
                OCC_ViewAll__c,
                OCC_ViewApproved__c,
                OCC_Rewards__c,
                Birthdate,
                OCC_RewardsValue__c,
                AccountId
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];
        return contact;
    }

    /**
     * @description get contact's releases paginated
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String searchTerm
     * @param Integer offset
     * @return Map<String, QOCResults>
     **/
    @AuraEnabled
    public static Map<String, QOCResults> getReleases(String searchTerm, Integer offset) {
        Map<String, QOCResults> results = new Map<String, QOCResults>();
        results.put(
            'myRecords',
            searchTerm == null ||
                searchTerm == ''
                ? Portal_ResourceController.getMyReleases(offset)
                : Portal_ResourceController.searchMyReleases(searchTerm, offset)
        );
        results.put(
            'otherRecords',
            searchTerm == null ||
                searchTerm == ''
                ? Portal_ResourceController.getOtherReleases(offset)
                : Portal_ResourceController.searchOtherReleases(searchTerm, offset)
        );
        return results;
    }

    /**
     * @description search all account releases that don't belong to current contact
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String searchTerm
     * @param Integer offset
     * @return QOCResults
     * @status Completed
     **/
    @AuraEnabled
    public static QOCResults searchOtherReleases(String searchTerm, Integer offset) {
        QOCResults results = new QOCResults();
        Contact contact = Portal_ResourceController.getContact();
        User user = [SELECT Id, Name, Profile.name FROM User WHERE Id = :UserInfo.getUserId()];
        Boolean invoiceAccess = user.Profile.name == 'E.D. Portal User' ? true : false;
        String contenFilter = invoiceAccess ? '' : '%Invoice%';

        List<String> headerIds = new List<String>();
        searchTerm = '*' + searchTerm + '*';
        List<List<SObject>> foundResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING
                QuotesOrdersCredits_Header__c(
                    Id
                    WHERE
                        Customer__c = :contact.AccountId
                        AND Buyer__c != :contact.Id
                        AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                        AND (Type__c = 'Release'
                        OR Type__c = 'RFQ'
                        OR Sub_Type__c = 'Change Order')),
                QuoteOrderCredit_Details__c(
                    Order_Header__c
                    WHERE
                        Order_Header__r.Customer__c = :contact.AccountId
                        AND Order_Header__r.Buyer__c != :contact.Id
                        AND Order_Header__r.Status__c != 'Cancelled'
                        AND Line_Status__c != 'Cancelled'
                        AND (Order_Header__r.Type__c = 'Release'
                        OR Order_Header__r.Type__c = 'RFQ'
                        OR Order_Header__r.Sub_Type__c = 'Change Order'))
        ];

        for (QuotesOrdersCredits_Header__c obj : (List<QuotesOrdersCredits_Header__c>) foundResults[0]) {
            headerIds.add(obj.Id);
        }

        for (QuoteOrderCredit_Details__c obj : (List<QuoteOrderCredit_Details__c>) foundResults[1]) {
            headerIds.add(obj.Order_Header__c);
        }

        results.recordCount = [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id IN :headerIds];

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT Id, ContentDocument.Title, ContentDocumentId
                    FROM ContentDocumentLinks
                    WHERE NOT ContentDocument.Title LIKE :contenFilter
                ),
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id IN :headerIds
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 10
            OFFSET :offset
        ];

        return results;
    }

    /**
     * @description search contact's releases
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String searchTerm
     * @param Integer offset
     * @return QOCResults
     * @status Completed
     **/
    @AuraEnabled
    public static QOCResults searchMyReleases(String searchTerm, Integer offset) {
        QOCResults results = new QOCResults();
        Contact contact = Portal_ResourceController.getContact();
        User user = [SELECT Id, Name, Profile.name FROM User WHERE Id = :UserInfo.getUserId()];
        Boolean invoiceAccess = user.Profile.name == 'E.D. Portal User' ? true : false;
        String contenFilter = invoiceAccess ? '' : '%Invoice%';

        List<String> headerIds = new List<String>();
        searchTerm = '*' + searchTerm + '*';
        List<List<SObject>> foundResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING
                QuotesOrdersCredits_Header__c(
                    Id
                    WHERE
                        Buyer__c = :contact.Id
                        AND Status__c != 'Cancelled'
                        AND (Type__c = 'Release'
                        OR Type__c = 'RFQ'
                        OR Sub_Type__c = 'Change Order')),
                QuoteOrderCredit_Details__c(
                    Order_Header__c
                    WHERE
                        Order_Header__r.Buyer__c = :contact.Id
                        AND Order_Header__r.Status__c != 'Cancelled'
                        AND Line_Status__c != 'Cancelled'
                        AND (Order_Header__r.Type__c = 'Release'
                        OR Order_Header__r.Type__c = 'RFQ'
                        OR Order_Header__r.Sub_Type__c = 'Change Order'))
        ];

        for (QuotesOrdersCredits_Header__c obj : (List<QuotesOrdersCredits_Header__c>) foundResults[0]) {
            headerIds.add(obj.Id);
        }

        for (QuoteOrderCredit_Details__c obj : (List<QuoteOrderCredit_Details__c>) foundResults[1]) {
            headerIds.add(obj.Order_Header__c);
        }

        results.recordCount = [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id IN :headerIds];

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT Id, ContentDocument.Title, ContentDocumentId
                    FROM ContentDocumentLinks
                    WHERE NOT ContentDocument.Title LIKE :contenFilter
                ),
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id IN :headerIds
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 10
            OFFSET :offset
        ];

        return results;
    }

    /**
     * @description get contact's releases paginated
     * @author chrisw@launchdm.com | 11-30-2022
     * @param Integer offset
     * @return QOCResults
     **/
    @AuraEnabled(cacheable=true)
    public static QOCResults getMyReleases(Integer offset) {
        QOCResults results = new QOCResults();
        Contact contact = Portal_ResourceController.getContact();
        String accountId = contact.AccountId;

        results.recordCount = [
            SELECT COUNT()
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Buyer__c = :contact.Id
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND (Type__c = 'Release'
                OR Type__c = 'RFQ'
                OR Sub_Type__c = 'Change Order')
        ];

        User user = [SELECT Id, Name, Profile.name FROM User WHERE Id = :UserInfo.getUserId()];
        Boolean invoiceAccess = user.Profile.name == 'E.D. Portal User' ? true : false;
        String contenFilter = invoiceAccess ? '' : '%Invoice%';

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT Id, ContentDocument.Title, ContentDocumentId
                    FROM ContentDocumentLinks
                    WHERE NOT ContentDocument.Title LIKE :contenFilter
                ),
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Buyer__c = :contact.Id
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND (Type__c = 'Release'
                OR Type__c = 'RFQ'
                OR Sub_Type__c = 'Change Order')
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 10
            OFFSET :offset
        ];

        return results;
    }

    /**
     * @description get all account's releases
     * @author chrisw@launchdm.com | 11-30-2022
     * @param Integer offset
     * @return QOCResults
     * @status Completed
     **/
    @AuraEnabled(cacheable=true)
    public static QOCResults getOtherReleases(Integer offset) {
        QOCResults results = new QOCResults();
        Contact contact = Portal_ResourceController.getContact();
        User user = [SELECT Id, Name, Profile.name FROM User WHERE Id = :UserInfo.getUserId()];
        Boolean invoiceAccess = user.Profile.name == 'E.D. Portal User' ? true : false;
        String contenFilter = invoiceAccess ? '' : '%Invoice%';

        results.recordCount = [
            SELECT COUNT()
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Customer__c = :contact.AccountId
                AND Buyer__c != :contact.Id
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND (Type__c = 'Release'
                OR Type__c = 'RFQ'
                OR Sub_Type__c = 'Change Order')
        ];

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT Id, ContentDocument.Title, ContentDocumentId
                    FROM ContentDocumentLinks
                    WHERE NOT ContentDocument.Title LIKE :contenFilter
                ),
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Customer__c = :contact.AccountId
                AND Buyer__c != :contact.Id
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND (Type__c = 'Release'
                OR Type__c = 'RFQ'
                OR Sub_Type__c = 'Change Order')
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 10
            OFFSET :offset
        ];

        return results;
    }

    @AuraEnabled
    public static Map<String, QOCResults> getOrders(String searchTerm, Integer offset) {
        Map<String, QOCResults> results = new Map<String, QOCResults>();
        results.put(
            'masterOrders',
            searchTerm == null ||
                searchTerm == ''
                ? Portal_ResourceController.getMasterOrders(offset)
                : Portal_ResourceController.searchMasterOrders(searchTerm, offset)
        );
        return results;
    }

    @AuraEnabled
    public static QOCResults searchMasterOrders(String searchTerm, Integer offset) {
        QOCResults results = new QOCResults();
        Contact contact = Portal_ResourceController.getContact();

        List<String> headerIds = new List<String>();
        searchTerm = '*' + searchTerm + '*';
        List<List<SObject>> foundResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING
                QuotesOrdersCredits_Header__c(
                    Id
                    WHERE
                        Customer__c = :contact.AccountId
                        AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                        AND Type__c = 'Order'
                        AND Sub_Type__c = 'Blanket'),
                QuoteOrderCredit_Details__c(Order_Header__c)
        ];

        for (QuotesOrdersCredits_Header__c obj : (List<QuotesOrdersCredits_Header__c>) foundResults[0]) {
            headerIds.add(obj.Id);
        }

        for (QuoteOrderCredit_Details__c obj : (List<QuoteOrderCredit_Details__c>) foundResults[1]) {
            headerIds.add(obj.Order_Header__c);
        }

        results.recordCount = [
            SELECT COUNT()
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Customer__c = :contact.AccountId
                AND Id IN :headerIds
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND Type__c = 'Order'
                AND Sub_Type__c = 'Blanket'
        ];

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Customer__c = :contact.AccountId
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND Id IN :headerIds
                AND Type__c = 'Order'
                AND Sub_Type__c = 'Blanket'
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 10
            OFFSET :offset
        ];

        return results;
    }

    @AuraEnabled
    public static QOCResults getMasterOrders(Integer offset) {
        QOCResults results = new QOCResults();
        Contact contact = Portal_ResourceController.getContact();
        String accountId = contact.AccountId;
        User user = [SELECT Id, Name, Profile.name FROM User WHERE Id = :UserInfo.getUserId()];
        Boolean invoiceAccess = user.Profile.name == 'E.D. Portal User' ? true : false;
        String contenFilter = invoiceAccess ? '' : '%Invoice%';

        results.recordCount = [
            SELECT COUNT()
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Customer__c = :accountId
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND Type__c = 'Order'
                AND Sub_Type__c = 'Blanket'
        ];

        results.records = [
            SELECT
                (
                    SELECT
                        Id,
                        Name,
                        Account__c,
                        Part_Numbers__c,
                        Part_Numbers__r.Id,
                        Part_Numbers__r.Name,
                        Part_Numbers__r.Item_Description_OPUS__c
                    FROM Alternative_Part_Numbers__r
                ),
                Id,
                (
                    SELECT Id, ContentDocument.Title, ContentDocumentId
                    FROM ContentDocumentLinks
                    WHERE NOT ContentDocument.Title LIKE :contenFilter
                ),
                (
                    SELECT
                        Id,
                        Customer_Item__c,
                        CableCode__c,
                        Item_Markings__c,
                        SalesPricePortal__c,
                        NotesPortal__c,
                        TotalDollarsPortal__c,
                        Putups__c,
                        Put_up_1__c,
                        Put_up_2__c,
                        Put_up_3__c,
                        Put_up_4__c,
                        Put_up_5__c,
                        Put_up_6__c,
                        Put_up_7__c,
                        Spec_Sheet__c,
                        C2SPRC__c,
                        Name,
                        Dollars__c,
                        Expected_Date__c,
                        Freight_Terms__c,
                        Freight_Carrier__c,
                        Item_Description__c,
                        Line_Item__c,
                        Line_Number__c,
                        Line_Status__c,
                        Qty_Ordered__c,
                        Qty_Shipped__c,
                        TrackingURL__c,
                        Order_Header__c,
                        Received_Complete__c
                    FROM Order_Details__r
                    WHERE Line_Status__c != 'Cancelled'
                    ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
                ),
                Ship_to_Address_1__c,
                Ship_to_Address_2__c,
                Ship_to_City__c,
                Ship_to_State__c,
                Ship_to_Zip_Code__c,
                OCC_RewardRedeemed__c,
                Order_Number__c,
                RFQNumber__c,
                RFQ_Text__c,
                CreditRMAPortalType__c,
                TotalOrderSalesPortal__c,
                CreatedDate,
                Name,
                Purchase_Agent__c,
                Notes__c,
                Status__c,
                Type__c,
                OCC_Rewards__c,
                Customer__c,
                Customer__r.ShippingAddress,
                Customer__r.BillingAddress,
                Customer__r.Name,
                Customer__r.OCC_Rewards__c,
                Total_Order_Sales__c,
                TotalDollars__c,
                Outside_AM_Name__r.Name,
                Outside_AM_Name__r.UserRole.Name,
                Outside_AM_Name__r.FullPhotoUrl,
                Outside_AM_Name__r.Photo__c,
                Outside_AM_Name__r.Email,
                Outside_AM_Name__r.Phone,
                Inside_AM_Name__r.Email,
                Inside_AM_Name__r.FullPhotoUrl,
                Inside_AM_Name__r.Photo__c,
                Inside_AM_Name__r.Phone,
                Inside_AM_Name__r.Name,
                Entered_By__c,
                Date__c,
                Buyer__c,
                Job_Reference__c,
                Mark_Number__c,
                Payment_Terms__c,
                Customer_PO__c,
                Customer_Name__c,
                Customer__r.OwnerId,
                Buyer__r.Name,
                RewardOverride__c,
                Entered_By__r.Name,
                RMF_PO__c,
                Sub_Type__c,
                Requested_Delivery_Date__c,
                Delivery_Address__c
            FROM QuotesOrdersCredits_Header__c
            WHERE
                Customer__c = :accountId
                AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
                AND Type__c = 'Order'
                AND Sub_Type__c = 'Blanket'
            ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
            LIMIT 10
            OFFSET :offset
        ];

        return results;
    }

    /**
     * @description flag releases as received
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String Id
     * @param Boolean value
     * @return Boolean
     * @status Completed
     **/
    @AuraEnabled
    public static Boolean toggleReleaseReceive(String Id, Boolean value) {
        QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(Id = Id, Received_Complete__c = value);
        update detail;
        return detail.Received_Complete__c;
    }

    @AuraEnabled
    public static List<Alternative_Part_Number__c> getAlternativePartNumbers(String accountId) {
        return [
            SELECT
                Id,
                Name,
                Account__c,
                Cable_Code__c,
                Part_Numbers__c,
                Part_Numbers__r.Id,
                Part_Numbers__r.Name,
                Part_Numbers__r.Item_Description_OPUS__c
            FROM Alternative_Part_Number__c
            WHERE Account__c = :accountId
        ];
    }

    /**
     * @description get all data required for the Request Release page
     * @author chrisw@launchdm.com | 11-30-2022
     * @return Map<String, Object>
     * @status Completed
     **/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRequestReleaseData() {
        Contact contact = Portal_ResourceController.getContact();
        Account account = [
            SELECT
                Id,
                Account_Number__c,
                (SELECT Id, Name, Area_Account_Manager__c, Area_Account_Manager__r.Name FROM Job_Areas__r ORDER BY Name ASC)
            FROM Account
            WHERE Id = :contact.AccountId
        ];

        Map<String, Object> results = new Map<String, Object>();
        results.put('defaultPartList', Portal_ResourceController.getDefaultFilteredParts());
        results.put('deliveryAddresses', Portal_ResourceController.getDeliveryAddresses(contact.AccountId));
        results.put('jobAreas', account.Job_Areas__r);
        results.put('contact', contact);
        //Depricated
        // results.put(
        //     'rmfPOValues',
        //     Portal_ResourceController.getFieldDependencies('Account', 'Portal_PO_Selector__c', 'Portal_POs__c', account.Account_Number__c)
        // );
        return results;
    }

    @AuraEnabled
    public static List<Alternative_Part_Number__c> getDefaultFilteredParts() {
        Contact contact = Portal_ResourceController.getContact();
        return [
            SELECT Id, Name, Part_Numbers__r.Name, Part_Numbers__r.Item_Description_OPUS__c
            FROM Alternative_Part_Number__c
            WHERE Account__c = :contact.AccountId AND Closed__c = false
            ORDER BY Name ASC
            LIMIT 25
        ];
    }

    @AuraEnabled
    public static List<Alternative_Part_Number__c> searchAlternateParts(String searchTerm) {
        Contact contact = Portal_ResourceController.getContact();
        searchTerm = '*' + searchTerm + '*';
        List<Alternative_Part_Number__c> items = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING
                Alternative_Part_Number__c(
                    Id,
                    Name,
                    Part_Numbers__r.Name,
                    Part_Numbers__r.Item_Description_OPUS__c
                    WHERE Account__c = :contact.AccountId AND Closed__c = false
                    LIMIT 50)
        ][0];

        return items;
    }

    @AuraEnabled
    public static List<Delivery_Address__c> getDeliveryAddresses(String accountId) {
        Contact contact = Portal_ResourceController.getContact();
        return [
            SELECT
                Id,
                Name,
                Street_Address__c,
                Display_Name__c,
                Zip_Code__c,
                City__c,
                State__c,
                Site_Contact_Name__c,
                Flatbed_Requirements__c,
                Require_24hr_Notice__c,
                Phone_Number__c,
                Lift_Gate__c,
                Other_Instructions__c
            FROM Delivery_Address__c
            WHERE Contact__c = :contact.Id
        ];
    }

    public class MyPickListInfo {
        public String validFor;
    }

    /**
     * @name getFieldDependencies
     * @description get dependent list based on account number
     * @param String objectName
     * @param String controllingField
     * @param String dependentField
     * @param String AccountNumber
     * @return List<String> dependentFields
     * @status Completed
     **/
    public static List<String> getFieldDependencies(
        String objectName,
        String controllingField,
        String dependentField,
        String AccountNumber
    ) {
        Map<String, List<String>> controllingInfo = new Map<String, List<String>>();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);

        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();

        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();

        for (Schema.PicklistEntry currControllingValue : controllingValues) {
            controllingInfo.put(currControllingValue.getLabel(), new List<String>());
        }

        for (Schema.PicklistEntry currDependentValue : dependentValues) {
            String jsonString = JSON.serialize(currDependentValue);

            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);

            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor)).toUpperCase();

            Integer baseCount = 0;

            for (Integer curr : hexString.getChars()) {
                Integer val = 0;

                if (curr >= 65) {
                    val = curr - 65 + 10;
                } else {
                    val = curr - 48;
                }

                if ((val & 8) == 8) {
                    controllingInfo.get(controllingValues[baseCount + 0].getLabel()).add(currDependentValue.getLabel());
                }
                if ((val & 4) == 4) {
                    controllingInfo.get(controllingValues[baseCount + 1].getLabel()).add(currDependentValue.getLabel());
                }
                if ((val & 2) == 2) {
                    controllingInfo.get(controllingValues[baseCount + 2].getLabel()).add(currDependentValue.getLabel());
                }
                if ((val & 1) == 1) {
                    controllingInfo.get(controllingValues[baseCount + 3].getLabel()).add(currDependentValue.getLabel());
                }

                baseCount += 4;
            }
        }

        List<String> results = new List<String>();
        if (controllingInfo.get(AccountNumber) != null) {
            results = controllingInfo.get(AccountNumber);
        }

        return results;
    }

    /**
     * @description buld request release email
     * @author chrisw@launchdm.com | 11-30-2022
     * @param Contact contact
     * @param Account account
     * @param Map<String Object> newRequest
     * @param List<Map<String Object>> releaseItems
     * @return String
     * @status Completed
     **/
    public static String buildRFQEmailBody(
        Contact contact,
        Account account,
        Map<String, Object> newRequest,
        List<Map<String, Object>> releaseItems
    ) {
        Map<Object, Object> address = (Map<Object, Object>) newRequest.get('deliveryAddress');
        System.debug('newRequest: ' + JSON.serialize(newRequest));
        System.debug('releaseItems: ' + JSON.serialize(releaseItems));
        String emailBody =
            contact.FirstName +
            ', <br> <br>' +
            'We have received your Release Request below from <a href="https://myomnicable.com"> myomnicable.com </a> and will contact you shortly. <br> <br> ' +
            '<b>Release: </b> **RFQ**' +
            '<br/><b>Customer Name: </b>' +
            contact.Name +
            '<br/><br/><b>Delivery Information: </b><br/>' +
            '<b>Site Contact Name:</b> ' +
            (String) address.get('Site_Contact_Name__c') +
            '<br/>' +
            '<b>Phone Number:</b> ' +
            (String) address.get('Phone_Number__c') +
            '<br/>' +
            '<b>Address:</b> ' +
            (String) address.get('Display_Name__c') +
            '<br/>' +
            '<b>Delivery Instructions:</b> ' +
            (String) address.get('Other_Instructions__c') +
            '<br/>' +
            '<b>Require 24hr Notice:</b> ' +
            (Boolean) address.get('Require_24hr_Notice__c') +
            '<br/>' +
            '<b>Flatbed Requirements:</b> ' +
            (Boolean) address.get('Flatbed_Requirements__c') +
            '<br/>' +
            '<b>Lift Gate:</b> ' +
            (Boolean) address.get('Lift_Gate__c') +
            '<br/><br/>' +
            '<br/><b>Distributor P.O. #: </b>' +
            (String) newRequest.get('jobReference') +
            '<br/><b>Customer P.O. #: </b>' +
            (String) newRequest.get('rmfPO') +
            '<br/><b>Account #: </b>' +
            account.Account_Number__c +
            '<br/><b>Special Instructions / Job Reference: </b>' +
            (String) newRequest.get('specialInstructions') +
            '<br>' +
            '<br/><b>Total Weight: </b>' +
            (Decimal) newRequest.get('totalWeight') +
            '<br>';

        Integer index = 1;
        for (Map<String, Object> item : releaseItems) {
            Boolean paralleling =  (Boolean) item.get('paralleling');
            String par = paralleling == true ? 'Yes' : 'No';
            emailBody += '<br/><b>Line Number: </b>' + index++;
            emailBody += '<br/><b>Customer Part #: </b>' +  (String) item.get('cableNumber');
            emailBody += '<br/><b>Item #: </b>' +  (String) item.get('itemNumber');
            emailBody += '<br/><b>Item Description: </b>' +  (String) item.get('description');
            emailBody += '<br/><b>Quantity: </b>' + item.get('qty');
            emailBody += '<br/><b>Length: </b>' +  (String) item.get('lengthValue');
            emailBody += '<br/><b>Total Quantity: </b>' + (Decimal) item.get('totalQty');
            emailBody += '<br/><b>Special Instructions: </b>' +  (String) item.get('info');
            // emailBody += '<br/><b>Pulling Heads: </b>' + item.get('pullingHeads');
            emailBody += '<br/><b>Paralleling: </b>' + par;
            // emailBody += '<br/><b>Paralelling: </b>' + item.get('paralleling');
            emailBody += '<br/><b>Mark #: </b>' + (String) item.get('area');
            //emailBody += '<br/><b>Area Manager: </b>' + item.get('areaManager');
            emailBody += '<br> <br>';
        }

        emailBody +=
            '<b>Delivery Requirements: </b>' +
            (String) newRequest.get('deliveryDate') +
            '<br/><b>Contact Method:</b> ' +
            (String) newRequest.get('deliveryContact') +
            '<br> <br> <br> Thank you, <br> Omni Cable <br> <br>';
        return emailBody;
    }

    /**
     * @description send request release email and create release
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String typeStr
     * @param Map<String Object> newRequest
     * @param List<Map<String Object>> releaseItems
     * @param List<String> attachments
     * @return Map<String, Object>
     * @status Completed
     **/
    @AuraEnabled
    public static Map<String, Object> sendRFQ(
        String typeStr,
        Map<String, Object> newRequest,
        List<Map<String, Object>> releaseItems,
        List<String> attachments
    ) {
        Map<String, Object> result = new Map<String, Object>();
        User user = [SELECT User_s_AM_Email__c, User_s_DSM_Email__c, User_s_RM_Email__c FROM User WHERE Id = :UserInfo.getUserId()];
        Contact contact = Portal_ResourceController.getContact();
        Account account = [
            SELECT Id, ParentId, Account_Number__c, Outside_Salesperson__r.Email, Owner.FirstName, Owner.LastName, Owner.Email, Owner.Phone
            FROM Account
            WHERE Id = :contact.AccountId
        ];

        String managerEmail = account.Owner.Email;
        if (managerEmail == null) {
            managerEmail = user.User_s_AM_Email__c;
        }
        System.debug('managerEmail: ' + managerEmail);

        String[] toAddress = new List<String>{ contact.Email };

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(toAddress);

        List<Messaging.EmailFileAttachment> efas = new List<Messaging.EmailFileAttachment>();
        List<ContentVersion> emailContentVersions = [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE Id IN :attachments
        ];
        for (ContentVersion contentVersion : emailContentVersions) {
            Blob imageBlob = contentVersion.VersionData;
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setBody(imageBlob);
            efa.setFileName(contentVersion.Title + '.' + contentVersion.FileExtension);
            efas.add(efa);
        }

        message.setFileAttachments(efas);
        if (!Test.isRunningTest() && managerEmail != null) {
            message.setCcAddresses(new List<String>{ managerEmail });
            message.setReplyTo(managerEmail);
            message.setSenderDisplayName(managerEmail);
        }

        message.setBccAddresses(new List<String>{ 'portal@omnicable.com' });
        message.setSubject('Release Received from myomnicable.com');

        String emailBody = Portal_ResourceController.buildRFQEmailBody(contact, account, newRequest, releaseItems);
        Map<Object, Object> address = (Map<Object, Object>) newRequest.get('deliveryAddress');
        System.debug('DELIVERY_DATE: ' + newRequest.get('rawDeliveryDate'));

        QuotesOrdersCredits_Header__c newQOC = new QuotesOrdersCredits_Header__c(
            RFQ_Text__c = emailBody,
            Customer__c = account.Id,
            Date__c = date.today(),
            Job_Reference__c = (String) newRequest.get('JobReference'),
            Requested_Delivery_Date__c = (Date) Date.valueOf((String)newRequest.get('rawDeliveryDate')),
            Delivery_Address__c = (String) address.get('Id'),
            // Mark_Number__c = request.markNumber,
            Buyer__c = contact.Id,
            Type__c = 'RFQ'
        );
        insert newQOC;

        QuotesOrdersCredits_Header__c fullQOC = [SELECT Id, RFQNumber__c FROM QuotesOrdersCredits_Header__c WHERE Id = :newQOC.Id];
        emailBody = emailBody.replace('**RFQ**', fullQOC.RFQNumber__c);
        fullQOC.RFQ_Text__c = emailBody;
        update fullQOC;
        message.setPlainTextBody(emailBody);
        message.setHtmlBody(emailBody);
        message.setSaveAsActivity(true);
        Messaging.SendEmailResult[] messageRes = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
        result.put('message', fullQOC.RFQNumber__c + ' successfully submitted');
        result.put('success', true);
        return result;
    }

    /**
     * @description get all acount data for account page
     * @author chrisw@launchdm.com | 11-30-2022
     * @return Map<String, Object>
     * @status Completed
     **/
    @AuraEnabled
    public static Map<String, Object> getAccount() {
        Map<String, Object> results = new Map<String, Object>();
        Contact contact = Portal_ResourceController.getContact();
        User user = [SELECT User_s_AM_Email__c, User_s_DSM_Email__c, User_s_RM_Email__c FROM User WHERE Id = :UserInfo.getUserId()];
        Account account = [
            SELECT
                Id,
                Owner.FirstName,
                Owner.LastName,
                Owner.Email,
                Owner.Name,
                Owner.Phone,
                Owner.Photo__c,
                Owner.Full_Name__c,
                Owner.FullPhotoUrl,
                Outside_Salesperson__r.Name,
                Outside_Salesperson__r.Full_Name__c,
                Outside_Salesperson__r.Phone,
                Outside_Salesperson__r.Email,
                Outside_Salesperson__r.ManagerId,
                Outside_Salesperson__r.Photo__c
            FROM Account
            WHERE Id = :contact.AccountId
        ];

        List<User> otherManagers = [
            SELECT Name, Full_Name__c, UserRole.Name, Email, Phone, FullPhotoUrl, Photo__c, ManagerId
            FROM User
            WHERE Id = :account.Outside_Salesperson__r.ManagerId
        ];
        if (otherManagers.size() > 0) {
            results.put('regionalManager', otherManagers.get(0));
        }

        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :contact.Id
            ORDER BY Id DESC
            LIMIT 1
        ];

        if (docLinks.size() > 0) {
            results.put('contactFileId', docLinks[0].ContentDocumentId);
        } else {
            results.put('contactFileId', '');
        }

        results.put('contact', contact);
        results.put('accountManager', account.Owner);
        results.put('territorySalesManager', account.Outside_Salesperson__r);
        results.put('amEmail', user.User_s_AM_Email__c);
        results.put('dsmEmail', user.User_s_DSM_Email__c);
        results.put('rmEmail', user.User_s_RM_Email__c);

        return results;
    }

    /**
     * @description
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String recId
     * @return String
     * @status Deprecated
    
    @AuraEnabled
    public static String updatePicturePath(String recId) {
        //In lighting, the attachments are stored in content documents
        ContentDocumentLink docLink = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recId
            ORDER BY Id DESC
            LIMIT 1
        ];
        //ContentVersion Id uniquely identifies the attachment
        ContentVersion version = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :docLink.ContentDocumentId];
        //Update the Picture_Path field with the url of the image
        Contact contact = [SELECT Id, OCC_Photo__c FROM Contact WHERE Id = :recId];
        contact.OCC_Photo__c = '/sfc/servlet.shepherd/version/download/' + version.Id;
        upsert contact;
        return docLink.ContentDocumentId;
    }
     **/

    /**
     * @description search all available inventory
     * @author chrisw@launchdm.com | 11-30-2022
     * @param String searchTerm
     * @param Integer offset
     * @return List<Inventory_Item__c>
     * @status Compelted
     **/
    @AuraEnabled(cacheable=true)
    public static QOCResults getAvailableInventory(String searchTerm, Integer offset, Integer limitCount) {
        Contact contact = Portal_ResourceController.getContact();
        QOCResults results = new QOCResults();
        // results.recordCount = [SELECT COUNT() FROM Inventory_Item__c];

        if (searchTerm != null && searchTerm.length() > 0) {
            searchTerm = '*' + searchTerm + '*';
            List<String> foundIds = new List<String>();

            for (
                sObject item : [
                    FIND :searchTerm
                    RETURNING Inventory_Item__c(Id WHERE Account__c = :contact.AccountId)
                ][0]
            ) {
                foundIds.add((item.Id));
            }

        results.recordCount = foundIds.size();
            results.records = [
                SELECT
                    Id,
                    Name,
                    Customer_PO__c,
                    Description__c,
                    Available__c,
                    On_Hand__c,
                    Bin_Location__c,
                    Weight_Per_Foot__c,
                    (SELECT Id, Name, Putup__c, Lot_Number__c FROM Reels__r)
                FROM Inventory_Item__c
                WHERE Id IN :foundIds
                ORDER BY Name
                LIMIT :limitCount
                OFFSET :offset
            ];
        } else {
            results.recordCount = [SELECT COUNT() FROM Inventory_Item__c WHERE Account__c = :contact.AccountId];
            results.records = [
                SELECT
                    Id,
                    Name,
                    Customer_PO__c,
                    Description__c,
                    Available__c,
                    On_Hand__c,
                    Bin_Location__c,
                    Lot_Number__c,
                    Weight_Per_Foot__c,
                    (SELECT Id, Name, Putup__c, Lot_Number__c FROM Reels__r)
                FROM Inventory_Item__c
                WHERE Account__c = :contact.AccountId
                ORDER BY Name
                LIMIT :limitCount
                OFFSET :offset
            ];
        }

        return results;
    }

    // @AuraEnabled
    // public static QOCResults globalSearch(String searchTerm) {
    //     Contact contact = Portal_ResourceController.getContact();
    //     QOCResults results = new QOCResults();
    //     Set<Id> headerIds = new Set<Id>();

    //     searchTerm = '*' + searchTerm + '*';

    //     List<List<SObject>> allResults = [
    //         FIND :searchTerm
    //         RETURNING QuoteOrderCredit_Details__c(Order_Header__c WHERE Line_Status__c != 'Cancelled')
    //     ];

    //     List<QuoteOrderCredit_Details__c> allDetails = ((List<QuoteOrderCredit_Details__c>) allResults[0]);

    //     for (QuoteOrderCredit_Details__c detail : allDetails) {
    //         if (!headerIds.contains(detail.Order_Header__c)) {
    //             headerIds.add(detail.Order_Header__c);
    //         }
    //     }

    //     results.recordCount = [
    //         SELECT COUNT()
    //         FROM QuotesOrdersCredits_Header__c
    //         WHERE
    //             Buyer__c = :contact.Id
    //             AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
    //             AND (Type__c = 'Release'
    //             OR Type__c = 'RFQ'
    //             OR Sub_Type__c = 'Change Order')
    //     ];

    //     results.records = [
    //         SELECT
    //             (
    //                 SELECT
    //                     Id,
    //                     Name,
    //                     Account__c,
    //                     Part_Numbers__c,
    //                     Part_Numbers__r.Id,
    //                     Part_Numbers__r.Name,
    //                     Part_Numbers__r.Item_Description_OPUS__c
    //                 FROM Alternative_Part_Numbers__r
    //             ),
    //             Id,
    //             (
    //                 SELECT
    //                     Id,
    //                     Customer_Item__c,
    //                     CableCode__c,
    //                     Item_Markings__c,
    //                     SalesPricePortal__c,
    //                     NotesPortal__c,
    //                     TotalDollarsPortal__c,
    //                     Put_up_1__c,
    //                     Put_up_2__c,
    //                     Put_up_3__c,
    //                     Put_up_4__c,
    //                     Put_up_5__c,
    //                     Put_up_6__c,
    //                     Put_up_7__c,
    //                     Spec_Sheet__c,
    //                     C2SPRC__c,
    //                     Name,
    //                     Dollars__c,
    //                     Expected_Date__c,
    //                     Freight_Terms__c,
    //                     Freight_Carrier__c,
    //                     Item_Description__c,
    //                     Line_Item__c,
    //                     Line_Number__c,
    //                     Line_Status__c,
    //                     Qty_Ordered__c,
    //                     Qty_Shipped__c,
    //                     TrackingURL__c,
    //                     Order_Header__c,
    //                     Received_Complete__c
    //                 FROM Order_Details__r
    //                 WHERE Line_Status__c != 'Cancelled'
    //                 ORDER BY QuoteOrderCredit_Details__c.Line_Number__c
    //             ),
    //             Ship_to_Address_1__c,
    //             Ship_to_Address_2__c,
    //             Ship_to_City__c,
    //             Ship_to_State__c,
    //             Ship_to_Zip_Code__c,
    //             OCC_RewardRedeemed__c,
    //             Order_Number__c,
    //             RFQNumber__c,
    //             RFQ_Text__c,
    //             CreditRMAPortalType__c,
    //             TotalOrderSalesPortal__c,
    //             CreatedDate,
    //             Name,
    //             Purchase_Agent__c,
    //             Notes__c,
    //             Status__c,
    //             Type__c,
    //             OCC_Rewards__c,
    //             Customer__c,
    //             Customer__r.ShippingAddress,
    //             Customer__r.BillingAddress,
    //             Customer__r.Name,
    //             Customer__r.OCC_Rewards__c,
    //             Total_Order_Sales__c,
    //             TotalDollars__c,
    //             Outside_AM_Name__r.Name,
    //             Outside_AM_Name__r.UserRole.Name,
    //             Outside_AM_Name__r.FullPhotoUrl,
    //             Outside_AM_Name__r.Photo__c,
    //             Outside_AM_Name__r.Email,
    //             Outside_AM_Name__r.Phone,
    //             Inside_AM_Name__r.Email,
    //             Inside_AM_Name__r.FullPhotoUrl,
    //             Inside_AM_Name__r.Photo__c,
    //             Inside_AM_Name__r.Phone,
    //             Inside_AM_Name__r.Name,
    //             Entered_By__c,
    //             Date__c,
    //             Buyer__c,
    //             Job_Reference__c,
    //             Mark_Number__c,
    //             Payment_Terms__c,
    //             Customer_PO__c,
    //             Customer_Name__c,
    //             Customer__r.OwnerId,
    //             Buyer__r.Name,
    //             RewardOverride__c,
    //             Entered_By__r.Name,
    //             RMF_PO__c,
    //             Sub_Type__c
    //         FROM QuotesOrdersCredits_Header__c
    //         WHERE
    //             Id IN :headerIds
    //             AND Buyer__c = :contact.Id
    //             AND QuotesOrdersCredits_Header__c.Status__c != 'Cancelled'
    //             AND (Type__c = 'Release'
    //             OR Type__c = 'RFQ'
    //             OR Sub_Type__c = 'Change Order')
    //         ORDER BY QuotesOrdersCredits_Header__c.Sub_Type__c ASC, QuotesOrdersCredits_Header__c.Date__c DESC
    //     ];

    //     return results;

    // return [FIND :searchTerm in all fields returning
    // QuotesOrdersCredits_Header__c (Id, Name, Owner.Name, Status__c LIMIT 5),
    // Inventory_Item__c (Id, Name, Project__r.Name LIMIT 10);
    // }
}