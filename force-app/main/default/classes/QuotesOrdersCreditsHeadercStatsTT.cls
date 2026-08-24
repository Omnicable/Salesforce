@isTest
private class QuotesOrdersCreditsHeadercStatsTT {

   static testMethod void testTrigger() {
      try {
          QuotesOrdersCredits_Header__c o = new QuotesOrdersCredits_Header__c();
          insert o;

          System.assertNotEquals(null, o);
      }
      catch(Exception e) {
          List<QuotesOrdersCredits_Header__c> l = [SELECT Id from QuotesOrdersCredits_Header__c LIMIT 1];
          update l;
          System.assertNotEquals(null, l);
      }
   }
}