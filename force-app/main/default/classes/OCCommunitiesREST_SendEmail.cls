@RestResource(urlMapping='/occommunities/v1/sendemail/*')
global with sharing class OCCommunitiesREST_SendEmail {
	@HttpPost
    global static OCCommunitiesResource.RFQResponse sendEmail (String email,String subject,String message){ 
        OCCommunitiesResource.EmailRequest eq = new OCCommunitiesResource.EmailRequest();
		eq.Email = email;
		eq.Subject = subject;
		eq.Message = message;
    	return OCCommunitiesResourceHelper.sendEmail(eq,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}