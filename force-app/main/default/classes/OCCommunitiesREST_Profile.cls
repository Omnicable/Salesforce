@RestResource(urlMapping='/occommunities/v1/profile/*')
global with sharing class OCCommunitiesREST_Profile {
    
	@HttpPost
    global static OCCommunitiesResource.ProfileResult updateProfile(String firstName,String lastName,String email,String phone,String birthdateMonth,String birthdateDay,String birthdateYear){ 
        OCCommunitiesResource.ProfileRequest pr = new OCCommunitiesResource.ProfileRequest();
        RestRequest request = RestContext.request;
        String contactId = request.requestURI.substring(request.requestURI.lastIndexOf('/')+1);
        pr.contactId = contactId;
        pr.firstName = firstName;
        pr.lastName = lastName;
        pr.email = email;
        pr.phone = phone;
        pr.month = birthdateMonth;
        pr.day = birthdateDay;
        pr.year = birthdateYear;
    	return OCCommunitiesResourceHelper.updateProfile(pr);
  	}
}