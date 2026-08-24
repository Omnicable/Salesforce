/**
 * @description       : Updates the account when the a Price Book Approval is denied or approaved
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 09-15-2022
 * @last modified by  : chrisw@launchdm.com
**/
trigger PriceBookApprovalTrigger on Price_Book_Approval__c (before insert, before update) {

	if(Trigger.isBefore){
		PriceSheetController.checkPermission(Trigger.new, Trigger.oldMap);
	}
	
	if(Trigger.isUpdate){
		PriceSheetController.handleTypeChange(Trigger.newMap, Trigger.oldMap);
		PriceSheetController.setReadyStatus(trigger.newMap);
		PriceSheetController.checkLinkStatus(Trigger.newMap, Trigger.oldMap);
	}
	
	
}