/**
 * @description Tests for {@link InvoiceBatchUpdate}.
 */
@IsTest
private class InvoiceBatchUpdateTest {
    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    private static SalesHistory__c newSalesHistory(Account acct, Date invoiceDate) {
        return new SalesHistory__c(
            Name = 'INV-' + uniqueSuffix(),
            Customer__c = acct.Id,
            Invoice_Date__c = invoiceDate
        );
    }

    private static Id quotesHeaderRecordTypeId() {
        return Schema.SObjectType.QuotesOrdersCredits_Header__c.getRecordTypeInfosByDeveloperName()
            .get('Quotes')
            .getRecordTypeId();
    }

    private static Id quoteDetailStandardRecordTypeId() {
        return Schema.SObjectType.QuoteOrderCredit_Details__c.getRecordTypeInfosByDeveloperName()
            .get('Standard')
            .getRecordTypeId();
    }

    private static Id standardPricebookId() {
        return Test.getStandardPricebookId();
    }

    private static PricebookEntry newActivePricebookEntry() {
        // Make the standard pricebook queryable for Product2Trigger / PriceSheetController.
        update new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);

        Product2 product = new Product2(
            Name = 'Prod-' + uniqueSuffix(),
            ProductCode = 'PC-' + uniqueSuffix(),
            Family = 'Family',
            Category__c = 'Category',
            Unit_Price__c = 100,
            IsActive = true
        );
        insert product;

        Id stdPbId = Test.getStandardPricebookId();
        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :product.Id AND Pricebook2Id = :stdPbId
            LIMIT 1
        ];
        if (!entries.isEmpty()) {
            return entries[0];
        }

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = product.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert entry;
        return entry;
    }

    private static void assertJobCompleted(Id jobId) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void executeBatch_deletesSalesHistory_inDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        SalesHistory__c inRange = newSalesHistory(acct, startDate.addDays(1));
        SalesHistory__c outOfRange = newSalesHistory(acct, startDate.addDays(-1));
        insert new List<SalesHistory__c>{ inRange, outOfRange };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new SalesHistory__c(), 'delete'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
        System.assertEquals(0, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :inRange.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :outOfRange.Id]);
    }

    @IsTest
    static void executeBatch_update_actionUpdatesSalesHistory() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        SalesHistory__c inRange = newSalesHistory(acct, startDate.addDays(1));
        insert inRange;

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new SalesHistory__c(), 'update'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
        System.assertEquals(1, [SELECT COUNT() FROM SalesHistory__c WHERE Id = :inRange.Id]);
    }

    @IsTest
    static void executeBatch_opportunityAmount_updatesQuoteDetails() {
        String orderNum = 'ORD-' + uniqueSuffix();
        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        QuotesOrdersCredits_Header__c hdr = new QuotesOrdersCredits_Header__c(
            Name = 'Hdr-' + uniqueSuffix(),
            Customer__c = acct.Id,
            Order_Number__c = orderNum,
            RecordTypeId = quotesHeaderRecordTypeId(),
            Total_Order_Sales__c = 100
        );
        insert hdr;

        QuoteOrderCredit_Details__c detail = new QuoteOrderCredit_Details__c(
            Name = 'Det-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId(),
            Dollars__c = 100,
            QTY_Ordered__c = 1
        );
        insert detail;

        Opportunity opp = new Opportunity(
            Name = 'Opp-' + uniqueSuffix(),
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Order_Number__c = orderNum
        );
        insert opp;

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(null, null, new Opportunity(), 'OPPORTUNITY_AMOUNT'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
        System.assertEquals(1, [SELECT COUNT() FROM QuoteOrderCredit_Details__c WHERE Id = :detail.Id]);
    }

    @IsTest
    static void executeBatch_deletesLines_inDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;
        SalesHistory__c inRangeHdr = newSalesHistory(acct, startDate.addDays(1));
        SalesHistory__c outOfRangeHdr = newSalesHistory(acct, startDate.addDays(-1));
        insert new List<SalesHistory__c>{ inRangeHdr, outOfRangeHdr };

        Sales_History_Line_Item__c inRange = new Sales_History_Line_Item__c(
            Name = 'Line-In',
            Sales_History__c = inRangeHdr.Id
        );
        Sales_History_Line_Item__c outOfRange = new Sales_History_Line_Item__c(
            Name = 'Line-Out',
            Sales_History__c = outOfRangeHdr.Id
        );
        insert new List<Sales_History_Line_Item__c>{ inRange, outOfRange };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new Sales_History_Line_Item__c(), 'delete'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Sales_History_Line_Item__c WHERE Id IN :new List<Id>{ inRange.Id, outOfRange.Id }],
            'Only out-of-range rows should remain'
        );
        System.assertEquals(0, [SELECT COUNT() FROM Sales_History_Line_Item__c WHERE Id = :inRange.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Sales_History_Line_Item__c WHERE Id = :outOfRange.Id]);
    }

    @IsTest
    static void executeBatch_noOpForUnsupportedRecordType() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new Account(), 'test'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void executeBatch_deletesQocHeaders_inCreatedDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        QuotesOrdersCredits_Header__c inRange = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-' + uniqueSuffix(),
            Customer__c = acct.Id
        );
        QuotesOrdersCredits_Header__c outOfRange = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-' + uniqueSuffix(),
            Customer__c = acct.Id
        );
        insert new List<QuotesOrdersCredits_Header__c>{ inRange, outOfRange };

        // CreatedDate can't be set directly, but we need deterministic in/out-of-range rows.
        Test.setCreatedDate(inRange.Id, DateTime.newInstance(startDate.addDays(1), Time.newInstance(12, 0, 0, 0)));
        Test.setCreatedDate(outOfRange.Id, DateTime.newInstance(startDate.addDays(-1), Time.newInstance(12, 0, 0, 0)));

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new QuotesOrdersCredits_Header__c(), 'delete'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

        System.assertEquals(0, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :inRange.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM QuotesOrdersCredits_Header__c WHERE Id = :outOfRange.Id]);
    }

    @IsTest
    static void executeBatch_totalSalesUpdate_copiesTotalOrderSales() {
        Account rewardsAcct = new Account(
            Name = 'Acct-Rewards-' + uniqueSuffix(),
            OCC_Rewards__c = true
        );
        insert rewardsAcct;

        Decimal salesAmount = 1234.56;

        QuotesOrdersCredits_Header__c eligible = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-Eligible-' + uniqueSuffix(),
            Customer__c = rewardsAcct.Id,
            Total_Order_Sales__c = salesAmount
        );
        QuotesOrdersCredits_Header__c alreadyPopulated = new QuotesOrdersCredits_Header__c(
            Name = 'QOC-Populated-' + uniqueSuffix(),
            Customer__c = rewardsAcct.Id,
            Total_Order_Sales__c = salesAmount,
            New_Total_Order_Sales__c = 99.99
        );
        insert new List<QuotesOrdersCredits_Header__c>{ eligible, alreadyPopulated };

        List<QuotesOrdersCredits_Header__c> scope = [
            SELECT Id, New_Total_Order_Sales__c, Total_Order_Sales__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id IN :new Set<Id>{ eligible.Id, alreadyPopulated.Id }
        ];

        Test.startTest();
        new InvoiceBatchUpdate(null, null, new QuotesOrdersCredits_Header__c(), 'Total Sales Update')
            .execute(null, scope);
        Test.stopTest();

        eligible = [
            SELECT New_Total_Order_Sales__c, Total_Order_Sales__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id = :eligible.Id
        ];
        System.assertEquals(
            salesAmount,
            eligible.New_Total_Order_Sales__c,
            'Eligible header should copy Total_Order_Sales__c to New_Total_Order_Sales__c'
        );

        alreadyPopulated = [
            SELECT New_Total_Order_Sales__c
            FROM QuotesOrdersCredits_Header__c
            WHERE Id = :alreadyPopulated.Id
        ];
        System.assertEquals(
            salesAmount,
            alreadyPopulated.New_Total_Order_Sales__c,
            'Batch should overwrite New_Total_Order_Sales__c from Total_Order_Sales__c'
        );
    }

    @IsTest
    static void start_totalSalesUpdate_returnsQueryLocator() {
        Test.startTest();
        Database.QueryLocator locator = new InvoiceBatchUpdate(
            Date.today().addDays(-1),
            Date.today().addDays(1),
            new QuotesOrdersCredits_Header__c(),
            'Total Sales Update'
        ).start(null);
        Test.stopTest();

        System.assertNotEquals(null, locator, 'Total Sales Update should return a query locator');
    }

    @IsTest
    static void executeBatch_deletesVendors_inCreatedDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Vendor__c inRange = new Vendor__c(
            Name = 'Vendor-In-' + uniqueSuffix()
        );
        Vendor__c outOfRange = new Vendor__c(
            Name = 'Vendor-Out-' + uniqueSuffix()
        );
        insert new List<Vendor__c>{ inRange, outOfRange };

        Test.setCreatedDate(inRange.Id, DateTime.newInstance(startDate.addDays(1), Time.newInstance(12, 0, 0, 0)));
        Test.setCreatedDate(outOfRange.Id, DateTime.newInstance(startDate.addDays(-1), Time.newInstance(12, 0, 0, 0)));

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new Vendor__c(), 'delete'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

        System.assertEquals(0, [SELECT COUNT() FROM Vendor__c WHERE Id = :inRange.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Vendor__c WHERE Id = :outOfRange.Id]);
    }

    @IsTest
    static void executeBatch_deletesOpportunitySyncReports_inCreatedDateRange() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today().addDays(1);

        Opportunity_Sync_Report__c inRange = new Opportunity_Sync_Report__c(
            Is_Successful__c = true,
            Record_Type__c = 'Opportunity',
            Update_Count__c = 0,
            Insert_Count__c = 0,
            Total_Count__c = 0,
            Error_Count__c = 0
        );
        Opportunity_Sync_Report__c outOfRange = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Order',
            Update_Count__c = 0,
            Insert_Count__c = 0,
            Total_Count__c = 0,
            Error_Count__c = 1
        );
        insert new List<Opportunity_Sync_Report__c>{ inRange, outOfRange };

        Test.setCreatedDate(inRange.Id, DateTime.newInstance(startDate.addDays(1), Time.newInstance(12, 0, 0, 0)));
        Test.setCreatedDate(outOfRange.Id, DateTime.newInstance(startDate.addDays(-1), Time.newInstance(12, 0, 0, 0)));

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(startDate, endDate, new Opportunity_Sync_Report__c(), 'delete'),
            50
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

        System.assertEquals(0, [SELECT COUNT() FROM Opportunity_Sync_Report__c WHERE Id = :inRange.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity_Sync_Report__c WHERE Id = :outOfRange.Id]);
    }

    @IsTest
    static void executeBatch_fixCancelledOpportunities_zerosTotalPrice() {
        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        PricebookEntry entry = newActivePricebookEntry();

        Opportunity opp = new Opportunity(
            Name = 'Opp-' + uniqueSuffix(),
            AccountId = acct.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId()
        );
        insert opp;

        OpportunityLineItem cancelled = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = entry.Id,
            Quantity = 2,
            UnitPrice = 50,
            Line_Status__c = 'Cancelled'
        );
        OpportunityLineItem active = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 75,
            Line_Status__c = 'Open'
        );
        insert new List<OpportunityLineItem>{ cancelled, active };

        System.assertNotEquals(0, [SELECT TotalPrice FROM OpportunityLineItem WHERE Id = :cancelled.Id].TotalPrice);

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(null, null, new OpportunityLineItem(), 'FIX_CANCELLED_OPPORTUNITIES'),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(
            0,
            [SELECT TotalPrice FROM OpportunityLineItem WHERE Id = :cancelled.Id].TotalPrice,
            'Cancelled opportunity lines should have TotalPrice zeroed'
        );
        System.assertEquals(
            75,
            [SELECT TotalPrice FROM OpportunityLineItem WHERE Id = :active.Id].TotalPrice,
            'Non-cancelled opportunity lines should be unchanged'
        );
    }

    @IsTest
    static void executeBatch_fixCancelledQuotes_syncsUnitPriceFromDetail() {
        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        PricebookEntry entry = newActivePricebookEntry();
        Decimal detailUnitPrice = 125.50;
        Decimal detailQty = 2;
        Decimal detailDollars = detailUnitPrice * detailQty;

        QuotesOrdersCredits_Header__c hdr = new QuotesOrdersCredits_Header__c(
            Name = 'Hdr-' + uniqueSuffix(),
            Customer__c = acct.Id,
            RecordTypeId = quotesHeaderRecordTypeId()
        );
        insert hdr;

        QuoteOrderCredit_Details__c activeDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Active-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId(),
            Qty_Ordered__c = detailQty,
            Dollars__c = detailDollars
        );
        QuoteOrderCredit_Details__c cancelledDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Cancelled-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId(),
            Qty_Ordered__c = 1,
            Dollars__c = 200
        );
        insert new List<QuoteOrderCredit_Details__c>{ activeDetail, cancelledDetail };

        Opportunity opp = new Opportunity(
            Name = 'Opp-' + uniqueSuffix(),
            AccountId = acct.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId()
        );
        insert opp;

        Quote quote = new Quote(
            Name = 'Quote-' + uniqueSuffix(),
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId(),
            Status = 'Draft'
        );
        insert quote;

        QuoteLineItem cancelled = new QuoteLineItem(
            QuoteId = quote.Id,
            PricebookEntryId = entry.Id,
            Quantity = 2,
            UnitPrice = 50,
            Line_Status__c = 'Cancelled',
            Quote_Order_Credit_Detail__c = cancelledDetail.Id
        );
        QuoteLineItem active = new QuoteLineItem(
            QuoteId = quote.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 75,
            Line_Status__c = 'Open',
            Quote_Order_Credit_Detail__c = activeDetail.Id
        );
        insert new List<QuoteLineItem>{ cancelled, active };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(null, null, new QuoteLineItem(), 'FIX_CANCELLED_QUOTES'),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(
            50,
            [SELECT UnitPrice FROM QuoteLineItem WHERE Id = :cancelled.Id].UnitPrice,
            'Cancelled quote lines should be excluded from the batch'
        );
        System.assertEquals(
            detailUnitPrice,
            [SELECT UnitPrice FROM QuoteLineItem WHERE Id = :active.Id].UnitPrice,
            'Non-cancelled quote lines should sync UnitPrice from Quote_Order_Credit_Detail__r.Unit_Price__c'
        );
    }

    @IsTest
    static void executeBatch_fixCancelledOrders_syncsUnitPriceFromDetail() {
        Account acct = new Account(Name = 'Acct-' + uniqueSuffix());
        insert acct;

        PricebookEntry entry = newActivePricebookEntry();
        Decimal detailUnitPrice = 88.25;
        Decimal detailQty = 4;
        Decimal detailDollars = detailUnitPrice * detailQty;

        QuotesOrdersCredits_Header__c hdr = new QuotesOrdersCredits_Header__c(
            Name = 'Hdr-' + uniqueSuffix(),
            Customer__c = acct.Id,
            RecordTypeId = quotesHeaderRecordTypeId()
        );
        insert hdr;

        QuoteOrderCredit_Details__c activeDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Active-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId(),
            Qty_Ordered__c = detailQty,
            Dollars__c = detailDollars
        );
        QuoteOrderCredit_Details__c cancelledDetail = new QuoteOrderCredit_Details__c(
            Name = 'Det-Cancelled-' + uniqueSuffix(),
            Order_Header__c = hdr.Id,
            RecordTypeId = quoteDetailStandardRecordTypeId(),
            Qty_Ordered__c = 1,
            Dollars__c = 200
        );
        insert new List<QuoteOrderCredit_Details__c>{ activeDetail, cancelledDetail };

        Order ord = new Order(
            Name = 'Ord-' + uniqueSuffix(),
            AccountId = acct.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId()
        );
        insert ord;

        OrderItem cancelled = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = entry.Id,
            Quantity = 2,
            UnitPrice = 50,
            Line_Status__c = 'Cancelled',
            Quote_Order_Credit_Detail__c = cancelledDetail.Id
        );
        OrderItem active = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 75,
            Line_Status__c = 'Open',
            Quote_Order_Credit_Detail__c = activeDetail.Id
        );
        insert new List<OrderItem>{ cancelled, active };

        Test.startTest();
        Id jobId = Database.executeBatch(
            new InvoiceBatchUpdate(null, null, new OrderItem(), 'FIX_CANCELLED_ORDERS'),
            50
        );
        Test.stopTest();

        assertJobCompleted(jobId);
        System.assertEquals(
            50,
            [SELECT UnitPrice FROM OrderItem WHERE Id = :cancelled.Id].UnitPrice,
            'Cancelled order lines should be excluded from the batch'
        );
        System.assertEquals(
            detailUnitPrice,
            [SELECT UnitPrice FROM OrderItem WHERE Id = :active.Id].UnitPrice,
            'Non-cancelled order lines should sync UnitPrice from Quote_Order_Credit_Detail__r.Unit_Price__c'
        );
    }
}