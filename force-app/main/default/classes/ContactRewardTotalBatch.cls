global class ContactRewardTotalBatch implements Database.Batchable<sObject> {
	
	global Database.QueryLocator start(Database.BatchableContext bc) {
		System.debug('ContactRewardTotalBatch started');
		String query= 'Select Id, OCC_RewardStep__c , OCC_RewardStepValue__c, OCC_RewardsTotal__c, OCC_RewardsValue__c FROM Contact WHERE Account.OCC_Rewards__c = true AND Contact_Title__c != Null AND FirstName != Null';
		return Database.getQueryLocator(query);
	}

   	global void execute(Database.BatchableContext bc, List<Contact> scope) {

		List<Contact> updatedContacts = new List<Contact>();
        for(Contact contact : scope){
            OCCommunitiesResourceHelper.HeaderCalculationResult headerResults = OCCommunitiesResourceHelper.getHeaderAndTotals(contact);
            Decimal total = headerResults.total;
            System.debug('Contact Total: ' + total);
            contact.OCC_RewardsTotal__c = total;
            updatedContacts.add(contact);
        }

        update updatedContacts;
	}
	
	global void finish(Database.BatchableContext bc) {
		System.debug('ContactRewardTotalBatch Complete');   
	}
}