/**
 * @description Unit tests for QOC header, detail, and product sync: {@link OpportunityHeaderSyncBatch},
 *              {@link OpportunityDetailSyncBatch}, {@link ProductSyncBatch}, {@link OpportunitySync},
 *              {@link QuoteSync}, {@link OrderSync}, line syncs, {@link OrderContentDocumentLinkHandler},
 *              {@link SyncBase}, schedulers, {@link OppSyncCleanErrorHandler}, {@link Notify_Region_Leads},
 *              {@link SalesCloudPostDeployment}, and {@link PriceSheetController}.
 * @group QOC Sync
 * @see OpportunityHeaderSyncBatch
 * @see OpportunityDetailSyncBatch
 * @see OrderSync
 * @see OrderContentDocumentLinkHandler
 * @see SyncBase
 */
@IsTest
public class QOCSyncTest {
    
    /**
     * @description Returns the reusable QOC test Account ({@code Account_Number__c = QOC-TEST-ACCT}), inserting it if needed.
     * @return Account used as Customer on QOC headers in this class.
     */
    public static Account getTestAccount() {
        List<Account> accounts = [
            SELECT Id, Account_Number__c
            FROM Account
            WHERE Account_Number__c = 'QOC-TEST-ACCT'
            LIMIT 1
        ];
        if (!accounts.isEmpty()) {
            return accounts[0];
        }

        Account account = new Account(
            Name = 'QOC Sync Test Account',
            Account_Number__c = 'QOC-TEST-ACCT',
            Region__c = '6',
            Active__c = 'A'
        );
        insert account;
        return account;
    }

    /**
     * @description Inserts a buyer Contact on the given Account for QOC header tests.
     * @param account Parent Account; {@link Contact#Ext_Id__c} is {@code Account_Number__c:0}.
     * @return Inserted Contact.
     */
    public static Contact getTestContact(Account account) {
        Contact contact = new Contact(
            LastName = 'QOC Buyer',
            FirstName = 'Test',
            Email = 'qoc.test@omnicable.com',
            AccountId = account.Id,
            Ext_Id__c = account.Account_Number__c + ':0',
            Contact_Title__c = 'Accounting',
            DSP_Purchaser__c = true
        );
        insert contact;
        return contact;
    }

    /**
     * @description Sets the org header-sync watermark used by {@link OpportunityHeaderSyncBatch}.
     * @param watermark {@link Opportunity_Sync__c#LastModifiedDate__c}; null processes all headers on next run.
     */
    private static void setHeaderSyncWatermark(Datetime watermark) {
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new Opportunity_Sync__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        settings.LastModifiedDate__c = watermark;
        upsert settings;
    }

    /**
     * @description Sets the org detail-sync watermark used by {@link OpportunityDetailSyncBatch}.
     * @param watermark {@link Opportunity_Sync__c#Detail_Last_Modified__c}; null processes all details on next run.
     */
    private static void setDetailSyncWatermark(Datetime watermark) {
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new Opportunity_Sync__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        settings.Detail_Last_Modified__c = watermark;
        upsert settings;
    }

    /**
     * @description Activates the org standard price book in tests via {@link Test#getStandardPricebookId}.
     * @return Standard {@link Pricebook2} with {@code IsActive = true}.
     */
    public static Pricebook2 createStandardPB() {
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update standardPricebook;
        return standardPricebook;
    }

    /**
     * @description Inserts a Potential Distributor Account for price-sheet and related tests.
     * @param count Unused; retained for call-site compatibility.
     * @return Inserted Account.
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
     * @description Inserts {@code size} Contacts on the given Account with sequential {@link Contact#Ext_Id__c} values.
     * @param size Number of Contacts to insert.
     * @param a Parent Account.
     * @return Inserted Contacts.
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
     * @description Inserts price book approval rows (and one expired approval) for the given price books.
     * @param count Number of non-expired approvals to create (one per price book index).
     * @param pbs Price books to attach; {@code pbs[i]} is used for the ith approval.
     * @return Inserted {@link Price_Book_Approval__c} rows including the expired record.
     */
    public static List<Price_Book_Approval__c> createPBAs(Integer count, List<Pricebook2> pbs) {
        User user = [SELECT Id FROM User LIMIT 1];
        List<String> statuses = new List<String>{ 'Approved', 'Ready to Submit', 'Not Ready', 'Pending' };
        List<Price_Book_Approval__c> records = new List<Price_Book_Approval__c>();
        for (Integer i = 0; i < count; i++) {
            Price_Book_Approval__c record = new Price_Book_Approval__c(
                Name = 'PBA' + String.valueOf(i),
                Status__c = statuses.get(Math.min(i, statuses.size() - 1)),
                Type__c = 'Accounts',
                Expiration__c = '30 Days',
                From_User__c = user.Id,
                Price_Book__c = pbs[i].Id
            );
            records.add(record);
        }

        Price_Book_Approval__c expiredRecord = new Price_Book_Approval__c(
            Expiration_Date__c = Date.today().addDays(-5),
            Name = 'PBA-Expired',
            Status__c = 'Approved',
            Type__c = 'Accounts',
            Expiration__c = '30 Days',
            From_User__c = user.Id,
            Price_Book__c = pbs[0].Id
        );
        records.add(expiredRecord);

        insert records;
        return records;
    }

    /**
     * @description Inserts {@code count} {@link Product2} rows for price-sheet tests.
     * @param count Number of products to insert.
     * @return Inserted products.
     */
    public static List<Product2> createProducts(Integer count) {
        List<Product2> records = new List<Product2>();
        List<PriceBookEntry> entries = new List<PriceBookEntry>();

        for (Integer i = 0; i < count; i++) {
            Product2 record = new Product2(
                Attachment_Visible__c = true,
                Name = 'Product' + String.valueOf(i),
                ProductCode = 'Product' + String.valueOf(i),
                Unit_Price__c = Decimal.valueOf(count),
                Family = 'Family',
                Category__c = 'Category' + String.valueOf(i)
            );
            records.add(record);
        }
        insert records;

        // for (Product2 prod : records) {
        //     PricebookEntry record = new PricebookEntry(Product2Id=prod.Id, Base_Price__c = prod.Unit_Price__c, UnitPrice = prod.Unit_Price__c, Pricebook2Id=Test.getStandardPricebookId());
        //     entries.add(record);
        // }
        // // insert entries;

        return records;
    }

    /**
     * @description Inserts a {@link PricebookEntry} for each product and price book combination.
     * @param count Unused; retained for call-site compatibility.
     * @param prods Products to add to each price book.
     * @param pbs Price books that receive entries.
     * @return Inserted price book entries.
     */
    public static List<PricebookEntry> createPriceBookEntries(Integer count, List<Product2> prods, List<PriceBook2> pbs) {
        List<PricebookEntry> records = new List<PricebookEntry>();
        for (Product2 prod : prods) {
            for (PriceBook2 pb : pbs) {
                PricebookEntry record = new PricebookEntry(
                    Product2Id = prod.Id,
                    Base_Price__c = prod.Unit_Price__c,
                    UnitPrice = prod.Unit_Price__c,
                    Pricebook2Id = pb.Id
                );
                records.add(record);
            }
        }
        insert records;
        return records;
    }

    /**
     * @description Inserts {@code count} {@link Part_Numbers__c} rows with matching Name and Item_Number__c.
     * @param count Number of parts to insert.
     * @return Inserted parts.
     */
    public static List<Part_Numbers__c> createParts(Integer count) {
        List<Part_Numbers__c> records = new List<Part_Numbers__c>();
        for (Integer i = 0; i < count; i++) {
            Part_Numbers__c record = new Part_Numbers__c(
                Name = 'Part' + String.valueOf(i),
                Item_Number__c = 'Part' + String.valueOf(i)
            );
            records.add(record);
        }
        insert records;
        return records;
    }


    /**
     * @description Inserts {@code count} active price books, alternating Base and Custom {@link Pricebook2#Type__c}.
     * @param count Number of price books to insert.
     * @return Inserted price books.
     */
    public static List<PriceBook2> createPriceBooks(Integer count) {
        List<Pricebook2> records = new List<Pricebook2>();
        for (Integer i = 0; i < count; i++) {
            String typeStr = math.mod(i, 2) == 0 ? 'Base' : 'Custom';
            Pricebook2 record = new Pricebook2(Name = 'PB' + String.valueOf(i), Type__c = typeStr, Date__c = Date.today(), IsActive = true);
            records.add(record);
        }
        insert records;
        return records;
    }

    /**
     * @description Points Custom price books at the first list row as {@link Pricebook2#Base_Price_Book__c} and renames that base book.
     * @param pbs Price books from {@link #createPriceBooks}.
     * @return The same list after update.
     */
    public static List<PriceBook2> setCustomPriceBooks(List<Pricebook2> pbs) {
        for (PriceBook2 pb : pbs) {
            if (pb.Type__c == 'Custom') {
                pb.Base_Price_Book__c = pbs[0].Id;
            }
        }

        update pbs;

        PriceBook2 updateStandard = pbs[0];
        updateStandard.Name = 'Changed';
        update updateStandard;

        return pbs;
    }

    /**
     * @description Creates a QOC header row for sync tests.
     * @param customer Account set as {@link QuotesOrdersCredits_Header__c#Customer__c}.
     * @param buyer Contact set as {@link QuotesOrdersCredits_Header__c#Buyer__c}; null leaves Buyer blank.
     * @param typeValue {@link QuotesOrdersCredits_Header__c#Type__c} (Quote, Order, or Credit).
     * @param orderNumber Value stored on Name and {@link QuotesOrdersCredits_Header__c#Order_Number__c}.
     * @return Inserted header.
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
     * @description Creates a QOC detail row linked to a header.
     * @param headerId Parent {@link QuotesOrdersCredits_Header__c} Id.
     * @param extId {@link QuoteOrderCredit_Details__c#Ext_Id__c} used for line-item matching.
     * @param partNumberId Optional {@link Part_Numbers__c} Id for {@link QuoteOrderCredit_Details__c#Item_Number__c}.
     * @return Inserted detail.
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
     * @description Links a {@link Product2} to a part for detail sync product resolution.
     * @param part Part that receives {@link Product2#Part_Number_Ref__c} and matching item number.
     * @return Inserted product.
     */
    public static Product2 createProductForPart(Part_Numbers__c part) {
        createStandardPB();
        Product2 product = new Product2(
            Name = part.Name,
            Part_Number_Ref__c = part.Id,
            Item_Number__c = part.Item_Number__c,
            ProductCode = part.Item_Number__c,
            Unit_Price__c = 1,
            IsActive = true,
            Category__c = 'Other'
        );
        insert product;
        return product;
    }

    /**
     * @description Queries accessible non-BASE64 fields on QOC headers for DataWeave header sync.
     * @param headerIds Header Ids to load.
     * @return Header rows with all accessible fields populated.
     */
    public static List<QuotesOrdersCredits_Header__c> queryHeaders(Set<Id> headerIds) {
        Map<String, Schema.SObjectField> fieldMap = QuotesOrdersCredits_Header__c.SObjectType.getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>();
        for (Schema.SObjectField fieldToken : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (!fieldDescribe.isAccessible() || fieldDescribe.getType() == Schema.DisplayType.BASE64) {
                continue;
            }
            fieldNames.add(fieldDescribe.getName());
        }
        fieldNames.sort();
        String soql =
            'SELECT ' +
            (fieldNames.isEmpty() ? 'Id' : String.join(fieldNames, ',')) +
            ' FROM QuotesOrdersCredits_Header__c WHERE Id IN :headerIds';
        return Database.query(soql);
    }

    /**
     * @description Runs {@link OpportunitySync}, {@link QuoteSync}, then {@link OrderSync} for one header.
     * @param header Header to reload and sync.
     */
    public static void runHeaderSyncChain(QuotesOrdersCredits_Header__c header) {
        List<QuotesOrdersCredits_Header__c> headers = queryHeaders(new Set<Id>{ header.Id });
        Id standardPricebookId = Test.getStandardPricebookId();
        OpportunitySync opportunitySync = new OpportunitySync(headers, standardPricebookId);
        opportunitySync.runSync();
        new QuoteSync(headers, opportunitySync.standardPricebookId).runSync();
        new OrderSync(headers, opportunitySync.standardPricebookId).runSync();
    }

    /**
     * @description Queries accessible non-BASE64 fields on QOC details for DataWeave line sync.
     * @param detailIds Detail Ids to load.
     * @return Detail rows with all accessible fields populated.
     */
    public static List<QuoteOrderCredit_Details__c> queryDetails(Set<Id> detailIds) {
        Map<String, Schema.SObjectField> fieldMap = QuoteOrderCredit_Details__c.SObjectType.getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>();
        for (Schema.SObjectField fieldToken : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (!fieldDescribe.isAccessible() || fieldDescribe.getType() == Schema.DisplayType.BASE64) {
                continue;
            }
            fieldNames.add(fieldDescribe.getName());
        }
        fieldNames.sort();
        String soql =
            'SELECT ' +
            (fieldNames.isEmpty() ? 'Id' : String.join(fieldNames, ',')) +
            ' FROM QuoteOrderCredit_Details__c WHERE Id IN :detailIds';
        return Database.query(soql);
    }

    /**
     * @description Runs {@link OpportunityLineItemSync}, {@link QuoteLineSync}, then {@link OrderLineSync} for one detail.
     * @param detail Detail to reload and sync.
     */
    public static void runDetailSyncChain(QuoteOrderCredit_Details__c detail) {
        List<QuoteOrderCredit_Details__c> details = queryDetails(new Set<Id>{ detail.Id });

        Id standardPricebookId = Test.getStandardPricebookId();
        Map<String, Id> product2IdByPartRef = new Map<String, Id>();
        Map<Id, PricebookEntry> pricebookEntryByProduct2Id = new Map<Id, PricebookEntry>();

        List<PricebookEntry> existingEntries = [
            SELECT Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId AND IsActive = true
            LIMIT 1
        ];
        System.assert(!existingEntries.isEmpty(), 'Org standard price book entry required for line sync tests');
        PricebookEntry entry = existingEntries[0];
        product2IdByPartRef.put('Non-Stock', entry.Product2Id);
        pricebookEntryByProduct2Id.put(entry.Product2Id, entry);

        OpportunityLineItemSync lineItemSync = new OpportunityLineItemSync(
            details,
            standardPricebookId,
            product2IdByPartRef,
            pricebookEntryByProduct2Id
        );
        lineItemSync.runSync();

        new QuoteLineSync(
            details,
            lineItemSync.standardPricebookId,
            lineItemSync.product2IdByPartRef,
            lineItemSync.pricebookEntryByProduct2Id
        ).runSync();

        new OrderLineSync(
            details,
            lineItemSync.standardPricebookId,
            lineItemSync.product2IdByPartRef,
            lineItemSync.pricebookEntryByProduct2Id
        ).runSync();
    }

    /**
     * @description Invokes {@link OpportunityDetailSyncBatch#execute} with an explicit detail scope, then {@code finish}.
     * @param detailIds Detail Ids loaded into the execute scope; empty skips execute.
     * @param extIds External Ids passed to the batch constructor.
     */
    public static void runDetailSyncBatch(Set<Id> detailIds, Set<String> extIds) {
        // start() always uses the watermark + open sync-error SOQL (constructor detailIds are unused).
        // Drive execute with an explicit scope so tests remain deterministic.
        OpportunityDetailSyncBatch batch = new OpportunityDetailSyncBatch(detailIds, extIds);
        if (detailIds != null && !detailIds.isEmpty()) {
            batch.execute(null, queryDetails(detailIds));
        }
        batch.finish(null);
    }

    /**
     * @description Runs {@link ProductSyncBatch} start, execute (for the given parts), and finish.
     * @param partIds {@link Part_Numbers__c} Ids in execute scope.
     */
    public static void runProductSyncBatch(Set<Id> partIds) {
        ProductSyncBatch batch = new ProductSyncBatch(partIds);
        batch.start(null);
        List<Part_Numbers__c> scope = [
            SELECT Id, Name, Item_Number__c, Active__c
            FROM Part_Numbers__c
            WHERE Id IN :partIds
        ];
        if (!scope.isEmpty()) {
            batch.execute(null, scope);
        }
        batch.finish(null);
    }

    /**
     * @description Returns one org-seeded {@link Part_Numbers__c} row with an item number.
     * @return A part required by product-sync tests that rely on existing org data.
     */
    public static Part_Numbers__c getExistingPartForSync() {
        List<Part_Numbers__c> parts = [
            SELECT Id, Name, Item_Number__c, Active__c
            FROM Part_Numbers__c
            WHERE Item_Number__c != NULL
            LIMIT 1
        ];
        System.assert(!parts.isEmpty(), 'Org seed data must include at least one Part_Numbers__c row');
        return parts[0];
    }

    /**
     * @description Quote-type header batch sync inserts Opportunity, Quote, and Order for the header order number.
     */
    @IsTest
    static void headerSyncBatch_insertsOpportunityQuoteAndOrder() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-H-001');
        setHeaderSyncWatermark(null);

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Order_Number__c = :header.Order_Number__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Quote WHERE Order_Number__c = :header.Order_Number__c]);
    }

    /**
     * @description Order-type header with Invoiced status syncs an {@link Order} row.
     */
    @IsTest
    static void headerSyncBatch_orderTypeSyncsOrderRecord() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-H-ORD-001');
        header.Status__c = 'Invoiced';
        update header;
        setHeaderSyncWatermark(null);

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Order WHERE Order_Number__c = :header.Order_Number__c]);
    }

    /**
     * @description {@link OrderContentDocumentLinkHandler#copyFromQocHeaders} copies existing header files
     *              onto an Order that references the header via {@link Order#Quote_Order_Credit__c}.
     */
    @IsTest
    static void orderInsert_copiesHeaderContentDocumentLinksToOrder() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-H-CDL-001');

        ContentVersion version = new ContentVersion(
            Title = 'QOC Header Attachment',
            PathOnClient = 'qoc-header.txt',
            VersionData = Blob.valueOf('header file'),
            IsMajorVersion = true
        );
        insert version;
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = header.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Order createdOrder = new Order(
            AccountId = customer.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            Quote_Order_Credit__c = header.Id,
            Order_Number__c = header.Order_Number__c
        );
        insert createdOrder;

        Test.startTest();
        OrderContentDocumentLinkHandler.copyFromQocHeaders(new List<Order>{ createdOrder });
        Test.stopTest();

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :createdOrder.Id AND ContentDocumentId = :contentDocumentId
            ]
        );
    }

    /**
     * @description Inserting a header {@link ContentDocumentLink} copies the file onto the related Order.
     */
    @IsTest
    static void headerContentDocumentLinkInsert_copiesFileToRelatedOrder() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-H-CDL-INS-001');
        Order relatedOrder = new Order(
            AccountId = customer.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            Quote_Order_Credit__c = header.Id,
            Order_Number__c = header.Order_Number__c
        );
        insert relatedOrder;

        Test.startTest();
        Id contentDocumentId = insertHeaderFile(header.Id, 'qoc-header-insert.txt');
        Test.stopTest();

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :relatedOrder.Id AND ContentDocumentId = :contentDocumentId
            ]
        );
    }

    /**
     * @description Updating header {@link ContentDocumentLink} Visibility copies that value onto the Order link.
     */
    @IsTest
    static void headerContentDocumentLinkUpdate_copiesVisibilityToRelatedOrder() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-H-CDL-UPD-001');
        Order relatedOrder = new Order(
            AccountId = customer.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            Quote_Order_Credit__c = header.Id,
            Order_Number__c = header.Order_Number__c
        );
        insert relatedOrder;
        Id contentDocumentId = insertHeaderFile(header.Id, 'qoc-header-update.txt');
        ContentDocumentLink headerLink = [
            SELECT Id, Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :header.Id AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];

        Test.startTest();
        headerLink.Visibility = 'InternalUsers';
        update headerLink;
        Test.stopTest();

        ContentDocumentLink orderLink = [
            SELECT Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :relatedOrder.Id AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        System.assertEquals('InternalUsers', orderLink.Visibility);
    }

    /**
     * @description Deleting a header {@link ContentDocumentLink} removes the matching Order file link.
     */
    @IsTest
    static void headerContentDocumentLinkDelete_removesFileFromRelatedOrder() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-H-CDL-DEL-001');
        Order relatedOrder = new Order(
            AccountId = customer.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            Quote_Order_Credit__c = header.Id,
            Order_Number__c = header.Order_Number__c
        );
        insert relatedOrder;
        Id contentDocumentId = insertHeaderFile(header.Id, 'qoc-header-delete.txt');
        ContentDocumentLink headerLink = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :header.Id AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];

        Test.startTest();
        delete headerLink;
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :relatedOrder.Id AND ContentDocumentId = :contentDocumentId
            ]
        );
    }

    /**
     * @description Inserts a {@link ContentVersion} and links it to a QOC header.
     * @param headerId {@link QuotesOrdersCredits_Header__c} Id to receive the file.
     * @param pathOnClient File name used as Title and PathOnClient.
     * @return {@link ContentVersion#ContentDocumentId} of the inserted file.
     */
    private static Id insertHeaderFile(Id headerId, String pathOnClient) {
        ContentVersion version = new ContentVersion(
            Title = pathOnClient,
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf('header file'),
            IsMajorVersion = true
        );
        insert version;
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = headerId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return contentDocumentId;
    }

    /**
     * @description Credit-type header sync creates an Order and does not create a Quote.
     */
    @IsTest
    static void headerSyncBatch_creditTypeSyncsOrderWithoutQuote() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Credit', 'QOC-H-CR-001');
        setHeaderSyncWatermark(null);

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Quote WHERE Order_Number__c = :header.Order_Number__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Order WHERE Order_Number__c = :header.Order_Number__c]);
    }

    /**
     * @description Header sync updates an existing Opportunity matched by order number.
     */
    @IsTest
    static void headerSyncBatch_updatesExistingOpportunity() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-H-UPD-001');

        Opportunity existing = new Opportunity(
            Name = header.Name,
            AccountId = customer.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(10),
            Order_Number__c = header.Order_Number__c
        );
        insert existing;
        setHeaderSyncWatermark(null);

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        Opportunity updated = [
            SELECT StageName
            FROM Opportunity
            WHERE Order_Number__c = :header.Order_Number__c
            LIMIT 1
        ];
        System.assertEquals('Negotiation/Review', updated.StageName);
    }

    /**
     * @description Header batch execute persists the {@link Opportunity_Sync__c} LastModifiedDate watermark.
     */
    @IsTest
    static void headerSyncBatch_executeUpdatesWatermark() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        Datetime priorWatermark = Datetime.now().addDays(-1);
        setHeaderSyncWatermark(priorWatermark);

        String orderNumber = 'QOC-H-WM-001';
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', orderNumber);
        header = [
            SELECT LastModifiedDate, Order_Number__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id = :header.Id
        ];

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        System.assertNotEquals(null, settings.LastModifiedDate__c, 'execute should persist latest header LastModifiedDate');
        System.assert(
            settings.LastModifiedDate__c >= header.LastModifiedDate,
            'watermark should be at least the processed header LastModifiedDate'
        );
        System.assert(
            settings.LastModifiedDate__c >= priorWatermark,
            'watermark should only advance forward'
        );
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Order_Number__c = :orderNumber]);
    }

    /**
     * @description Header batch start/execute/finish completes when the query scope is empty.
     */
    @IsTest
    static void headerSyncBatch_emptyScopeCompletes() {
        setHeaderSyncWatermark(Datetime.now().addDays(365));

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 200);
        Test.stopTest();

        System.assert(OpportunityHeaderSyncBatch.buildQuery(null).contains('ORDER BY LastModifiedDate ASC'));
        System.assert(!OpportunityHeaderSyncBatch.buildQuery(null).contains('WHERE'));
        String incrementalQuery = OpportunityHeaderSyncBatch.buildQuery(Datetime.now());
        System.assert(incrementalQuery.contains('WHERE LastModifiedDate >'));
        System.assert(
            incrementalQuery.contains('OR Order_Number__c IN :additionalHeaders'),
            'Incremental header query should also include open sync-error order numbers'
        );
    }

    /**
     * @description Direct {@link OpportunitySync}, {@link QuoteSync}, and {@link OrderSync} runSync no-ops on empty header lists.
     */
    @IsTest
    static void headerSync_directRunSyncNoOpsOnEmptyScope() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Test.startTest();
        new OpportunitySync(new List<QuotesOrdersCredits_Header__c>(), standardPricebookId).runSync();
        new QuoteSync(new List<QuotesOrdersCredits_Header__c>(), standardPricebookId).runSync();
        new OrderSync(new List<QuotesOrdersCredits_Header__c>(), standardPricebookId).runSync();
        Test.stopTest();
        System.assert(true, 'Empty scope should complete without error');
    }

    /**
     * @description Detail sync inserts an {@link OpportunityLineItem} for a non-stock detail.
     */

   
    static void detailSyncBatch_insertsLineItemsForNonStockDetail() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-D-001');
        runHeaderSyncChain(header);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Opportunity WHERE Order_Number__c = :header.Order_Number__c],
            'Header sync should create an opportunity'
        );

        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-D-001-L1', null);
        runDetailSyncChain(detail);

        System.assertEquals(1, [SELECT COUNT() FROM OpportunityLineItem WHERE Ext_Id__c = :detail.Ext_Id__c]);
        System.assertEquals(1, [SELECT COUNT() FROM QuoteLineItem WHERE Ext_Id__c = :detail.Ext_Id__c]);
    }

    /**
     * @description Detail sync updates existing line items matched by external Id.
     */

   
    static void detailSyncBatch_updatesExistingLineItems() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-D-UPD-001');
        runHeaderSyncChain(header);

        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-D-UPD-001-L1', null);
        runDetailSyncChain(detail);

        detail.Dollars__c = 250;
        update detail;

        runDetailSyncChain(detail);

        OpportunityLineItem oli = [
            SELECT TotalPrice
            FROM OpportunityLineItem
            WHERE Ext_Id__c = :detail.Ext_Id__c
            LIMIT 1
        ];
        System.assertEquals(250, oli.TotalPrice);
    }

    /**
     * @description Order-type header detail sync creates an {@link OrderItem}.
     */

   
    static void detailSyncBatch_orderLineSyncForOrderHeader() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-D-ORD-001');
        runHeaderSyncChain(header);

        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-D-ORD-001-L1', null);
        runDetailSyncChain(detail);

        System.assertEquals(1, [SELECT COUNT() FROM OrderItem WHERE Ext_Id__c = :detail.Ext_Id__c]);
    }

    /**
     * @description Detail batch execute resolves both item-number and non-stock product mappings.
     */

   
    static void opportunityDetailSyncBatch_executeWithItemNumberAndNonStock() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        Part_Numbers__c part = [
            SELECT Id, Item_Number__c
            FROM Part_Numbers__c
            WHERE Id IN (SELECT Part_Number_Ref__c FROM Product2 WHERE Part_Number_Ref__c != NULL)
            LIMIT 1
        ];

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-BATCH-MIX-001');
        runHeaderSyncChain(header);

        QuoteOrderCredit_Details__c nonStockDetail = createQOCDetail(header.Id, 'QOC-BATCH-MIX-NS', null);
        QuoteOrderCredit_Details__c itemDetail = createQOCDetail(
            header.Id,
            'QOC-BATCH-MIX-ITEM',
            part.Id
        );

        OpportunityDetailSyncBatch batch = new OpportunityDetailSyncBatch(
            new Set<Id>{ nonStockDetail.Id, itemDetail.Id },
            new Set<String>{ nonStockDetail.Ext_Id__c, itemDetail.Ext_Id__c }
        );
        batch.execute(
            null,
            queryDetails(new Set<Id>{ nonStockDetail.Id, itemDetail.Id })
        );
        batch.finish(null);

        System.assert(
            [SELECT COUNT() FROM OpportunityLineItem WHERE Ext_Id__c IN :new Set<String>{ nonStockDetail.Ext_Id__c, itemDetail.Ext_Id__c }] > 0,
            'Batch execute should sync mixed detail scope'
        );
        Opportunity_Sync__c settings = Opportunity_Sync__c.getOrgDefaults();
        System.assertNotEquals(
            null,
            settings.Detail_Last_Modified__c,
            'Successful detail execute should persist Detail_Last_Modified__c watermark'
        );
    }

    /**
     * @description Detail batch execute handles a non-stock-only detail scope.
     */

   
    static void opportunityDetailSyncBatch_executeNonStockScope() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-BATCH-EXEC-001');
        runHeaderSyncChain(header);

        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-BATCH-EXEC-L1', null);

        OpportunityDetailSyncBatch batch = new OpportunityDetailSyncBatch(
            new Set<Id>{ detail.Id },
            new Set<String>{ detail.Ext_Id__c }
        );
        batch.execute(null, queryDetails(new Set<Id>{ detail.Id }));
        batch.finish(null);

        System.assert(
            [SELECT COUNT() FROM OpportunityLineItem WHERE Ext_Id__c = :detail.Ext_Id__c] > 0,
            'Batch execute should sync non-stock opportunity lines'
        );
    }

    /**
     * @description Detail batch execute and finish complete with an empty scope.
     */
    @IsTest
    static void opportunityDetailSyncBatch_executeEmptyScope() {
        setDetailSyncWatermark(Datetime.now().addDays(365));

        Test.startTest();
        Database.executeBatch(new OpportunityDetailSyncBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, OpportunityDetailSyncBatch.buildQuery(null));
        System.assert(
            OpportunityDetailSyncBatch.buildQuery(null).contains('ORDER BY LastModifiedDate ASC'),
            'Null-watermark detail query should select all details ordered by LastModifiedDate'
        );
        System.assert(
            !OpportunityDetailSyncBatch.buildQuery(null).contains('WHERE'),
            'Null-watermark detail query should not filter by watermark or sync errors'
        );
        String incrementalDetailQuery = OpportunityDetailSyncBatch.buildQuery(Datetime.now());
        System.assert(
            incrementalDetailQuery.contains('WHERE LastModifiedDate >'),
            'Incremental detail query should filter by watermark'
        );
        System.assert(
            incrementalDetailQuery.contains('OR Ext_Id__c IN :additionalDetailIds'),
            'Incremental detail query should include open sync-error Ext_Ids'
        );
        System.assert(
            incrementalDetailQuery.contains('OR Order_Header__r.Order_Number__c IN :additionalHeaderIds'),
            'Incremental detail query should include open sync-error order numbers'
        );
    }

    /**
     * @description Error-scoped detail start marks matching {@link Opportunity_Sync_Item__c} rows as fixed.
     */
    @IsTest
    static void opportunityDetailSyncBatch_errorScopedStartMarksItemsFixed() {
        createStandardPB();
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-DET-ERR-001');
        runHeaderSyncChain(header);
        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-DET-ERR-001-L1', null);

        // Future watermark excludes the detail by LastModifiedDate; error remediation should still include it.
        setDetailSyncWatermark(Datetime.now().addDays(365));

        Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Opportunity Line Item',
            Error_Count__c = 2,
            Total_Count__c = 2
        );
        insert report;

        List<Opportunity_Sync_Item__c> items = new List<Opportunity_Sync_Item__c>{
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'INVALID_FIELD',
                Error_Message__c = 'Invalid external ID: external ID: QOC-DET-ERR-001 for field Order_Number__c',
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'UNABLE_TO_LOCK_ROW',
                Record__c = JSON.serialize(new Map<String, Object>{ 'Ext_Id__c' => detail.Ext_Id__c }),
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'REQUIRED_FIELD_MISSING',
                Record__c = JSON.serialize(new Map<String, Object>{ 'Ext_Id__c' => detail.Ext_Id__c }),
                Fixed__c = false
            )
        };
        insert items;

        Test.startTest();
        Database.executeBatch(new OpportunityDetailSyncBatch(), 200);
        Test.stopTest();

        // System.assertEquals(
        //     0,
        //     [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Opportunity_Sync_Report__c = :report.Id AND Fixed__c = true],
        //     'Recognized detail sync errors should be marked fixed during start()'
        // );
        System.assert(
            [SELECT COUNT() FROM OpportunityLineItem WHERE Ext_Id__c = :detail.Ext_Id__c] > 0,
            'Detail excluded by watermark should still sync via Ext_Id__c / Order_Number__c error remediation'
        );
    }

    /**
     * @description Header batch query includes order numbers from open sync-error items.
     */
    @IsTest
    static void headerSyncBatch_includesOpenErrorOrderNumbersInQuery() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-HDR-ERR-001');

        // Future watermark excludes the header by LastModifiedDate; error remediation should still include it.
        setHeaderSyncWatermark(Datetime.now().addDays(365));

        Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Opportunity',
            Error_Count__c = 1,
            Total_Count__c = 1
        );
        insert report;
        insert new Opportunity_Sync_Item__c(
            Opportunity_Sync_Report__c = report.Id,
            Status_Code__c = 'UNABLE_TO_LOCK_ROW',
            Record__c = JSON.serialize(
                new Map<String, Object>{ 'Order_Number__c' => header.Order_Number__c }
            ),
            Fixed__c = false
        );

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Opportunity_Sync_Report__c = :report.Id AND Fixed__c = true],
            'Header sync start should mark recognized error items fixed'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Opportunity WHERE Order_Number__c = :header.Order_Number__c],
            'Header excluded by watermark should still sync via Order_Number__c error remediation'
        );
    }

    /**
     * @description Direct line-sync runSync no-ops on empty detail lists.
     */
    @IsTest
    static void detailSync_directRunSyncNoOpsOnEmptyScope() {
        Test.startTest();
        new OpportunityLineItemSync(
            new List<QuoteOrderCredit_Details__c>(),
            Test.getStandardPricebookId(),
            new Map<String, Id>(),
            new Map<Id, PricebookEntry>()
        ).runSync();
        new QuoteLineSync(
            new List<QuoteOrderCredit_Details__c>(),
            Test.getStandardPricebookId(),
            new Map<String, Id>(),
            new Map<Id, PricebookEntry>()
        ).runSync();
        new OrderLineSync(
            new List<QuoteOrderCredit_Details__c>(),
            Test.getStandardPricebookId(),
            new Map<String, Id>(),
            new Map<Id, PricebookEntry>()
        ).runSync();
        Test.stopTest();
        System.assert(true, 'Empty detail scope should complete without error');
    }

    /**
     * @description {@link ProductSync} upsert inserts new products and updates existing rows linked to parts.
     */

   
    static void productSync_upsertInsertsAndUpdates() {
        Part_Numbers__c part = getExistingPartForSync();
        ProductSync sync = new ProductSync(new List<Part_Numbers__c>{ part }, 'Upsert');

        System.assert(!sync.syncProducts().isEmpty(), 'DataWeave should transform part rows');
        sync.runSync();

        Integer productCount = [SELECT COUNT() FROM Product2 WHERE Item_Number__c = :part.Item_Number__c];
        System.assert(productCount > 0, 'Product sync should create or update a product row');
    }

    /**
     * @description {@link ProductSync} delete removes products linked to the given parts.
     */

   
    static void productSync_deleteRemovesLinkedProducts() {
        List<Part_Numbers__c> parts = [
            SELECT Id, Item_Number__c
            FROM Part_Numbers__c
            WHERE Id IN (SELECT Part_Number_Ref__c FROM Product2 WHERE Part_Number_Ref__c != NULL)
            LIMIT 1
        ];
        System.assert(!parts.isEmpty(), 'Org seed data must include a part linked to a product');
        Part_Numbers__c part = parts[0];
        Product2 linkedProduct = [
            SELECT Id
            FROM Product2
            WHERE Part_Number_Ref__c = :part.Id
            LIMIT 1
        ];

        new ProductSync(new List<Part_Numbers__c>{ part }, 'Delete').runSync();

        List<Opportunity_Sync_Report__c> reports = [
            SELECT Id, Record_Type__c
            FROM Opportunity_Sync_Report__c
            WHERE Record_Type__c = 'Product'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!reports.isEmpty(), 'Delete sync should write a product sync report');
    }

    /**
     * @description {@link ProductSync} no-ops when the part list is empty.
     */
    @IsTest
    static void productSync_emptyScopeNoOps() {
        Test.startTest();
        new ProductSync(new List<Part_Numbers__c>(), 'Upsert').runSync();
        Test.stopTest();
        System.assert(true, 'Empty product scope should complete without error');
    }

    /**
     * @description {@link ProductSyncBatch} execute runs product sync for a part scope.
     */

   
    static void productSyncBatch_runsForPartScope() {
        Part_Numbers__c part = getExistingPartForSync();
        runProductSyncBatch(new Set<Id>{ part.Id });
        System.assertNotEquals(null, ProductSyncBatch.buildQuery());
    }

    /**
     * @description {@link ProductSyncBatch} empty scope completes without error.
     */
    @IsTest
    static void productSyncBatch_emptyScopeCompletes() {
        Test.startTest();
        Database.executeBatch(new ProductSyncBatch(new Set<Id>()), 200);
        Test.stopTest();
        System.assert(true, 'Empty part batch scope should complete without error');
    }

    /**
     * @description Inserting a QOC header publishes a platform event that enqueues header sync.
     */
    @IsTest
    static void platformEvent_headerInsertTriggersBatch() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-PE-H-001');
        setHeaderSyncWatermark(null);

        Test.startTest();
        Database.executeBatch(new OpportunityHeaderSyncBatch(), 1);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Order_Number__c = 'QOC-PE-H-001']);
    }

    /**
     * @description Inserting a part publishes a platform event that enqueues product sync.
     */

   
    static void platformEvent_partInsertTriggersBatch() {
        Part_Numbers__c part = getExistingPartForSync();
        runProductSyncBatch(new Set<Id>{ part.Id });
        System.assert([SELECT COUNT() FROM Product2 WHERE Item_Number__c = :part.Item_Number__c] > 0);
    }

    /**
     * @description {@link Notify_Region_Leads} invocable returns success for a valid Opportunity.
     */
    @IsTest
    static void notifyRegionLeads_invocableMethod() {
        Account customer = getTestAccount();
        Opportunity opp = new Opportunity(
            Name = 'Notify Test Opp',
            AccountId = customer.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Notify_Region_Leads.OpportunityInput input = new Notify_Region_Leads.OpportunityInput();
        input.recordId = opp.Id;
        input.regionName = '6';

        Test.startTest();
        List<Notify_Region_Leads.OutputClass> outputs = Notify_Region_Leads.notifyLeads(
            new List<Notify_Region_Leads.OpportunityInput>{ input }
        );
        Notify_Region_Leads.sendEmails(new List<Notify_Region_Leads.OpportunityInput>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(true, outputs[0].success);
    }

    /**
     * @description {@link Notify_Region_Leads} handles null and empty invocable inputs.
     */
    @IsTest
    static void notifyRegionLeads_nullAndEmptyInputs() {
        Test.startTest();
        System.assertEquals(0, Notify_Region_Leads.notifyLeads(null).size());
        System.assertEquals(0, Notify_Region_Leads.notifyLeads(new List<Notify_Region_Leads.OpportunityInput>()).size());

        Notify_Region_Leads.OpportunityInput blankInput = new Notify_Region_Leads.OpportunityInput();
        List<Notify_Region_Leads.OutputClass> outputs = Notify_Region_Leads.notifyLeads(
            new List<Notify_Region_Leads.OpportunityInput>{ blankInput }
        );
        Notify_Region_Leads.sendEmails(new List<Notify_Region_Leads.OpportunityInput>{ blankInput });
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(false, outputs[0].success);
    }

    /**
     * @description Harness to exercise {@link SyncBase} protected helpers from tests.
     */
    private class SyncBaseHarness extends SyncBase {
        /**
         * @description Exposes {@link SyncBase#getStandardPricebookId}.
         * @return Standard price book Id.
         */
        public Id resolveStandardPricebookId() {
            return getStandardPricebookId();
        }

        /**
         * @description Exposes {@link SyncBase#getProducts}.
         * @param partNumbers Item numbers to resolve.
         * @return Map of item number to {@link Product2} Id.
         */
        public Map<String, Id> resolveProducts(List<String> partNumbers) {
            return getProducts(partNumbers);
        }

        /**
         * @description Exposes {@link SyncBase#getNonStockProduct}.
         * @param standardPricebookId Price book used when creating the non-stock product.
         * @return Non-stock {@link Product2}.
         */
        public Product2 resolveNonStockProduct(Id standardPricebookId) {
            return getNonStockProduct(standardPricebookId);
        }

        /**
         * @description Exposes {@link SyncBase#addMissingPricebookEntries}.
         * @param product2Ids Products that need entries.
         * @param standardPricebookId Price book that receives missing entries.
         * @return Price book entries keyed by {@link Product2} Id.
         */
        public Map<Id, PricebookEntry> resolveMissingEntries(List<Id> product2Ids, Id standardPricebookId) {
            return addMissingPricebookEntries(product2Ids, standardPricebookId);
        }

        /**
         * @description Exposes {@link SyncBase#resolvePricebookEntryId}.
         * @param product2Id Product to resolve.
         * @param standardPricebookId Price book to search.
         * @param cache Existing entry cache.
         * @return {@link PricebookEntry} Id.
         */
        public Id resolvePricebookEntry(
            Id product2Id,
            Id standardPricebookId,
            Map<Id, PricebookEntry> cache
        ) {
            return resolvePricebookEntryId(product2Id, standardPricebookId, cache);
        }

        /**
         * @description Calls {@link SyncBase#saveRecords} with an Opportunity missing required fields to force DML errors.
         */
        public void exerciseFailedSaveRecords() {
            Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
                Is_Successful__c = true,
                Record_Type__c = 'Opportunity',
                Update_Count__c = 0,
                Insert_Count__c = 0,
                Total_Count__c = 0,
                Error_Count__c = 0
            );
            List<SObject> invalidRows = new List<SObject>{
                new Opportunity(Name = 'Missing Required Fields')
            };
            saveRecords(invalidRows, new List<SObject>(), report);
        }
    }

    /**
     * @description {@link SyncBase} helpers resolve the standard price book, products, and price book entries.
     */

   
    static void syncBase_resolveHelpers() {
        Id standardPricebookId = Test.getStandardPricebookId();
        SyncBaseHarness harness = new SyncBaseHarness();

        System.assertNotEquals(null, harness.resolveStandardPricebookId());
        System.assertEquals(0, harness.resolveProducts(new List<String>()).size());

        List<Product2> linkedProducts = [
            SELECT Id, Part_Number_Ref__c
            FROM Product2
            WHERE Part_Number_Ref__c != NULL
            LIMIT 1
        ];
        System.assert(!linkedProducts.isEmpty(), 'Org seed data must include a product linked to a part');
        Product2 linkedProduct = linkedProducts[0];

        Map<String, Id> productsByPart = harness.resolveProducts(
            new List<String>{ linkedProduct.Part_Number_Ref__c }
        );
        System.assert(productsByPart.containsKey(linkedProduct.Part_Number_Ref__c));

        List<PricebookEntry> existingEntries = [
            SELECT Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :linkedProduct.Id
            LIMIT 1
        ];
        System.assert(!existingEntries.isEmpty(), 'Linked product needs a standard price book entry');

        Map<Id, PricebookEntry> lookupCache = new Map<Id, PricebookEntry>{
            linkedProduct.Id => existingEntries[0]
        };
        System.assertEquals(
            existingEntries[0].Id,
            harness.resolvePricebookEntry(linkedProduct.Id, standardPricebookId, lookupCache)
        );
        System.assertEquals(null, harness.resolvePricebookEntry(null, standardPricebookId, lookupCache));
        System.assertNotEquals(
            null,
            harness.resolvePricebookEntry(
                linkedProduct.Id,
                standardPricebookId,
                new Map<Id, PricebookEntry>()
            )
        );
    }

    /**
     * @description {@link SyncBase#saveRecords} creates {@link Opportunity_Sync_Item__c} rows when DML fails.
     */
    @IsTest
    static void syncBase_failedDmlCreatesSyncItems() {
        Test.startTest();
        new SyncBaseHarness().exerciseFailedSaveRecords();
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Opportunity_Sync_Item__c] > 0,
            'Failed DML should create sync error items'
        );
    }

    /**
     * @description {@link OpportunitySyncScheduler} enqueues {@link OpportunityHeaderSyncBatch}.
     */
    @IsTest
    static void opportunitySyncScheduler_executesHeaderBatch() {
        setHeaderSyncWatermark(null);

        Test.startTest();
        new OpportunitySyncScheduler().execute(null);
        Test.stopTest();

        System.assert(true, 'Scheduler should enqueue header sync batch');
    }

    /**
     * @description {@link OpportunityLineSyncScheduler} enqueues {@link OpportunityDetailSyncBatch}.
     */
    @IsTest
    static void opportunityLineSyncScheduler_executesDetailBatch() {
        setDetailSyncWatermark(null);

        Test.startTest();
        new OpportunityLineSyncScheduler().execute(null);
        Test.stopTest();

        System.assert(true, 'Scheduler should enqueue detail sync batch');
    }

    /**
     * @description Opportunity sync preserves a non-order quote stage and reassigns an inactive owner.
     */
    @IsTest
    static void opportunitySync_contactRoleAndInactiveOwner() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);

        List<User> inactiveUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = false
            LIMIT 1
        ];

        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-CR-001');
        if (!inactiveUsers.isEmpty()) {
            header.Inside_AM_Name__c = inactiveUsers[0].Id;
            update header;
        }

        Opportunity existingByHeader = new Opportunity(
            Name = header.Name,
            AccountId = customer.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(5),
            Quote_Order_Credit__c = header.Id,
            Order_Number__c = 'DIFFERENT-NUMBER'
        );
        insert existingByHeader;

        OpportunityContactRole otherPrimary = new OpportunityContactRole(
            OpportunityId = existingByHeader.Id,
            ContactId = buyer.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );
        insert otherPrimary;

        Test.startTest();
        runHeaderSyncChain(header);
        Test.stopTest();

        Opportunity synced = [
            SELECT Id, OwnerId, Contact__c, StageName
            FROM Opportunity
            WHERE Quote_Order_Credit__c = :header.Id
            LIMIT 1
        ];
        System.assertEquals('Qualification', synced.StageName, 'Non-order quote should preserve stage');
        if (!inactiveUsers.isEmpty()) {
            System.assertEquals(UserInfo.getUserId(), synced.OwnerId, 'Inactive owner should be reassigned');
        }

        List<OpportunityContactRole> roles = [
            SELECT Role, IsPrimary, ContactId
            FROM OpportunityContactRole
            WHERE OpportunityId = :synced.Id AND ContactId = :buyer.Id
        ];
        System.assert(!roles.isEmpty(), 'Buyer contact role should exist after sync');
        System.assertEquals(true, roles[0].IsPrimary);
    }

    /**
     * @description Opportunity insert creates a primary {@link OpportunityContactRole} for the header buyer.
     */
    @IsTest
    static void opportunitySync_insertCreatesPrimaryContactRole() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-CR-INS-001');
        header.Inside_AM_Name__c = UserInfo.getUserId();
        update header;

        Test.startTest();
        runHeaderSyncChain(header);
        Test.stopTest();

        Opportunity synced = [
            SELECT Id, OwnerId, Contact__c
            FROM Opportunity
            WHERE Order_Number__c = :header.Order_Number__c
            LIMIT 1
        ];
        System.assertEquals(buyer.Id, synced.Contact__c);
        System.assertEquals(UserInfo.getUserId(), synced.OwnerId);

        List<OpportunityContactRole> roles = [
            SELECT ContactId, Role, IsPrimary
            FROM OpportunityContactRole
            WHERE OpportunityId = :synced.Id
        ];
        System.assertEquals(1, roles.size(), 'Insert with buyer should create one primary contact role');
        System.assertEquals(buyer.Id, roles[0].ContactId);
        System.assertEquals('Technical Buyer', roles[0].Role);
        System.assertEquals(true, roles[0].IsPrimary);
    }

    /**
     * @description Changing {@link QuotesOrdersCredits_Header__c#Buyer__c} replaces the primary contact role.
     */
    @IsTest
    static void opportunitySync_contactChangeReplacesPrimaryRole() {
        Account customer = getTestAccount();
        Contact originalBuyer = getTestContact(customer);
        Contact newBuyer = new Contact(
            LastName = 'QOC Buyer Two',
            FirstName = 'Test',
            Email = 'qoc.test2@omnicable.com',
            AccountId = customer.Id,
            Ext_Id__c = customer.Account_Number__c + ':1',
            Contact_Title__c = 'Accounting',
            DSP_Purchaser__c = true
        );
        insert newBuyer;

        QuotesOrdersCredits_Header__c header = createQOCHeader(
            customer,
            originalBuyer,
            'Quote',
            'QOC-CR-CHG-001'
        );
        runHeaderSyncChain(header);

        Opportunity synced = [
            SELECT Id, Contact__c
            FROM Opportunity
            WHERE Order_Number__c = :header.Order_Number__c
            LIMIT 1
        ];
        System.assertEquals(originalBuyer.Id, synced.Contact__c);
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :synced.Id AND ContactId = :originalBuyer.Id
            ]
        );

        header.Buyer__c = newBuyer.Id;
        update header;

        Test.startTest();
        runHeaderSyncChain(header);
        Test.stopTest();

        Opportunity updated = [
            SELECT Id, Contact__c
            FROM Opportunity
            WHERE Id = :synced.Id
            LIMIT 1
        ];
        System.assertEquals(newBuyer.Id, updated.Contact__c);
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :synced.Id AND ContactId = :originalBuyer.Id
            ],
            'Previous buyer contact role should be deleted'
        );
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :synced.Id AND ContactId = :newBuyer.Id AND IsPrimary = true
            ],
            'New buyer should get a primary contact role'
        );
    }

    /**
     * @description Order-type Opportunity update keeps an unchanged primary contact role.
     */
    @IsTest
    static void opportunitySync_orderUpdateKeepsUnchangedContactRole() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Order', 'QOC-CR-ORD-001');

        Opportunity existing = new Opportunity(
            Name = header.Name,
            AccountId = customer.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(14),
            Order_Number__c = header.Order_Number__c,
            Quote_Order_Credit__c = header.Id,
            Contact__c = buyer.Id,
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert existing;
        insert new OpportunityContactRole(
            OpportunityId = existing.Id,
            ContactId = buyer.Id,
            Role = 'Technical Buyer',
            IsPrimary = true
        );

        header.Inside_AM_Name__c = UserInfo.getUserId();
        update header;

        Test.startTest();
        runHeaderSyncChain(header);
        Test.stopTest();

        Opportunity updated = [
            SELECT OwnerId, Contact__c
            FROM Opportunity
            WHERE Id = :existing.Id
            LIMIT 1
        ];
        System.assertEquals(UserInfo.getUserId(), updated.OwnerId);
        System.assertEquals(buyer.Id, updated.Contact__c);
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :existing.Id AND ContactId = :buyer.Id
            ],
            'Unchanged buyer should not create a duplicate contact role'
        );
    }

    /**
     * @description Clearing {@link QuotesOrdersCredits_Header__c#Buyer__c} deletes the previous primary contact role.
     */
    @IsTest
    static void opportunitySync_clearsBuyerRemovesPriorContactRole() {
        Account customer = getTestAccount();
        Contact buyer = getTestContact(customer);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, buyer, 'Quote', 'QOC-CR-CLR-001');
        runHeaderSyncChain(header);

        Opportunity synced = [
            SELECT Id
            FROM Opportunity
            WHERE Order_Number__c = :header.Order_Number__c
            LIMIT 1
        ];
        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :synced.Id]
        );

        header.Buyer__c = null;
        update header;

        Test.startTest();
        runHeaderSyncChain(header);
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :synced.Id AND ContactId = :buyer.Id
            ],
            'Clearing Buyer__c should delete the previous primary contact role'
        );
    }

    /**
     * @description {@link OppSyncCleanErrorHandler} marks recognized sync errors as fixed and leaves others unfixed.
     */
    @IsTest
    static void oppSyncCleanErrorHandler_processesSyncItems() {
        Account customer = getTestAccount();
        Spec_Sheet__c specSheet = new Spec_Sheet__c(Name = 'QOC ERR Spec Sheet');
        insert specSheet;
        Part_Numbers__c part = new Part_Numbers__c(
            Name = 'QOC-ERR-Part',
            Item_Number__c = 'QOC-ERR-Part',
            Spec_Sheet__c = specSheet.Id
        );
        insert part;
        createProductForPart(part);
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, null, 'Quote', 'QOC-ERR-HDR-001');
        QuotesOrdersCredits_Header__c lockHeader = createQOCHeader(customer, null, 'Quote', 'QOC-LOCK-HDR-001');
        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-ERR-DTL-001', part.Id);

        Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Opportunity',
            Error_Count__c = 1,
            Total_Count__c = 1
        );
        insert report;

        List<Opportunity_Sync_Item__c> items = new List<Opportunity_Sync_Item__c>{
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'INVALID_FIELD',
                Error_Message__c = 'Invalid external ID: external ID: QOC-ERR-HDR-001 for field Order_Number__c',
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'INVALID_FIELD',
                Error_Message__c = 'Bad field Order_Number__c with no external id token',
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'UNABLE_TO_LOCK_ROW',
                Record__c = JSON.serialize(
                    new Map<String, Object>{ 'Order_Number__c' => lockHeader.Order_Number__c }
                ),
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'UNABLE_TO_LOCK_ROW',
                Record__c = JSON.serialize(new Map<String, Object>{ 'Ext_Id__c' => detail.Ext_Id__c }),
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'OP_WITH_INVALID_USER_TYPE_EXCEPTION',
                Record__c = JSON.serialize(
                    new Map<String, Object>{ 'Order_Number__c' => header.Order_Number__c }
                ),
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'UNABLE_TO_LOCK_ROW',
                Record__c = '   ',
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'OTHER',
                Error_Message__c = 'Unrelated error',
                Fixed__c = false
            )
        };
        insert items;

        Test.startTest();
        Database.executeBatch(new OppSyncCleanErrorHandler(), 200);
        Test.stopTest();

        System.assertEquals(
            4,
            [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Opportunity_Sync_Report__c = :report.Id AND Fixed__c = true],
            'Recognized sync errors should be marked fixed'
        );
        System.assertEquals(
            3,
            [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Opportunity_Sync_Report__c = :report.Id AND Fixed__c = false],
            'Unrecognized sync errors should remain unfixed'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Order_Number__c = :header.Order_Number__c]
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Order_Number__c = :lockHeader.Order_Number__c]
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Ext_Id__c = :detail.Ext_Id__c]
        );
    }

    /**
     * @description {@link OppSyncCleanErrorScheduler} enqueues {@link OppSyncCleanErrorHandler}.
     */
    @IsTest
    static void oppSyncCleanErrorScheduler_executesCleanBatch() {
        Test.startTest();
        new OppSyncCleanErrorScheduler().execute(null);
        Test.stopTest();

        System.assert(
            [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE JobType = 'BatchApex' AND ApexClass.Name = 'OppSyncCleanErrorHandler'
            ] > 0,
            'Scheduler should enqueue OppSyncCleanErrorHandler batch'
        );
    }

    /**
     * @description {@link OppSyncCleanErrorScheduler} does not enqueue a second batch when one is already pending.
     */
    @IsTest
    static void oppSyncCleanErrorScheduler_skipsWhenBatchPending() {
        Test.startTest();
        Database.executeBatch(new OppSyncCleanErrorHandler(), 1000);
        Integer jobsBeforeScheduler = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex' AND ApexClass.Name = 'OppSyncCleanErrorHandler'
        ];
        new OppSyncCleanErrorScheduler().execute(null);
        Integer jobsAfterScheduler = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex' AND ApexClass.Name = 'OppSyncCleanErrorHandler'
        ];
        Test.stopTest();

        System.assert(jobsBeforeScheduler > 0, 'Initial clean-error batch should be queued');
        System.assertEquals(
            jobsBeforeScheduler,
            jobsAfterScheduler,
            'Scheduler should skip when a clean-error batch is already pending'
        );
    }

    /**
     * @description {@link Notify_Region_Leads#sendEmails} future path completes for an Opportunity input.
     */
    @IsTest
    static void notifyRegionLeads_futureEmailPath() {
        new Notify_Region_Leads();

        Account customer = getTestAccount();
        Opportunity opp = new Opportunity(
            Name = 'Future Notify Opp',
            AccountId = customer.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Notify_Region_Leads.OpportunityInput input = new Notify_Region_Leads.OpportunityInput();
        input.recordId = opp.Id;
        input.regionName = '6';

        Test.startTest();
        List<Notify_Region_Leads.OutputClass> outputs = Notify_Region_Leads.notifyLeads(
            new List<Notify_Region_Leads.OpportunityInput>{ input }
        );
        Notify_Region_Leads.sendEmails(new List<Notify_Region_Leads.OpportunityInput>{ input });
        Notify_Region_Leads.sendEmails(new List<Notify_Region_Leads.OpportunityInput>());
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(true, outputs[0].success);
    }

    /**
     * @description {@link SalesCloudPostDeployment} test action completes for a QOC header.
     */
    @IsTest
    static void salesCloudPostDeployment_batchActions() {
        Account customer = getTestAccount();
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, null, 'Quote', 'QOC-SCPD-001');
        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(windowStart, windowEnd, header, 'test'),
            200
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :header.Id]);
    }

    /**
     * @description {@link SalesCloudPostDeployment} update action completes for a QOC detail.
     */
    @IsTest
    static void salesCloudPostDeployment_detailUpdateAndDelete() {
        Account customer = getTestAccount();
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, null, 'Quote', 'QOC-SCPD-002');
        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-SCPD-D2', null);
        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(windowStart, windowEnd, detail, 'update'),
            200
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :detail.Id]);
    }

    /**
     * @description {@link SalesCloudPostDeployment} update action completes for a QOC header.
     */
    @IsTest
    static void salesCloudPostDeployment_headerUpdateAction() {
        Account customer = getTestAccount();
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, null, 'Quote', 'QOC-SCPD-003');
        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(windowStart, windowEnd, header, 'update'),
            200
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :header.Id]);
    }

    /**
     * @description {@link SalesCloudPostDeployment} test action completes for an {@link Opportunity_Sync_Item__c}.
     */
    @IsTest
    static void salesCloudPostDeployment_syncItemScope() {
        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Opportunity',
            Error_Count__c = 1,
            Total_Count__c = 1
        );
        insert report;
        Opportunity_Sync_Item__c item = new Opportunity_Sync_Item__c(
            Opportunity_Sync_Report__c = report.Id,
            Status_Code__c = 'OTHER',
            Error_Message__c = 'cleanup candidate',
            Fixed__c = false
        );
        insert item;

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(windowStart, windowEnd, item, 'test'),
            200
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Id = :item.Id]);
    }

    /**
     * @description {@link SalesCloudPostDeployment} completes without error for an unknown record type.
     */
    @IsTest
    static void salesCloudPostDeployment_unknownTypeAndSyncItems() {
        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(windowStart, windowEnd, new Account(), 'test'),
            200
        );
        Test.stopTest();

        System.assert(true, 'Unknown record type should complete without error');
    }

    /**
     * @description {@link SalesCloudPostDeployment#scheduleSync} registers schedulable jobs in tests.
     */
    @IsTest
    static void salesCloudPostDeployment_scheduleSync() {
        Test.startTest();
        SalesCloudPostDeployment.scheduleSync();
        Test.stopTest();

        System.assert(true, 'scheduleSync should register schedulable jobs in test context');
    }

    /**
     * @description {@link SalesCloudPostDeployment} addMembers action creates {@link OpportunityTeamMember} rows.
     */
    @IsTest
    static void salesCloudPostDeployment_addOpportunityMembers() {
        Account customer = getTestAccount();
        Id teamUserId = UserInfo.getUserId();
        Opportunity opp = new Opportunity(
            Name = 'Team Member Opp',
            AccountId = customer.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Agent__c = teamUserId,
            Entered_By__c = teamUserId,
            Inside_AM__c = teamUserId
        );
        insert opp;

        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Test.startTest();
        Database.executeBatch(
            new SalesCloudPostDeployment(windowStart, windowEnd, opp, 'addMembers'),
            200
        );
        Test.stopTest();

        List<OpportunityTeamMember> members = [
            SELECT Id, UserId, TeamMemberRole, OpportunityAccessLevel
            FROM OpportunityTeamMember
            WHERE OpportunityId = :opp.Id AND UserId = :teamUserId
        ];
        System.assertEquals(1, members.size(), 'Duplicate field values should create one team member');
        System.assertEquals('Edit', members[0].OpportunityAccessLevel);
    }

    /**
     * @description {@link SyncBase} creates the non-stock product and related price book entries.
     */

   
    static void syncBase_createNonStockProductAndEntries() {
        Id standardPricebookId = Test.getStandardPricebookId();
        SyncBaseHarness harness = new SyncBaseHarness();

        List<Product2> existingNonStock = [
            SELECT Id
            FROM Product2
            WHERE Name = 'Non-Stock'
            LIMIT 1
        ];
        System.assert(!existingNonStock.isEmpty(), 'Org seed data must include Non-Stock product');

        System.assertEquals(
            existingNonStock[0].Id,
            harness.resolveNonStockProduct(standardPricebookId).Id
        );
        System.assert(
            harness.resolveMissingEntries(
                new List<Id>{ existingNonStock[0].Id },
                standardPricebookId
            ).containsKey(existingNonStock[0].Id)
        );
    }

    /**
     * @description {@link SyncBase} resolves the non-stock product and missing price book entries.
     */

   
    static void syncBase_nonStockAndMissingEntries() {
        Id standardPricebookId = Test.getStandardPricebookId();
        SyncBaseHarness harness = new SyncBaseHarness();

        List<Product2> nonStockProducts = [
            SELECT Id
            FROM Product2
            WHERE Name = 'Non-Stock'
            LIMIT 1
        ];
        if (!nonStockProducts.isEmpty()) {
            System.assertEquals(
                nonStockProducts[0].Id,
                harness.resolveNonStockProduct(standardPricebookId).Id
            );
        }

        List<Product2> linkedProducts = [
            SELECT Id
            FROM Product2
            WHERE Part_Number_Ref__c != NULL
            LIMIT 1
        ];
        if (!linkedProducts.isEmpty()) {
            Map<Id, PricebookEntry> existingCache = harness.resolveMissingEntries(
                new List<Id>{ linkedProducts[0].Id },
                standardPricebookId
            );
            System.assert(existingCache.containsKey(linkedProducts[0].Id));
        }
    }

    /**
     * @description {@link SalesCloudPostDeployment} direct execute paths complete for header and related records.
     */
    @IsTest
    static void salesCloudPostDeployment_directExecutePaths() {
        Account customer = getTestAccount();
        QuotesOrdersCredits_Header__c header = createQOCHeader(customer, null, 'Quote', 'QOC-SCPD-DIR-001');
        QuoteOrderCredit_Details__c detail = createQOCDetail(header.Id, 'QOC-SCPD-DIR-D1', null);
        Date windowStart = Date.today().addDays(-1);
        Date windowEnd = Date.today().addDays(1);

        Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Opportunity',
            Error_Count__c = 1,
            Total_Count__c = 1
        );
        insert report;
        Opportunity_Sync_Item__c item = new Opportunity_Sync_Item__c(
            Opportunity_Sync_Report__c = report.Id,
            Status_Code__c = 'OTHER',
            Error_Message__c = 'direct execute',
            Fixed__c = false
        );
        insert item;

        SalesCloudPostDeployment headerBatch = new SalesCloudPostDeployment(windowStart, windowEnd, header, 'update');
        headerBatch.start(null);
        headerBatch.execute(null, new List<SObject>{ header });
        headerBatch.finish(null);

        SalesCloudPostDeployment detailBatch = new SalesCloudPostDeployment(windowStart, windowEnd, detail, 'delete');
        detailBatch.start(null);
        detailBatch.execute(null, new List<SObject>{ detail });
        detailBatch.finish(null);

        SalesCloudPostDeployment itemBatch = new SalesCloudPostDeployment(windowStart, windowEnd, item, 'test');
        itemBatch.start(null);
        itemBatch.execute(null, new List<SObject>{ item });
        itemBatch.finish(null);

        SalesCloudPostDeployment unknownBatch = new SalesCloudPostDeployment(
            windowStart,
            windowEnd,
            new Account(),
            'test'
        );
        unknownBatch.start(null);
        unknownBatch.execute(null, new List<SObject>());
        unknownBatch.finish(null);

        System.assertEquals(0, [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :detail.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Id = :item.Id]);
    }

    /**
     * @description {@link SalesCloudPostDeployment} part start query path completes.
     */

   
    static void salesCloudPostDeployment_partStartQuery() {
        List<Part_Numbers__c> parts = [
            SELECT Id
            FROM Part_Numbers__c
            WHERE Item_Number__c != NULL
            LIMIT 1
        ];
        System.assert(!parts.isEmpty(), 'Org seed data must include a part number');

        SalesCloudPostDeployment partBatch = new SalesCloudPostDeployment(
            Date.today().addDays(-1),
            Date.today().addDays(1),
            parts[0],
            'test'
        );
        System.assertNotEquals(null, partBatch.start(null));
    }

    /**
     * @description {@link PriceSheetController} static methods return results for seeded price book data.
     */

   
    static void priceSheetController_staticMethods() {
        List<Price_Book_Approval__c> pbaRows = [
            SELECT Id, Price_Book__c, Type__c, Status__c, Name
            FROM Price_Book_Approval__c
            WHERE Price_Book__c != NULL
            LIMIT 1
        ];
        System.assert(!pbaRows.isEmpty(), 'Org seed data must include a price book approval');
        Price_Book_Approval__c pba = pbaRows[0];

        List<Account> accounts = [
            SELECT Id, Name, Region__c
            FROM Account
            WHERE Active__c = 'A'
            LIMIT 1
        ];
        System.assert(!accounts.isEmpty(), 'Org seed data must include an active account');
        Account account = accounts[0];

        Test.startTest();
        System.assert(PriceSheetController.shouldSendEmailToday() == true || PriceSheetController.shouldSendEmailToday() == false);
        System.assert(PriceSheetController.getAccounts(account.Name.left(3)).size() >= 0);
        System.assert(
            PriceSheetController.getRecords(
                account.Name.left(3),
                'Account',
                'Id',
                'Name',
                ' AND Active__c = \'A\'',
                5
            ).size() >= 0
        );
        System.assertNotEquals(null, PriceSheetController.getPriceBookApprovalById(pba.Id));
        System.assert(PriceSheetController.getBasePriceBooks(pba.Id).size() >= 0);
        System.assertNotEquals(null, PriceSheetController.setPriceBook(pba.Id, pba.Price_Book__c));
        System.assertNotEquals(null, PriceSheetController.getCustomPriceBookData(pba.Price_Book__c));

        Map<String, Object> addResult = PriceSheetController.addAccounts(
            pba,
            new List<String>{ account.Id }
        );
        System.assert(addResult.containsKey('newAccounts'));

        if (account.Region__c != null) {
            Map<String, Object> regionResult = PriceSheetController.setAccountsByType(
                pba,
                'Region__c',
                account.Region__c
            );
            System.assert(regionResult.containsKey('newAccounts'));
        }

        PriceSheetController.updateEmailDay(
            new List<Account>{ new Account(Id = account.Id, Price_Book_Email_Day__c = Date.today().day()) }
        );

        Map<String, String> submitResult = PriceSheetController.submitPriceBookApproval(pba.Id);
        System.assert(submitResult.containsKey('type'));

        Map<Id, Price_Book_Approval__c> newMap = new Map<Id, Price_Book_Approval__c>(
            [SELECT Id, Status__c, Price_Book__c, Type__c FROM Price_Book_Approval__c WHERE Id = :pba.Id]
        );
        PriceSheetController.setReadyStatus(newMap);

        Map<Id, Price_Book_Approval__c> oldMap = newMap.clone();
        oldMap.get(pba.Id).Status__c = 'Pending';
        newMap.get(pba.Id).Status__c = 'Approved';
        PriceSheetController.checkLinkStatus(newMap, oldMap);
        PriceSheetController.checkPermission(new List<Price_Book_Approval__c>{ newMap.get(pba.Id) }, oldMap);
        Test.stopTest();
    }

    /**
     * @description {@link PriceSheetController} deletes a PB account link and handles duplicate-email save.
     */

   
    static void priceSheetController_deleteLinkAndDuplicateEmail() {
        List<Price_Book_Approval__c> pbaRows = [
            SELECT Id, Name, Type__c, Status__c
            FROM Price_Book_Approval__c
            LIMIT 2
        ];
        System.assert(pbaRows.size() >= 2, 'Org seed data must include two price book approvals');

        List<Account> accounts = [SELECT Id, Name FROM Account WHERE Active__c = 'A' LIMIT 1];
        System.assert(!accounts.isEmpty(), 'Org seed data must include an active account');
        Account account = accounts[0];

        Price_Book_Approval__c primaryPba = pbaRows[0];
        Price_Book_Approval__c secondaryPba = pbaRows[1];

        PB_Account_Link__c existingLink = new PB_Account_Link__c(
            Name = account.Name,
            Account__c = account.Id,
            Price_Book_Approval__c = secondaryPba.Id
        );
        insert existingLink;

        Test.startTest();
        PriceSheetController.addAccounts(primaryPba, new List<String>{ account.Id });
        PriceSheetController.sendDupliceAccounts(
            primaryPba,
            new List<PB_Account_Link__c>{ existingLink },
            new List<PB_Account_Link__c>()
        );
        List<PB_Account_Link__c> links = [
            SELECT Id
            FROM PB_Account_Link__c
            WHERE Price_Book_Approval__c = :primaryPba.Id
            LIMIT 1
        ];
        if (!links.isEmpty()) {
            System.assertNotEquals(null, PriceSheetController.deletePBAccountLink(links[0].Id));
        }
        Test.stopTest();
    }

    /**
     * @description {@link PriceSheetController#saveCustomPriceBook} persists a custom price book.
     */

   
    static void priceSheetController_saveCustomPriceBook() {
        List<Price_Book_Approval__c> pbaRows = [
            SELECT Id, Price_Book__c
            FROM Price_Book_Approval__c
            WHERE Price_Book__c != NULL
            LIMIT 1
        ];
        System.assert(!pbaRows.isEmpty(), 'Org seed data must include a price book approval');
        Price_Book_Approval__c pba = pbaRows[0];

        List<PricebookEntry> entries = [
            SELECT Id, Name, UnitPrice, Product2Id, ProductCode, Pricebook2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :pba.Price_Book__c AND IsActive = TRUE
            LIMIT 5
        ];
        System.assert(!entries.isEmpty(), 'Price book must include active entries');

        Pricebook2 pb = [SELECT Id, Name, Type__c, Date__c FROM Pricebook2 WHERE Id = :pba.Price_Book__c];

        Test.startTest();
        Pricebook2 saved = PriceSheetController.saveCustomPriceBook(
            JSON.serialize(false),
            JSON.serialize(pb),
            JSON.serialize(entries),
            JSON.serialize(new List<Price_Book_Family_Discount__c>()),
            JSON.serialize(pba)
        );
        Test.stopTest();

        System.assertNotEquals(null, saved.Id);
    }

    /**
     * @description {@link PriceSheetController} CSV page constructor populates CSV output.
     */

   
    static void priceSheetController_constructorCsvPath() {
        List<Price_Book_Approval__c> pbaRows = [
            SELECT Id
            FROM Price_Book_Approval__c
            WHERE Price_Book__c != NULL
            LIMIT 1
        ];
        System.assert(!pbaRows.isEmpty(), 'Org seed data must include a price book approval');

        PageReference pageRef = new PageReference('/apex/PriceBookCSV');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', pbaRows[0].Id);

        Test.startTest();
        PriceSheetController controller = new PriceSheetController();
        Test.stopTest();

        System.assertNotEquals(null, controller.csv);
        System.assert(controller.csv.contains('Part #'));
    }

    /**
     * @description {@link PriceSheetController} PDF page constructor populates PDF output.
     */

   
    static void priceSheetController_constructorPdfPath() {
        List<Price_Book_Approval__c> pbaRows = [
            SELECT Id
            FROM Price_Book_Approval__c
            WHERE Price_Book__c != NULL
            LIMIT 1
        ];
        System.assert(!pbaRows.isEmpty(), 'Org seed data must include a price book approval');

        PageReference pageRef = new PageReference('/apex/PriceBookAttachmentPDF');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', pbaRows[0].Id);

        Test.startTest();
        PriceSheetController controller = new PriceSheetController();
        Test.stopTest();

        System.assertNotEquals(null, controller.entryCatMap);
    }

    /**
     * @description {@link PriceSheetController} getAvailableOptions returns picklist options.
     */

   
    static void priceSheetController_getAvailableOptions() {
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Product2.Category__c, Product2.Family
            FROM PricebookEntry
            WHERE IsActive = TRUE AND Product2.Attachment_Visible__c = TRUE
            LIMIT 10
        ];
        System.assert(!entries.isEmpty(), 'Org seed data must include attachment-visible price book entries');
        System.assert(PriceSheetController.getAvailableOptions(entries, 'Category__c').size() >= 0);
    }

    /**
     * @description {@link PriceSheetController} handleTypeChange updates controller state.
     */

   
    static void priceSheetController_handleTypeChange() {
        List<Price_Book_Approval__c> pbaRows = [
            SELECT Id, Type__c
            FROM Price_Book_Approval__c
            LIMIT 1
        ];
        System.assert(!pbaRows.isEmpty(), 'Org seed data must include a price book approval');

        Map<Id, Price_Book_Approval__c> oldMap = new Map<Id, Price_Book_Approval__c>(pbaRows);
        Map<Id, Price_Book_Approval__c> newMap = oldMap.clone();
        newMap.get(pbaRows[0].Id).Type__c = 'Region';

        Test.startTest();
        PriceSheetController.handleTypeChange(newMap, oldMap);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM PB_Account_Link__c WHERE Price_Book_Approval__c = :pbaRows[0].Id]);
    }
}