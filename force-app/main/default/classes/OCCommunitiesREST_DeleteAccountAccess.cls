@RestResource(urlMapping='/occommunities/v1/deleteaccountaccess/*')
global with sharing class OCCommunitiesREST_DeleteAccountAccess {
    
	@HttpPost
    global static OCCommunitiesResource.DeleteAccountResult deleteAccountAccess(String id, String name){ 
		OCCommunitiesResource.DeleteAccountRequest dar = new OCCommunitiesResource.DeleteAccountRequest();
        dar.Id = id;
        dar.Name = name;
    	return OCCommunitiesResourceHelper.deleteAccountAccess(dar,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
    
}