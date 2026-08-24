@RestResource(urlMapping='/MixPanelApi/*')

global class OCCMixPanelApi {
	
    @HttpPost 
    global static Void doPost(){
    
        RestRequest req = RestContext.request;
        Map<String, String> paramMap = new Map<String, String>();
        paramMap = RestContext.request.params;
        
        String criteria = paramMap.get('criteria');
        if (test.isRunningTest()) criteria='Amount_5000_10';

        
        JSONParser parser = JSON.createParser(paramMap.get('users'));
        List<String> ContactIds = new List<String>();
		
        while (parser.nextToken() != null) {
        	 
            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && parser.getText() == 'contact_id' ) {
                
                String fieldName = parser.getText();
                parser.nextToken();
                String fieldvalue = parser.getText();
                ContactIds.add(fieldvalue);
                parser.nextToken();

            }
            
        }
		
        //Get All Contacts and check criteria
        for(Contact contact : [Select Id, Name, Email, OCC_Rewards__c, OCC_RewardsValue__c from Contact where Id IN: ContactIds]){
             
        	for(OCC_BonusReward__c BonusReward : [SELECT Id, Name, Contact__c, ActionDescription__c, Redeemed__c, RedeemMessage__c, RewardValue__c FROM OCC_BonusReward__c WHERE Contact__c =: contact.Id AND Redeemed__c = false AND Name =: criteria]){
        		BonusReward.Redeemed__c = true;
    			    			
    			if(contact.OCC_Rewards__c == true){
    				
    				contact.OCC_RewardsValue__c +=  BonusReward.RewardValue__c;
    				update contact;
    				update BonusReward;
    				
    			}else{
    				
    				//Send Email
                    String title = ' Congrats on placing ' + BonusReward.ActionDescription__c + ' on myomnicable.com';
                    Boolean successful = sendRewardsEmail(BonusReward.RewardValue__c, contact.Name, contact.Email, title);
                    
                    if(successful){
                    	update BonusReward;
                    }

    			}
    			
        	}
        
        } 

    }
    
   	public static Boolean runningInASandbox() {
	  return [SELECT Id, IsSandbox FROM Organization LIMIT 1].IsSandbox;
	}
    
    @RemoteAction
    webservice static Boolean sendRewardsEmail(Decimal amount, String name, String email, String subject) {   
        Boolean Success = false;
        
     
        Http httpProtocol = new Http();
        HttpRequest req = new HttpRequest();
        
        String endpoint ='';
        String message = '';
        amount = amount * 100;
        
        if(runningInASandbox()){
        	endpoint = 'https://sandbox.tangocard.com/raas/v1.1/orders';
        	req.setHeader('authorization', 'Basic T21uaUNhYmxlVGVzdDpJQnUwU3BJa1BXcHdjRHFmYVlZS0tQZmo3NnEyWTNnYThaWWZFekJWeG5rYWZ2dDBHZGRHaFJ2VGZPbw==');
            req.setBody('{"customer": "OmniTestCustomer2", "account_identifier": "OmniTestAccount2", "campaign": "", "recipient": { "name": "' + name + '", "email": "' +  email + '" }, "sku": "TNGO-E-V-STD", "amount": ' + amount +', "reward_from": "OmniCable", "reward_subject": "' + subject + '", "reward_message": "' + message + '", "send_reward": true}');	
        }else{
        	
        	endpoint = 'https://api.tangocard.com/raas/v1.1/orders';
        	req.setHeader('authorization', 'Basic T21uaUNhYmxlOjZkRXlvTlpCTGp5Z0ZRZkhrQXRnZGRVMGVVQjh5RUUxdXpzNjdLRVNVbmxhQXp2RERwTEpBZ29j');
           	req.setBody('{"customer": "OmniCable", "account_identifier": "OmniCable", "campaign": "", "recipient": { "name": "' + name + '", "email": "' +  email + '" }, "sku": "TNGO-E-V-STD", "amount": ' + amount +', "reward_from": "OmniCable", "reward_subject": "' + subject + '", "reward_message": "' + message + '", "send_reward": true}');	            
        }
        	message = subject;
        	req.setEndPoint(endpoint);
       		req.setMethod('POST');
        	req.setHeader('Content-Type', 'application/json; charset=utf-8');
        
        try {
            	
            amount = amount*100;	            
			if (test.isRunningTest()) Test.setMock(HttpCalloutMock.class, new OCCommunitiesResourceTest());
            HTTPResponse res = httpProtocol.send(req);     
            
            if (String.valueOf(res.getStatusCode()).startsWith('2')){

                Success = true;
            }else{
                Success = false;

            }
                      
        } catch(System.CalloutException e) {
            Success = false;
        }
        
        return Success;

    } 
    
    

}