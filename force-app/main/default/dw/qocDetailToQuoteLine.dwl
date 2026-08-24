%dw 2.9
input payload application/apex
output application/json
// QuoteOrderCredit_Details__c -> QuoteLineItem
// Field pairs match QuoteLineItemSyncV2.getDetailToLineFieldMap().
// Also sets Ext_Id__c and Quote_Order_Credit_Detail__c (Detail Id), same as QuoteLineItemSyncV2.
// Drops rows where Order_Type__c = "Credit".
//
// Accepts: JSON array of detail records, or { records: [...] }.
var records =
    if (payload is Array) payload
    else if (payload.records? and (payload.records is Array)) payload.records
    else []

fun dateOnly(v) =
    if (v == null) null
    else ((v as String) splitBy "T")[0]

fun quantityOrMinOne(qty) =
    if (qty == null) 1
    else if ((qty as Number) == 0) 1
    else qty

fun toQuoteLineItem(d) =
    ({
        Ext_Id__c: d.Ext_Id__c default null,
        Quote_Order_Credit_Detail__c: d.Id default null,
        Quantity: quantityOrMinOne(d.Qty_Ordered__c),
        Description: d.Item_Description__c default null,
        UnitPrice: d.Unit_Price__c default 0,
        Item_Number__c: d.Item_Number__c default null,
        Order_Type__c: d.Order_Type__c default null,
        ServiceDate: dateOnly(d.Expected_Date__c),
        OrderNumber__c: d.OrderNumber__c default null
    })

---
records
    orderBy ((d) -> d.OrderNumber__c default "")
    filter ((d) -> (d.Order_Type__c default "") != "Credit")
    map ((d) -> toQuoteLineItem(d))
