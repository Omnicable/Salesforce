%dw 2.9
input payload application/apex
output application/json
// Part_Numbers__c -> Product2
// Mirrors ProductSyncV2.getPartNumberToProductFieldMap(), buildNewProduct / applyPartToProduct:
// - Name, Category__c = "Other", IsActive = (Active__c == "A")
// - Part_Number_Ref__c = part Id
// - applyMapping skips productField Name or Id (none in map)
// - Duplicate map key Spec_Sheet_URL__c: last wins -> DisplayUrl only (matches Apex Map behavior)
//
// Accepts: JSON array of Part_Numbers__c, or { records: [...] }.
var records =
    if (payload is Array) payload
    else if (payload.records? and (payload.records is Array)) payload.records
    else []

fun isActivePart(p) = (p.Active__c default "") == "A"

// ProductCode / Product2 Item_Number__c: prefer part Item_Number__c; if null use ExtID__c
fun partItemNumberOrExtId(p) = p.Item_Number__c default p.ExtID__c

// Field mapping: Part_Numbers__c API name -> Product2 API name (same as ProductSyncV2)
fun toProduct2(p) =
    ({
        Name: p.Name default null,
        Category__c: "Other",
        IsActive: isActivePart(p),
        Part_Number_Ref__c: p.Id,
        Ext_Id__c: p.Id default null,
        Breaker_Type__c: p.Breaker_Type__c default null,
        Breaker_Weight__c: p.Breaker_Weight__c default null,
        Breaker_Width__c: p.Breaker_Width__c default null,
        Breaker_of_Poles__c: p.Breaker_of_Poles__c default null,
        Armor_Material_OPUS__c: p.Armor_Material_OPUS__c default null,
        Insulation_OPUS__c: p.Insulation_OPUS__c default null,
        Jacket_Color_OPUS__c: p.Jacket_Color_OPUS__c default null,
        Jacket_Type_OPUS__c: p.Jacket_Type_OPUS__c default null,
        Item_Class_OPUS__c: p.Item_Class_OPUS__c default null,
        Item_Class_Description_OPUS__c: p.Item_Class_Description_OPUS__c default null,
        Item_Number_OPUS__c: p.Item_Number_OPUS__c default null,
        Shield_1_Type_OPUS__c: p.Shield_1_Type_OPUS__c default null,
        Shield_2_Type_OPUS__c: p.Shield_2_Type_OPUS__c default null,
        Temperature_OPUS__c: p.Temperature_OPUS__c default null,
        Voltage_Rating_OPUS__c: p.Voltage_Rating_OPUS__c default null,
        Nom_O_D_OPUS__c: p.Nom_O_D_OPUS__c default null,
        Ohms_OPUS__c: p.Ohms_OPUS__c default null,
        Copper_Weight_Lbs_M__c: p.Copper_Weight_Lbs_M__c default null,
        Conductors__c: p.Conductors__c default null,
        CSA__c: p.CSA__c default null,
        AWG__c: p.AWG__c default null,
        Description: p.Item_Description_OPUS__c default null,
        Jacket_2_Color__c: p.Jacket_2_Color__c default null,
        Breaker_Max_Voltage__c: p.Breaker_Max_Voltage__c default null,
        Breaker_Interrupt_Rating_1__c: p.Breaker_Interrupt_Rating_1__c default null,
        Breaker_Trip_Tech__c: p.Breaker_Trip_Tech__c default null,
        Capacitance_OPUS__c: p.Capacitance_OPUS__c default null,
        Color_Chart_OPUS__c: p.Color_Chart_OPUS__c default null,
        Conductor_OPUS__c: p.Conductor_OPUS__c default null,
        Breaker_Accessories_Mods__c: p.Breaker_Accessories_Mods__c default null,
        Breaker_Amps__c: p.Breaker_Amps__c default null,
        Breaker_Available__c: p.Breaker_Available__c default null,
        Breaker_Brand__c: p.Breaker_Brand__c default null,
        Breaker_Frame__c: p.Breaker_Frame__c default null,
        Breaker_Height__c: p.Breaker_Height__c default null,
        Breaker_Length__c: p.Breaker_Length__c default null,
        Breaker_Lugs_Removable__c: p.Breaker_Lugs_Removable__c default null,
        Triads__c: p.Triads__c default null,
        ExternalId: p.ExtID__c default null,
        ProductCode: partItemNumberOrExtId(p) default null,
        Item_Number__c: p.Item_Number__c default null,
        Omni_Item_Type__c: p.Omni_Item_Type__c default null,
        Lbs_M__c: p.Lbs_M__c default null,
        NEC__c: p.NEC__c default null,
        UL__c: p.UL__c default null,
        Product_Manager__c: p.Product_Manager__c default null,
        DisplayUrl: p.Spec_Sheet_URL__c default null,
        Line_Side_Breaker_Term_Opt__c: p.Line_Side_Breaker_Term_Opt__c default null,
        Product_Business_Unit__c: p.Product_Business_Unit__c default null
    })

---
records map ((p) -> toProduct2(p))
