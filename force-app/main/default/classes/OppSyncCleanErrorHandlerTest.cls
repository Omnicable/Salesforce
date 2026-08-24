/**
 * @description Focused tests for {@link OppSyncCleanErrorHandler}. Deploy with the handler so production
 *              validation uses current coverage instead of stale methods in {@link QOCSyncTest}.
 * @group QOC Sync
 */
@IsTest
private class OppSyncCleanErrorHandlerTest {

    @IsTest
    static void handler_processesRecognizedSyncErrors() {
        Account customer = QOCSyncTest.getTestAccount();
        Spec_Sheet__c specSheet = new Spec_Sheet__c(Name = 'QOC ERR Spec Sheet');
        insert specSheet;
        Part_Numbers__c part = new Part_Numbers__c(
            Name = 'QOC-ERR-Part',
            Item_Number__c = 'QOC-ERR-Part',
            Spec_Sheet__c = specSheet.Id
        );
        insert part;
        QOCSyncTest.createProductForPart(part);

        QuotesOrdersCredits_Header__c header = QOCSyncTest.createQOCHeader(customer, null, 'Quote', 'QOC-ERR-HDR-001');
        QuotesOrdersCredits_Header__c lockHeader = QOCSyncTest.createQOCHeader(customer, null, 'Quote', 'QOC-LOCK-HDR-001');
        QuoteOrderCredit_Details__c detail = QOCSyncTest.createQOCDetail(header.Id, 'QOC-ERR-DTL-001', part.Id);

        Opportunity_Sync_Report__c report = new Opportunity_Sync_Report__c(
            Is_Successful__c = false,
            Record_Type__c = 'Opportunity',
            Error_Count__c = 1,
            Total_Count__c = 1
        );
        insert report;

        insert new List<Opportunity_Sync_Item__c>{
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
                Status_Code__c = 'DUPLICATE_VALUE',
                Record__c = JSON.serialize(new Map<String, Object>{ 'Ext_Id__c' => detail.Ext_Id__c }),
                Fixed__c = false
            ),
            new Opportunity_Sync_Item__c(
                Opportunity_Sync_Report__c = report.Id,
                Status_Code__c = 'DUPLICATE_VALUE',
                Record__c = JSON.serialize(
                    new Map<String, Object>{ 'Order_Number__c' => header.Order_Number__c }
                ),
                Fixed__c = false
            )
        };

        Test.startTest();
        Database.executeBatch(new OppSyncCleanErrorHandler(), 200);
        Test.stopTest();

        System.assertEquals(
            6,
            [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Opportunity_Sync_Report__c = :report.Id AND Fixed__c = true]
        );
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Opportunity_Sync_Item__c WHERE Opportunity_Sync_Report__c = :report.Id AND Fixed__c = false]
        );
    }
}