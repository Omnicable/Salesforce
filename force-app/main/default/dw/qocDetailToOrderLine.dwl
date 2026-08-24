%dw 2.9
input payload application/apex
output application/json
// QuoteOrderCredit_Details__c -> OrderItem
// Field pairs match OrderItemSyncV2.getDetailToLineFieldMap().
// Also sets Ext_Id__c and Quote_Order_Credit_Detail__c (Detail Id), same as OrderItemSyncV2.
//
// Accepts: JSON array of detail records, or { records: [...] }.
var records =
    if (payload is Array) payload
    else if (payload.records? and (payload.records is Array)) payload.records
    else []

// Exclude detail rows whose Order_Type__c is not Order or Credit (picklist API values).
var orderTypeAllowed = ["Credit", "Order"]

fun dateOnly(v) =
    if (v == null) null
    else ((v as String) splitBy "T")[0]

fun quantityOrMinOne(qty) =
    if (qty == null) 1
    else if ((qty as Number) == 0) 1
    else qty

fun toOrderItem(d) =
    ({
        Ext_Id__c: d.Ext_Id__c default null,
        Quote_Order_Credit_Detail__c: d.Id default null,
        Item_Number__c: d.Item_Number__c default null,
        Quantity: quantityOrMinOne(d.Qty_Ordered__c),
        Description: d.Item_Description__c default null,
        UnitPrice: d.Unit_Price__c default 0,
        Is_Active__c: d.C2ACT__c default null,
        Date_Line_Entered__c: dateOnly(d.Date_Line_Entered__c),
        Line_Number__c: d.Line_Number__c default null,
        Warehouse__c: d.Warehouse__c default null,
        GPDollars__c: d.GPDollars__c default null,
        Line_Type__c: d.Line_Type__c default null,
        Qty_Shipped__c: d.Qty_Shipped__c default null,
        Unit_of_Measure__c: d.Unit_of_Measure__c default null,
        Order_Process__c: d.Order_Process__c default null,
        Ship_Via__c: d.Ship_Via__c default null,
        Freight_Terms__c: d.Freight_Terms__c default null,
        Freight_Carrier__c: d.Freight_Carrier__c default null,
        Major_Class_Desc__c: d.Major_Class_Desc__c default null,
        Item_Markings__c: d.Item_Markings__c default null,
        Leadtime__c: d.Leadtime__c default null,
        Customer_Item__c: d.Customer_Item__c default null,
        Firm__c: d.Firm__c default null,
        Flux__c: d.Flux__c default null,
        Item_Class__c: d.Item_Class__c default null,
        Item_Class_Description__c: d.Item_Class_Description__c default null,
        Line_Item__c: d.Line_Item__c default null,
        Line_Status__c: d.Line_Status__c default null,
        Metal_Type__c: d.Metal_Type__c default null,
        Metal_Weight__c: d.Metal_Weight__c default null,
        Put_up_1__c: d.Put_up_1__c default null,
        Put_up_2__c: d.Put_up_2__c default null,
        Put_up_3__c: d.Put_up_3__c default null,
        Put_up_4__c: d.Put_up_4__c default null,
        Put_up_5__c: d.Put_up_5__c default null,
        Put_up_6__c: d.Put_up_6__c default null,
        Put_up_7__c: d.Put_up_7__c default null,
        S_D_Not_Eligible__c: d.S_D_Not_Eligible__c default null,
        C2SPRC__c: d.C2SPRC__c default null,
        Tolerance__c: d.Tolerance__c default null,
        Tracking_Number__c: d.Tracking_Number__c default null,
        Vendor_Number__c: d.Vendor_Number__c default null,
        BSDCost__c: d.BSDCost__c default null,
        BSDBase__c: d.BSDBase__c default null,
        C2SPECV__c: d.C2SPECV__c default null,
        C3CTXT__c: d.C3CTXT__c default null,
        C3CTXT1_c__c: d.C3CTXT1_c__c default null,
        C3CTXT2_c__c: d.C3CTXT2_c__c default null,
        C9NOTE1__c: d.C9NOTE1__c default null,
        Received_Complete__c: d.Received_Complete__c default "",
        Why_Not_S_D_Eligible__c: d.Why_Not_S_D_Eligible__c default null,
        TrackingURL__c: d.TrackingURL__c default null,
        Order_Type__c: d.Order_Type__c default null,
        OrderNumber__c: d.OrderNumber__c default null,
        CableCode__c: d.CableCode__c default null,
        Vendor__c: d.Vendor__c default null
    })

---
(records
  orderBy ((d) -> d.OrderNumber__c default "")
  filter ((d) -> orderTypeAllowed contains ((d.Order_Type__c default "") as String))
  map ((d) -> toOrderItem(d))
)
