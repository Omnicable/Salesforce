trigger OpportunityTrigger on Opportunity (after insert, after update) {

    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            SalesCloudPostDeployment.addOpportunityMembers(Trigger.new);
        }
    }
}