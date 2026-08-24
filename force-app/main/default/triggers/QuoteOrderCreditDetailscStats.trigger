trigger QuoteOrderCreditDetailscStats on QuoteOrderCredit_Details__c(after insert, after update, after delete, after undelete) {
  try {
    // List<sObject> so = Database.query('SELECT Id FROM hoopla__Object__c');
    // String changeType = Trigger.isInsert ? 'insert' : Trigger.isUpdate ? 'update' : Trigger.isDelete ? 'delete' : 'undelete';
    // hoopla.NotifierGlobal.processNotifications('QuoteOrderCredit_Details__cStats', Trigger.newMap, Trigger.oldMap, changeType);
  }
  catch(Exception e) {
    //Package suspended, uninstalled or expired, exit gracefully.
  }
}