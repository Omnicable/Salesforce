trigger OCC_GetRewardInfo on QuotesOrdersCredits_Header__c(before insert, before update) {
	
	
	Set<ID> contIds = new Set<ID>();

	for (QuotesOrdersCredits_Header__c q : trigger.new){

		if(!contIds.contains(q.Buyer__c)){
			contIds.add(q.Buyer__c);
		}
	}

	List<Contact> conts = [Select Id, OCC_RewardStep__c , OCC_RewardStepValue__c from Contact where Id IN: contIds];
	
	Map<Id, Contact> contactMap = new Map<Id,Contact>();
	
	for(Contact cont : conts) {
	   contactMap.put(cont.Id, cont);
	}
	
	for (QuotesOrdersCredits_Header__c q : trigger.new){
		System.debug('before q.Sent_to_Customer__c: ' + q.Sent_to_Customer__c);
		if(Trigger.isInsert){
			//NOTE: only on insert
			updateSentToCustomer(q);
		}
		
		System.debug('afterq.Sent_to_Customer__c: ' + q.Sent_to_Customer__c);
		if(q.Status__c != 'Invoiced'){
			         
           if(contactMap.containsKey(q.Buyer__c )) {
               Contact c = contactMap.get(q.Buyer__c);

				q.OCC_RewardStep__c = c.OCC_RewardStep__c;	
				q.OCC_RewardStepValue__c = c.OCC_RewardStepValue__c;

        	}
        }
	}

	/**
	 * @description Update the Sent_to_Customer__c field based on the type and status of the quote/order
	 * added because sent_to_customer__c is not being set in OP
	 * @param q The quote/order to update
	 */
	public void updateSentToCustomer(QuotesOrdersCredits_Header__c q) {
		if(q.Sent_to_Customer__c == false) {
			if(q.Type__c == 'Order' && q.Status__c != 'Closed') {
				q.Sent_to_Customer__c = true;
			} else if(q.Type__c == 'Quote' && (q.Status__c == 'Open' || q.Status__c == 'Followed Up' || q.Status__c == 'Closed' || q.Status__c == 'Cancelled')) {
				q.Sent_to_Customer__c = true;
			}
		}
	}

}