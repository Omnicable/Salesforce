@RestResource(urlMapping='/occommunities/v1/profilePhoto/*')
global with sharing class OCCommunitiesREST_ProfilePhoto {
    
	@HttpPost
    global static OCCommunitiesResource.UploadPhotoResult uploadProfilePhoto(String image,String title){
        OCCommunitiesResource.UploadPhotoRequest upr = new OCCommunitiesResource.UploadPhotoRequest();
        upr.image = image;
        upr.title = title;
    	return OCCommunitiesResourceHelper.uploadProfilePhoto(upr, OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}