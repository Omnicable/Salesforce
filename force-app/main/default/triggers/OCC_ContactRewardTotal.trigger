trigger OCC_ContactRewardTotal on QuotesOrdersCredits_Header__c (after insert, after update, after delete) {
    // Set<ID> contactIds = new Set<ID>();
    // if(trigger.old != null){
    //     for (QuotesOrdersCredits_Header__c q :  trigger.old){
    //         if(!contactIds.contains(q.Buyer__c)){
    //             contactIds.add(q.Buyer__c);
    //         }
    //     }
    // }
    
    // //Get Updated
    // if(trigger.new != null){
    //     for (QuotesOrdersCredits_Header__c q : trigger.new){
    //         if(!contactIds.contains(q.Buyer__c)){
    //             contactIds.add(q.Buyer__c);
    //         }
    //     }
    // }

	// System.debug('Contact Ids: ' + contactIds);
	// OCCommunitiesResourceHelper.updateContactRewards(contactIds);
}