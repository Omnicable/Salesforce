trigger OCC_PreventClosedEdits on QuoteOrderCredit_Details__c (before insert, before update) {

/*
    List<ID> headerIds = new List<ID>();
    for (QuoteOrderCredit_Details__c h : Trigger.New){
        headerIds.add(h.Order_Header__c);
    }
    
    List<QuotesOrdersCredits_Header__c> headers = new List<QuotesOrdersCredits_Header__c>([SELECT ID, Status__c FROM QuotesOrdersCredits_Header__c WHERE Status__c IN ('Completed', 'Rejected') AND ID in: headerIds]);

    for (QuoteOrderCredit_Details__c qocd : Trigger.New){
        for (integer i = 0; i < headers.size(); i++){
            if (qocd.Order_Header__c == headers[i].id) {
                qocd.addError('Cannot update a record with a status of Completed or Rejected'); // prevent update
            }
        }
    }
   
*/
}