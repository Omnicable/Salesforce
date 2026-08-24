trigger OCC_ContactUpdateRewards on Contact (before update) {
    // System.debug('New : ' +  trigger.new);
    for( Id contactId : Trigger.newMap.keySet() ){
        if( Trigger.oldMap.get( contactId ).OCC_RewardsValue__c != Trigger.newMap.get( contactId ).OCC_RewardsValue__c  || Trigger.oldMap.get( contactId ).OCC_PendingRedeemIssue__c != Trigger.newMap.get( contactId ).OCC_PendingRedeemIssue__c || Trigger.oldMap.get( contactId ).OCC_RewardsTotal__c != Trigger.newMap.get( contactId ).OCC_RewardsTotal__c){
            Contact contact = Trigger.newMap.get( contactId );
            System.debug('Contact Changed: ' +  contact);
            OCCommunitiesResourceHelper.HeaderCalculationResult headerResults = OCCommunitiesResourceHelper.getHeaderAndTotals(contact);
            Trigger.newMap.get(contactId).OCC_RewardsTotal__c = headerResults.total;
        }
    } 
}