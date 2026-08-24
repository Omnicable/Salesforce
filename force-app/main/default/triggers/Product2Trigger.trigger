/**
 * @description       : triggered on new products
 * @author            : chrisw@launchdm.com
 * @group             : PriceSheet
 * @last modified on  : 08-04-2022
 * @last modified by  : chrisw@launchdm.com
**/
trigger Product2Trigger on Product2 (after insert) {
	PriceSheetController.addToStandardPriceBook(Trigger.New);
}