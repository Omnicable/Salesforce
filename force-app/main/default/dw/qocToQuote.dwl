%dw 2.9
input payload application/apex
output application/json
// Accepts either:
// - a list of QuotesOrdersCredits_Header__c records, or
// - an object with a "records" array (common SF REST shape)
//
// Produces a list of Opportunity objects using the mapping below.
var records =
    if (payload is Array) payload
    else if (payload.records? and (payload.records is Array)) payload.records
    else []

fun dateOnly(v) =
    if (v == null) null
    else ((v as String) splitBy "T")[0]

// Apex Date fields expect yyyy-MM-dd when deserializing from JSON.
fun todayDateOnly() = now() as String { format: "yyyy-MM-dd" }

// Field mapping: QuotesOrdersCredits_Header__c -> Opportunity
// Add/adjust mappings as needed.
fun toOpportunity(h) =
    ({
        Name: h.Name default null,
        Quote_Order_Credit__c: h.Id default null,
        ContactId: h.Buyer__c default null,
        ShippingName: h.Ship_to_Name__c default null,
        Phone: h.Ship_to_Phone__c default null,
        Ship_to_Address_1__c: h.Ship_to_Address_1__c default null,
        Ship_to_Address_2__c: h.Ship_to_Address_2__c default null,
        Ship_to_Attention__c: h.Ship_to_Attention__c default null,
        Ship_to_City__c: h.Ship_to_City__c default null,
        Ship_to_State__c: h.Ship_to_State__c default null,
        Ship_to_Zip_Code__c: h.Ship_to_Zip_Code__c default null,
        Date__c: (dateOnly(h.Date__c)) default todayDateOnly(),
        ExpirationDate: (dateOnly(h.Expiration_Date__c)) default null,
        Order_Number__c: h.Order_Number__c default h.Name default null,
        Order_Type__c: h.Order_Type__c default null,
        Tango_Redeemed__c: h.OCC_RewardRedeemed__c default null,
        Tango_Rewards_Override__c: h.RewardOverride__c default null,
        Tango_Reward_Step_Value__c: h.OCC_RewardStepValue__c default null,
        Tango_Reward_Step__c: h.OCC_RewardStep__c default null,
        Payment_Terms__c: h.Payment_Terms__c default null,
        Job_Reference__c: h.Job_Reference__c default null,
        Total_Order_Sales__c: h.Total_Order_Sales__c default null,
        Status__c: h.Status__c default null,
        Portal_Visibility__c: h.Sent_to_Customer__c default null,
        Status: h.Type__c match {
            case "Order" -> "Approved"
            else -> "Draft"
        }
    }
    ++ (if ((h.OwnerId default null) != null) { OwnerId: h.OwnerId } else {}))

---
(records filter ((h) -> (h.Type__c default "") != "Credit"))
  map ((h) -> toOpportunity(h))
  orderBy ((q) -> q.Order_Number__c default "")