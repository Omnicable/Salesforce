@RestResource(urlMapping='/occommunities/v1/accountaccess/*')
global with sharing class OCCommunitiesREST_AccountAccess {
    
	@HttpPost
    global static OCCommunitiesResource.AccountAccessResults requestAccountAccess(List<Account> createRequest,List<Account> deleteAccountLinks,List<String> deletedIds, List<OCCommunitiesResource.AccountRequest> added, String regionalManagerId){ 
		OCCommunitiesResource.AccountAccessRequest aar = new OCCommunitiesResource.AccountAccessRequest();
        aar.CreateRequest = createRequest;
        aar.DeleteAccountLinks = deleteAccountLinks;
        aar.DeletedIds = deletedIds;
        aar.Added = added;
        aar.RegionalManagerId = regionalManagerId; 

    	return OCCommunitiesResourceHelper.requestAccountAccess(aar,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
    
}