@RestResource(urlMapping='/occommunities/v1/redeemrewards/*')
global with sharing class  OCCommunitiesREST_RedeemRewards {
    
	@HttpPost
    global static OCCommunitiesResource.RewardsResponse redeemRewards(String name , String email, String accountName){ 
        OCCommunitiesResource.RewardsRequest rr = new OCCommunitiesResource.RewardsRequest();
        rr.Name = name;
        rr.Email = email;
        rr.AccountName = accountName;
    	return OCCommunitiesResourceHelper.redeemRewards(rr,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}