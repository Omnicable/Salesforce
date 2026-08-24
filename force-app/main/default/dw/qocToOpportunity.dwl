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

// Field mapping: QuotesOrdersCredits_Header__c -> Opportunity
// Add/adjust mappings as needed.
fun toOpportunity(h) =
    ({
        Quote_Order_Credit__c: h.Id default null,
        Name: h.Name default null,
        CloseDate: dateOnly(h.Date__c),
        StageName: h.Type__c match {
                case "Order" -> "Closed Won"
                case "Credit" -> "Close Won"
                else -> "Proposal/Price Quote"
        },
        Agent__c: h.Agent__c default null,
        AccountId: h.Customer__c default null,
        Contact__c: h.Buyer__c default null,
        Capital_Projects_Sales_Specialist__c: h.Capital_Projects_Sales_Specialist__c default null,
        Comms_Order__c: h.Comms_Order__c default null,
        CPSS_Involvement__c: h.CPSS_Involvement__c default null,
        Customer_PO__c: h.Customer_PO__c default null,
        Date__c: dateOnly(h.Date__c),
        DSP_Order__c: h.DSP_Order__c default null,
        Entered_By__c: h.Entered_By__c default null,
        Inside_AM__c: h.Inside_AM_Name__c default null,
        Invoiced_Date_Time__c: dateOnly(h.Invoiced_Date_Time__c),
        Job_Reference__c: h.Job_Reference__c default null,
        Order_Number__c: h.Order_Number__c default h.Name default null,
        Outside_AM__c: h.Outside_AM_Name__c default null,
        Payment_Terms__c: h.Payment_Terms__c default null,
        Quotation_Specialist__c: h.Quotation_Specialist__c default null,
        Sales_Notes__c: h.Sales_Notes__c default null,
        Sent_to_Customer__c: h.Sent_to_Customer__c default null,
        Ship_to_Address_1__c: h.Ship_to_Address_1__c default null,
        Ship_to_Address_2__c: h.Ship_to_Address_2__c default null,
        Ship_to_Attention__c: h.Ship_to_Attention__c default null,
        Ship_to_City__c: h.Ship_to_City__c default null,
        Ship_to_Name__c: h.Ship_to_Name__c default null,
        Ship_to_Phone__c: h.Ship_to_Phone__c default null,
        Ship_to_State__c: h.Ship_to_State__c default null,
        Ship_to_Zip_Code__c: h.Ship_to_Zip_Code__c default null,
        Status__c: h.Status__c default null,
        Status_Code__c: h.Status_Code__c default null,
        Sub_Type__c: h.Sub_Type__c default null,
        Total_Order_Cost__c: h.Total_Order_Cost__c default null,
        Total_Order_GP__c: h.Total_Order_GP__c default null,
        Total_Order_Sales__c: h.Total_Order_Sales__c default null,
        Source_System__c: h.Source_System__c default null,
        SalesNote1__c: h.SalesNote1__c default null,
        // LOD when total is strictly between $250k and $1M
        LOD__c: do {
            var total = (h.Total_Order_Sales__c default 0) as Number
            ---
            total > 250000
        },
        Capital_Project__c: ((h.Total_Order_Sales__c default 0) as Number) > 1000000,
        Type__c: h.Type__c default null,
        Type_Code__c: h.Type_Code__c default null
    }
    ++ (if ((h.Inside_AM_Name__c default null) != null) { OwnerId: h.Inside_AM_Name__c } else { OwnerId: '005Po000004BWlRIAW' }))

---
(records
  filter ((h) -> ((h.Type__c default "") as String) != "Credit")
  map ((h) -> toOpportunity(h))
  orderBy ((o) -> o.Order_Number__c default "")
)