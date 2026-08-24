@RestResource(urlMapping='/occommunities/v1/pollfornotifications/*')
global with sharing class OCCommunitiesREST_PollForNotifications {

	@HttpPost
    global static OCCommunitiesResource.NotificationResults pollForNotifications(){ 
    	return OCCommunitiesResourceHelper.pollForNotifications(OCCommunitiesResourceHelper.getContactIdOfRequest());
  	}
}