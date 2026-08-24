trigger OC_ContactOwnership_after on Account (after insert, after update) {
   try {
      Set<Id> accountIds = new Set<Id>(); //set for holding the Ids of all Accounts that have been assigned to new Owners
      Map<Id, String> oldOwnerIds = new Map<Id, String>(); //map for holding the old account ownerId
      Map<Id, String> newOwnerIds = new Map<Id, String>(); //map for holding the new account ownerId
      Contact[] contactUpdates = new Contact[0]; //Contact sObject to hold OwnerId updates

      System.Debug('OC_ContactOwnership_after New Accounts: ' + Trigger.new.size()); //get account update size 
      
      for (Account a : Trigger.new) { //for all records
         //Added check for oldmap being null which indicates new accounts
         if (Trigger.oldMap != null && Trigger.oldMap.get(a.Id) != null && a.OwnerId != Trigger.oldMap.get(a.Id).OwnerId) {
            oldOwnerIds.put(a.Id, Trigger.oldMap.get(a.Id).OwnerId); //put the old OwnerId value in a map
            newOwnerIds.put(a.Id, a.OwnerId); //put the new OwnerId value in a map
            accountIds.add(a.Id); //add the Account Id to the set
         }
      }
      
      System.Debug('OC_ContactOwnership_after accountIds: ' + JSON.serializePretty(accountIds)); //get all accountIds
      if (!accountIds.isEmpty()) { //if the accountIds Set is not empty
         for (Account act : [SELECT Id, (SELECT Id, OwnerId FROM Contacts), (SELECT Id, OwnerId FROM Opportunities WHERE IsClosed = False) FROM Account WHERE Id in :accountIds]) { //SOQL to get Contacts and Opportunities for updated Accounts
            String newOwnerId = newOwnerIds.get(act.Id); //get the new OwnerId value for the account
            String oldOwnerId = oldOwnerIds.get(act.Id); //get the old OwnerId value for the account

            System.Debug('OC_ContactOwnership_after act.Contacts: ' + JSON.serializePretty(act.Contacts)); //get all accountIds

            for (Contact c : act.Contacts) { //for all contacts
               if (c.OwnerId == oldOwnerId) { //if the contact is assigned to the old account Owner
                  Contact updatedContact = new Contact(Id = c.Id, OwnerId = newOwnerId); //create a new Contact sObject
                  contactUpdates.add(updatedContact); //add the contact to our List of updates
               }
            }
         }

         System.Debug('OC_ContactOwnership_after contactUpdates: ' + JSON.serializePretty(contactUpdates)); //get all accountIds
         update contactUpdates; //update the Contacts
      }
//       if (!accountIds.isEmpty()) {
//           OC_BudgetOwnership.setBudgetOwnership(accountIds);}
   } catch(Exception e) { //catch errors
      System.Debug('OC_ContactOwnership_after failure: '+e.getMessage()); //write error to the debug log
   }
}