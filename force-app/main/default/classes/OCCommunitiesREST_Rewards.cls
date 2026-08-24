@RestResource(urlMapping='/occommunities/v1/rewards/*')
global with sharing class OCCommunitiesREST_Rewards {
    
	@HttpGet
    global static OCCommunitiesResource.RewardsResponse getRewards (){ 
    	return OCCommunitiesResourceHelper.getRewards(OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}