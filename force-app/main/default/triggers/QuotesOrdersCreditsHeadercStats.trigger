trigger QuotesOrdersCreditsHeadercStats on QuotesOrdersCredits_Header__c(after insert, after update) {
  try {
    // List<sObject> so = Database.query('SELECT Id FROM hoopla__Object__c');
    // String changeType = Trigger.isInsert ? 'insert' : Trigger.isUpdate ? 'update' : Trigger.isDelete ? 'delete' : 'undelete';
    // hoopla.NotifierGlobal.processNotifications('QuotesOrdersCredits_Header__cStats', Trigger.newMap, Trigger.oldMap, changeType);
  }
  catch(Exception e) {
    //Package suspended, uninstalled or expired, exit gracefully.
  }
}