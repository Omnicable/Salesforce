%dw 2.9
input payload application/apex
output application/json
// Accepts either:
// - a list of QuotesOrdersCredits_Header__c records, or
// - an object with a "records" array (common SF REST shape)
//
// Produces a list of Order objects using the mapping below.
var records =
    if (payload is Array) payload
    else if (payload.records? and (payload.records is Array)) payload.records
    else []

// Only map headers whose Order_Type__c is Order or Credit (Salesforce picklist API values).
var orderTypeAllowed = ["Credit", "Order"]

fun dateOnly(v) =
    if (v == null) null
    else ((v as String) splitBy "T")[0]

fun dateOnlyOrToday(v) =
    dateOnly(v) default (now() as Date)

fun toCheckbox(v) =
    if (v == null or v == "") false
    else v as Boolean

// Field mapping: QuotesOrdersCredits_Header__c -> Order
// Add/adjust mappings as needed.
fun toOrder(h) = {


    Quote_Order_Credit__c: h.Id default null,
    Name: h.Name default null,
    OrderReferenceNumber: h.Order_Number__c default null,
    EffectiveDate: dateOnlyOrToday(h.Date__c),
    PoNumber: h.Customer_PO__c default null,
    AccountId: h.Customer__c default null,
    Ship_to_Phone__c: h.Ship_to_Phone__c default null,
    Ship_to_Address_1__c: h.Ship_to_Address_1__c default null,
    Ship_to_Address_2__c: h.Ship_to_Address_2__c default null,
    Ship_to_Attention__c: h.Ship_to_Attention__c default null,
    Ship_to_City__c: h.Ship_to_City__c default null,
    Ship_to_State__c: h.Ship_to_State__c default null,
    Ship_to_Zip_Code__c: h.Ship_to_Zip_Code__c default null,
    Ship_to_Name__c: h.Ship_to_Name__c default null,
    BillToContactId: h.Buyer__c default null,
    ShipToContactId: h.Buyer__c default null,
    Agent__c: h.Agent__c default null,
    DSP_Order__c: toCheckbox(h.DSP_Order__c),
    Entered_By__c: h.Entered_By__c default null,
    Job_Reference__c: h.Job_Reference__c default null,
    Payment_Terms__c: h.Payment_Terms__c default null,
    Sent_to_Customer__c: toCheckbox(h.Sent_to_Customer__c),
    Portal_Visibility__c: toCheckbox(h.Sent_to_Customer__c),
    Status__c: h.Status__c default null,
    Status_Code__c: h.Status_Code__c default null,
    Sub_Type__c: h.Sub_Type__c default null,
    Total_Order_Cost__c: h.Total_Order_Cost__c default null,
    Total_Order_GP__c: h.Total_Order_GP__c default null,
    Total_Order_Sales__c: h.Total_Order_Sales__c default null,
    Type__c: h.Type__c default null,
    Type_Code__c: h.Type_Code__c default null,
    Inside_AM__c: h.Inside_AM_Name__c default null,
    Outside_AM__c: h.Outside_AM_Name__c default null,
    Capital_Projects_Sales_Specialist__c: h.Capital_Projects_Sales_Specialist__c default null,
    Quotation_Specialist__c: h.Quotation_Specialist__c default null,
    CPSS_Involvement__c: h.CPSS_Involvement__c default null,
    Comms_Order__c: toCheckbox(h.Comms_Order__c),
    Sales_Notes__c: h.Sales_Notes__c default null,
    Source_System__c: h.Source_System__c default null,
    Tango_Redeemed__c: h.OCC_RewardRedeemed__c default null,
    Tango_Rewards_Override__c: h.RewardOverride__c default null,
    Tango_Reward_Step_Value__c: h.OCC_RewardStepValue__c default null,
    Tango_Reward_Step__c: h.OCC_RewardStep__c default null,
    Portal_Visibility__c: h.Sent_to_Customer__c default null,
    Order_Number__c: h.Order_Number__c default h.Name default null,
        LOD__c: do {
        var total = (h.Total_Order_Sales__c default 0) as Number
        ---
        total > 250000
    },
    Capital_Project__c: ((h.Total_Order_Sales__c default 0) as Number) > 1000000,
    Status: h.Type__c match {
        case "Order" -> "Booked"
        case "Credit" -> "Booked"
        else -> null
    }
        
}
    ++ (if ((h.Inside_AM__c default null) != null) { OwnerId: h.Inside_AM__c } else {})

---
(records
  filter ((h) -> orderTypeAllowed contains ((h.Type__c default "") as String))
  map ((h) -> toOrder(h))
  orderBy ((o) -> o.Order_Number__c default "")
)