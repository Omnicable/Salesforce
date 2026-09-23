/**
 * @description Before insert and before update on {@link Quote}. Stamps
 *              {@code Tango_Reward_Eligible__c} from {@link Quote#ContactId} and
 *              {@link Quote#Date__c} via {@link RewardEligibilityHandler#setEligible}.
 * @group Tango
 * @see RewardEligibilityHandler
 */
trigger QuoteTrigger on Quote (before insert, before update) {
    RewardEligibilityHandler.setEligible(Trigger.new, Quote.ContactId, Quote.Date__c);
}