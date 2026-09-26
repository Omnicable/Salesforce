/**
 * @description Before insert and before update on {@link Order}. Stamps
 *              {@code Tango_Reward_Eligible__c} from {@link Order#BillToContactId} and
 *              {@link Order#EffectiveDate} via {@link RewardEligibilityHandler#setEligible}.
 *              On insert, copies Contact Tango start and end dates onto the Order.
 * @group Tango
 * @see RewardEligibilityHandler
 */
trigger OrderTrigger on Order (before insert, before update) {
    RewardEligibilityHandler.setEligible(Trigger.new, Order.BillToContactId, Order.EffectiveDate, Trigger.isInsert);
}