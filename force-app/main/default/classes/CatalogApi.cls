@RestResource(urlMapping='/OMNI/*')
global with sharing class CatalogApi {

	global class SpecSheet {
        
        /*
        webservice String Id{get;set;}
        webservice String name{get;set;}
        webservice String Belden_Url {get;set;} 
        webservice String ExtId {get;set;} 
        webservice String CableType {get;set;} 
        webservice String Applications {get;set;} 
        webservice String Features {get;set;} 
        webservice String Braid {get;set;} 
        webservice String Voltage {get;set;}
        webservice String Description{get;set;} 
        webservice String Shield {get;set;} 
        webservice Boolean IsDeleted {get;set;} 
        webservice String Conductor {get;set;} 
        webservice String Insulation {get;set;} 
        webservice String Jacket {get;set;} 
        webservice String Assembly {get;set;} 
        webservice String Standards {get;set;} 
        webservice String ColorCode {get;set;} 
        webservice String LastModifiedDate {get;set;}
        */
        public Spec_Sheet__c SpecSheetObj;
       	public List<String> AWG{get;set;} 
        public List<Decimal> Conductors{get;set;} 
        public List<String> Pairs{get;set;} 
        public List<String> Triads{get;set;} 
        public List<String> BreakerFrames{get;set;} 
        public Part_Numbers__c PartNumberObj;
           
        public SpecSheet(){
          AWG = new List<String>();
          Conductors = new List<Decimal>();
          Pairs = new List<String>();
          Triads = new List<String>();
          BreakerFrames = new List<String>();
        }
    }
    
    global class SpecFieldSupress{
        set<String> hiddenFields{get;set;}
        
        public SpecFieldSupress(){
          hiddenFields = new set<String>();
        }
    }
    
    global class APIResult{
        webservice Boolean Success{get;set;}
        webservice String Message{get;set;} 
        
       	public List<sObject> PartNumbers{get;set;} 
        public List<SpecSheet> SpecSheets{get;set;}
        
        public APIResult(){
       	  Success = false;
          PartNumbers = new List<sObject>();
          SpecSheets = new List<SpecSheet>();
        }
    }
    
    global static String getQuery(DescribeSObjectResult objectSchema, set<String> ignoreList) {
        
        Map<String, Schema.SObjectField> objFields = objectSchema.fields.getMap();
        System.Debug(objFields);
        
        List<String> allFields = new List<String>();
        String queryString = '';
        Integer count = 0;
        String fieldName = '';
        for(Schema.SObjectField value : objFields.values()) {
            
            fieldName = value.getDescribe().getName();
            if(!ignoreList.contains(fieldName)) {
            
	            if (count == 0){
	                queryString = fieldName; 
	            }else{
	                queryString = queryString + ', ' + fieldName;
	            }
	            count++; 
            }
        }
        
        return queryString;
    }
    
    @HttpGet
    global static APIResult doGet()    {
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String time_stamp = ''; 
        Boolean do_load_specs = true;
        Boolean do_load_parts = true; 
        String do_include_deleted = '';
     
        if (req != null) {
          time_stamp = req.params.get('time_stamp');
          
          String load_specs = req.params.get('get_spec_sheets');
          if(load_specs != null) {
          	do_load_specs = Boolean.valueOf(load_specs); 
          }
          
          String load_parts = req.params.get('get_part_numbers');
          if(load_parts != null) {
          	do_load_parts = Boolean.valueOf(load_parts); 
          }
          
          String include_deleted = req.params.get('include_deleted');
          if(include_deleted != null) {
          	if(Boolean.valueOf(include_deleted)) {
          		do_include_deleted = ' ALL ROWS';
          	} 
          }
        }
        
        APIResult result = new APIResult();
        
        
        set<String> partIgnore = new set<String>();        
        partIgnore.add('CreatedById');
        //partIgnore.add('IsDeleted');
        partIgnore.add('LastViewedDate');
        partIgnore.add('LastReferencedDate');
        partIgnore.add('SystemModstamp');
        partIgnore.add('CreatedDate');
        partIgnore.add('LastModifiedById');
        partIgnore.add('LastModifiedDate');
        partIgnore.add('Spec_Sheet__c');
        partIgnore.add('Id');
        
        
        partIgnore.add('Jacket_Color_OPUS__c');
        partIgnore.add('Jacket_Type_OPUS__c');
        partIgnore.add('Insulation_OPUS__c');
        partIgnore.add('Shield_1_Type_OPUS__c');
        partIgnore.add('Shield_2_Type_OPUS__c');
        partIgnore.add('Capacitance_OPUS__c');
        partIgnore.add('Ohms_OPUS__c');
        partIgnore.add('Temperature_OPUS__c');
        partIgnore.add('Voltage_Rating_OPUS__c');
        partIgnore.add('Conductor_OPUS__c');
        partIgnore.add('Nom_O_D_OPUS__c');
        partIgnore.add('Product_Manager__c');
        partIgnore.add('Item_Class_OPUS__c');
        partIgnore.add('Item_Class_Description_OPUS__c');
        partIgnore.add('Item_Description_OPUS__c');
        partIgnore.add('Color_Chart_OPUS__c');
        partIgnore.add('Copper_Weight_Lbs_M__c');
        partIgnore.add('CSA__c');
        partIgnore.add('UL__c');
        partIgnore.add('NEC__c');
        
       
        
        /*
        partIgnore.add('Belden_URL__c');
        
        partIgnore.add('Jacket_Color__c');
        partIgnore.add('Max_D_C_Res_20_C_Ohms_M__c');
        partIgnore.add('Inner_Jacket_Thickness__c');
        
        partIgnore.add('Nominal_O_D_Inner_Conductor__c');
        partIgnore.add('Spec_Sheet_Text__c');
        partIgnore.add('Color_Code__c');
        partIgnore.add('Insulation_Min_Avg_Wall_mils__c');
        
        
        partIgnore.add('Nom_O_D_Overall__c');
        partIgnore.add('Nominal_Capacitance__c');
        partIgnore.add('Insulation_Diameter_Min__c');
        partIgnore.add('Kevlar_Thickness__c');
        partIgnore.add('Conductor_Colors__c');
       	partIgnore.add('Ground_Stranding__c');
        partIgnore.add('Ground_AWG__c');
        */
        
        //TFE_Wall_Thickness__c, Phase_Conductor_Stranding__c, Braid__c, Standard_Box_Quantities__c, Continuous_Current_per_Conductor_30_C__c, ExtID__c, Nom_O_D_over_Indiv_Wires__c, Nom_Capacitance_Cond_to_Cond__c, Conductors_Insul_Thick_Mils__c, Phase_Conductor_AWG__c, Neutral_AWG__c, Phase_Conductor_Insul_Thick_mils__c, Thermocouple_Type__c, Shielding__c, Nominal_O_D_over_Insulation__c, Stranding__c, Nominal_Capacitance_B__c, Vel_of_Prop__c, Ground_No_x_AWG__c, Outer_Jacket_Thickness__c, Impedance__c, Nominal_O_D_over_Core__c, Nominal_O_D_over_Dielectric__c, Neutral_Stranding__c, Dielectric_Material__c, CAble_OD_Complete_Cable_inches__c, Standard_Length__c, Ground_Check_AWG__c, Spec_Sheet__c, Max_Tensile_Load_Install__c, Jacket_Thickness__c, Cable_Color_Size__c, Fiberglass_Braid__c, Conductors__c
        
     	set<String> specIgnore = new set<String>();
     	specIgnore.add('CreatedById');
        //specIgnore.add('IsDeleted');
        specIgnore.add('LastViewedDate');
        specIgnore.add('LastReferencedDate');
        specIgnore.add('SystemModstamp');
        specIgnore.add('CreatedDate');
        specIgnore.add('LastModifiedById');
        specIgnore.add('LastModifiedDate');	
        specIgnore.add('Id');	
        specIgnore.add('Title__c');	
        
     	
        String partQuery = CatalogApi.getQuery(Schema.SObjectType.Part_Numbers__c, partIgnore);
        String specQuery = CatalogApi.getQuery(Schema.SObjectType.Spec_Sheet__c, specIgnore);
        
        try {
        
        	String emptySpec = '0000';
        	//String singlePart = '1164';
        	
        	if(time_stamp == null || time_stamp.equals('')) {      
        		specQuery = 'SELECT ' + specQuery + ' , (select Name, AWG__c, Conductors__c, Pairs__c, Triads__c, Breaker_Frame__c, Breaker_of_Poles__c, Breaker_Max_Voltage__c, Breaker_Amps__c, Breaker_Interrupt_Rating_1__c, Breaker_Interrupt_Rating_2__c, Breaker_Interrupt_Rating_3__c, Breaker_Interrupt_Rating_4__c from Part_Numbers__r) FROM Spec_Sheet__c where ExtID__c != :emptySpec' + do_include_deleted;
        		partQuery = 'SELECT ' + partQuery + ', Spec_Sheet__r.ExtID__c FROM Part_Numbers__c where Spec_Sheet__r.ExtID__c != :emptySpec' + do_include_deleted;
        	} else {
        		DateTime dt = Datetime.valueOf(time_stamp);
            	String date_query = dt.format('yyyy-MM-dd\'T\'HH:mm:ss', 'GMT')+'Z';
            	
            	specQuery = 'SELECT ' + specQuery + ' , (select AWG__c, Conductors__c, Pairs__c, Triads__c, Breaker_Frame__c, Breaker_of_Poles__c, Breaker_Max_Voltage__c, Breaker_Amps__c, Breaker_Interrupt_Rating_1__c, Breaker_Interrupt_Rating_2__c, Breaker_Interrupt_Rating_3__c, Breaker_Interrupt_Rating_4__c from Part_Numbers__r) FROM Spec_Sheet__c where LastModifiedDate >='+date_query+ ' and ExtID__c != :emptySpec' + do_include_deleted;
            	partQuery = 'SELECT ' + partQuery + ', Spec_Sheet__r.ExtID__c FROM Part_Numbers__c where LastModifiedDate >='+date_query + do_include_deleted;
        	}
        	
        	result.Message = time_stamp;
        	
        	if(do_load_specs) {
        	
	        	for (Spec_Sheet__c spec : Database.query(specQuery) ) {
		            	
		        	SpecSheet sheet = new SpecSheet();
		            	
		            Double maxConds = 0;
		            for(Part_Numbers__c partNum : spec.Part_Numbers__r) {
		            		
		           		sheet.AWG.add(partNum.AWG__c);
		           		sheet.Conductors.add(partNum.Conductors__c);
		           		sheet.Pairs.add(partNum.Pairs__c);
		           		sheet.Triads.add(partNum.Triads__c);

                        if(partNum.Breaker_Frame__c != null) {
                            sheet.BreakerFrames.add(partNum.Breaker_Frame__c);
                        }
		            	
		           		if(partNum.Conductors__c > maxConds) {
		           			maxConds = (Double)partNum.Conductors__c;
		           		}
		            		
		           		if(partNum.Pairs__c != null) {
		            		Double pairsInt = Double.valueOf(partNum.Pairs__c);
		            		if(pairsInt > maxConds) {
			           			maxConds = pairsInt;
			           		}
		            	}
		           		
		           		if(partNum.Triads__c != null) {
			           		Double pairsInt = Double.valueOf(partNum.Triads__c);
			           		if(pairsInt > maxConds) {
			           			maxConds = pairsInt;
			           		}
		           		}

                        //Work around to get breaker frame properties on to specsheet
                        if(partNum.Breaker_Frame__c != null && partNum.Breaker_Frame__c != '') {
                            sheet.PartNumberObj = partNum;
                        }
		           	}
		            	
		           	if(spec.Color_Code__c != null) {
			         	List<Object> colorCodeObjs = (List<Object>)JSON.deserializeUntyped(spec.Color_Code__c);
			            	
			           	for(Integer i = colorCodeObjs.size()-1; i >= maxConds; i--) {
			           		colorCodeObjs.remove(i);
			           	}
			           	spec.Color_Code__c = JSON.serializePretty(colorCodeObjs);
		           	}

					sheet.SpecSheetObj = spec;
						
	            	result.SpecSheets.add(sheet);
	            }
        	}
            
            if(do_load_parts) {
            	
            	Map<String, SpecFieldSupress> fieldIgnores = new Map<String, SpecFieldSupress>();
            	
            	String ignoreQuery = 'SELECT Name, Spec_Sheet__r.ExtId__c FROM Catalog_Field_Ignore__c';
        		
            	for (Catalog_Field_Ignore__c ignore : Database.query(ignoreQuery) ) {
	            	SpecFieldSupress supress = fieldIgnores.get(ignore.Spec_Sheet__r.ExtId__c);
	            	if(supress == null) {
	            		supress = new SpecFieldSupress();
	            		fieldIgnores.put(ignore.Spec_Sheet__r.ExtId__c, supress);
	            	}
	            	supress.hiddenFields.add(ignore.Name);
	            }
	            
	            partIgnore.add('IsDeleted');
	            
	            List<Schema.SObjectField> fieldValues = Schema.SObjectType.Part_Numbers__c.fields.getMap().values();
	            
				for(sObject  partNum : Database.query(partQuery)) {
					
					Boolean isDeleted = (Boolean)partNum.get('IsDeleted');
					
					if(!isDeleted) {
						
						Part_Numbers__c partNumObj = (Part_Numbers__c)partNum;
						SpecFieldSupress supress = fieldIgnores.get(partNumObj.Spec_Sheet__r.ExtID__c);
						if(supress != null) {
							
							sObject newPart = new Part_Numbers__c();
							for(Schema.SObjectField value : fieldValues) {
	           					
	           					String fieldName = value.getDescribe().getName();
                                Boolean isFormulaField = value.getDescribe().isCalculated(); //NOTE:(fix)chrisw@launchdm.com
	           					
	           					if(!supress.hiddenFields.contains(fieldName) && !partIgnore.contains(fieldName) && !isFormulaField) {
	           						Object oldVal = partNum.get(fieldName);
	           						if(oldVal != null) {
	           							newPart.put(fieldName, partNum.get(fieldName));
	           						}
	           					}
							}
							
							partNum = (Part_Numbers__c)newPart;
								
						}
						
					}
					result.PartNumbers.add(partNum);
				}
            }

            result.Success = true;
             
        
        } catch (Exception e) {
            result.Message += '  --  Exception: ' + e.getMessage();
            System.debug('ERROR: '  + result.Message);
        }
        //result.Message = time_stamp;
        //result.Message = partQuery;
        return result;
    }
    
    @HttpPost
    webservice static APIResult doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        
        //Blob body = req.requestBody;
        //Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(body.toString());
        
        return new APIResult();  
    }
}