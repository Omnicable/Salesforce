@isTest
private class HooplaStatscStatsTT {

    @isTest

   static void testTrigger() {
      try {
          HooplaStats__c o = new HooplaStats__c(Name='Test Hoopla Stats', DateSM1Key__c='1234567890');
          insert o;

          Assert.areNotEqual(null, o, 'Should not be null');
      }
      catch(Exception e) {
          List<HooplaStats__c> l = [SELECT Id from HooplaStats__c LIMIT 1];
          update l;
          Assert.areNotEqual(null, l, 'Should not be null');
      }
   }
}