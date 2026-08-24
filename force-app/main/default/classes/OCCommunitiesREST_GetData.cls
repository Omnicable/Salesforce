@RestResource(urlMapping='/occommunities/v1/getdata/*')
global with sharing class OCCommunitiesREST_GetData {

	@HttpPost
    global static OCCommunitiesResource.GetDataResults getData(Integer offset,String typeStr,String searchText,String url){ 
        OCCommunitiesResource.GetDataRequest gdr = new OCCommunitiesResource.GetDataRequest();
        gdr.offset = offset;
        gdr.typeStr = typeStr;
        gdr.searchText = searchText;
        gdr.url = url;
        
        //TODO: fix later 
        OCCommunitiesResourceHelper.getDataPortal(gdr,OCCommunitiesResourceHelper.getContactIdOfRequest());
        return OCCommunitiesResourceHelper.getData(gdr,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}