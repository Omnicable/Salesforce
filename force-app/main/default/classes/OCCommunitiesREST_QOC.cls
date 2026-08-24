@RestResource(urlMapping='/occommunities/v1/qoc/*')
global with sharing class OCCommunitiesREST_QOC {
	 
	@HttpPOST
    global static OCCommunitiesResource.QOCDataResult findQOCById(String id,String url){
        OCCommunitiesResource.QOCRequest qocr = new OCCommunitiesResource.QOCRequest();
        qocr.id = id;
        qocr.url = url;
    	return OCCommunitiesResourceHelper.findQOCById(qocr, OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}