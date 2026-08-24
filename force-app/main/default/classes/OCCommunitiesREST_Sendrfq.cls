@RestResource(urlMapping='/occommunities/v1/sendrfq/*')
global with sharing class OCCommunitiesREST_Sendrfq {
    
	@HttpPost
    global static OCCommunitiesResource.RFQResponse sendRFQ(String rFQData,String id,String image,List<OCCommunitiesResource.ImageData> imageData,String imageTitle,String typeStr,String accountNumber){
        OCCommunitiesResource.RFQRequest rfqr = new OCCommunitiesResource.RFQRequest();
        rfqr.RFQData = rFQData;
        rfqr.Id = id;
        rfqr.image = image;
        rfqr.imageData = imageData;
       	rfqr.imageTitle = imageTitle;
        rfqr.typeStr = typeStr;
        rfqr.accountNumber = accountNumber;
    	return OCCommunitiesResourceHelper.sendRFQ(rfqr,OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}