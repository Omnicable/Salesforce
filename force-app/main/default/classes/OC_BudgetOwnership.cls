public with sharing class OC_BudgetOwnership {

// Map contains ID's
    public static void setBudgetOwnership(Set<Id> accountIds) {
      try{
        // New Budget Month list to be used to fill with BM records to update
        List<Budget_Month__c> bmList = new List<Budget_Month__c>();
        // set of ID's to be used in the SOQL query below
        
        //Never Never Never do SOQL within a loop per Ami
        List <Budget__c> mylist = [SELECT Name, customer__r.OwnerId, 
                                          (SELECT Id, Budget_Owner__c 
                                           FROM Budget_Months__r) 
                                       From Budget__c 
                                       WHERE Customer__c in :accountIds];
                 for (Budget__c b : mylist) { 
                    b.Budget_Owner__c = b.customer__r.OwnerId;
                 for (Budget_Month__c bm : b.Budget_Months__r) {
                   bm.Budget_Owner__c = b.customer__r.OwnerId;
                 bmlist.add(bm);
                 }
                 //update bmlist never do update's inside loops;
              }
              // if more than one in an if setup then need {}'s'
              // use these if statements to ensure you have results
              if (!bmList.isempty())
                 update bmlist;
              if (!mylist.isempty())
              update mylist;
      }                   
           catch (Exception e) {system.debug('Unhandled exception: '+e);}
    }

}