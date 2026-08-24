@RestResource(urlMapping='/occommunities/v1/communitiesdata/*')
global with sharing class OCCommunitiesREST_Communitiesdata {
    
	@HttpPost
    global static OCCommunitiesResource.QOCDataResult getCommunitiesData(String id, String url){ 
		OCCommunitiesResource.QOCRequest qoc1 = new OCCommunitiesResource.QOCRequest();
        qoc1.id = id;
        qoc1.url = url;

    	return OCCommunitiesResourceHelper.getCommunitiesData(qoc1,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}