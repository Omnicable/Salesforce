/**
 * @description Stamps {@code Tango_Reward_Eligible__c} on Order and Quote records from the
 *              related Contact's OCC reward enrollment and Tango date window. On insert,
 *              also copies {@link Contact#Tango_Start_Date__c} and
 *              {@link Contact#Tango_End_Date__c} onto the record. Intended for before-insert
 *              and before-update triggers so values are set without a follow-up DML. Order
 *              uses {@link Order#BillToContactId} and {@link Order#EffectiveDate}; Quote uses
 *              {@link Quote#ContactId} and {@link Quote#Date__c}.
 * @group Tango
 * @see TangoAPI
 */
@SuppressWarnings('PMD.ExcessiveParameterList')
public without sharing class RewardEligibilityHandler {
    /**
     * @description Sets {@code Tango_Reward_Eligible__c} on each record when the Contact in
     *              {@code contactField} has {@link Contact#OCC_Rewards__c} true and the Date
     *              in {@code dateField} falls between {@link Contact#Tango_Start_Date__c} and
     *              {@link Contact#Tango_End_Date__c} (inclusive). On insert, copies those
     *              Contact dates onto the record. Records with a blank contact, a blank
     *              {@code dateField}, or a Contact that does not meet those criteria, are
     *              stamped {@code false}. Performs one Contact query for the batch; returns
     *              immediately when no contact Ids are present.
     * @param records Trigger {@code new} Order or Quote rows (or any SObject with
     *                {@code Tango_Reward_Eligible__c}, the given contact lookup, and date).
     * @param contactField Lookup field used to resolve the Contact, for example
     *                     {@link Order#BillToContactId} or {@link Quote#ContactId}.
     * @param dateField Date compared to the Contact Tango window, for example
     *                  {@link Order#EffectiveDate} or {@link Quote#Date__c}.
     * @param isInsert True when the trigger is before insert; copies Contact Tango dates
     *                 onto the record. Before update does not overwrite those dates.
     */
    public static void setEligible(List<SObject> records, SObjectField contactField, SObjectField dateField, Boolean isInsert) {
        Set<Id> contactIds = new Set<Id>();
        for (SObject record : records) {
            Id contactId = (Id) record.get(contactField);
            if (contactId != null) {
                contactIds.add(contactId);
            }
        }
        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contacts = new Map<Id, Contact>([
            SELECT OCC_Rewards__c, Tango_Start_Date__c, Tango_End_Date__c
            FROM Contact
            WHERE Id IN :contactIds
        ]);

        for (SObject record : records) {
            Contact buyer = contacts.get((Id) record.get(contactField));
            if (isInsert == true && buyer != null) {
                record.put('Tango_Start_Date__c', buyer.Tango_Start_Date__c);
                record.put('Tango_End_Date__c', buyer.Tango_End_Date__c);
            }
            Date bookDate = (Date) record.get(dateField);
            Date startDate = (Date) record.get('Tango_Start_Date__c');
            Date endDate = (Date) record.get('Tango_End_Date__c');
            Boolean eligible =
                buyer != null
                && buyer.OCC_Rewards__c == true
                && startDate != null
                && endDate != null
                && bookDate >= startDate
                && bookDate <= endDate;
            record.put('Tango_Reward_Eligible__c', eligible);
        }
    }
}