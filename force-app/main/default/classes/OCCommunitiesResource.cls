global class OCCommunitiesResource {
	
 	public Boolean isSandbox { get; set; }
     
    public OCCommunitiesResource(){
    	isSandbox = [SELECT Id, IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }
    
    global class QOCRequest{
        public string Id {get; set;}
        public string url {get;set;}
        
    }
    
    global class QOCDataResult {
        
        webservice Boolean Success = false;
        webservice Boolean Rewards = false;
        webservice String BuyerId = '';
        webservice List<UserRole> roles = new List<UserRole>();
        webservice String Message = '';
        webservice String AccountType = '';
        webservice List<QOCTypeData> quotes = new List<QOCTypeData>();
        webservice List<QOCTypeData> orders = new List<QOCTypeData>();

        //Added recentRelease
        webservice List<QOCTypeData> recentRelease = new List<QOCTypeData>();
        
        
        webservice List<QOCTypeData> credits = new List<QOCTypeData>();
   
        webservice List<OCC_ContactSlider__c> contactSlider = new List<OCC_ContactSlider__c>();
        webservice Contact contact = null;
        webservice User user = null;
        webservice User manager1 = null;
        webservice User manager2 = null;
        webservice User manager3 = null;
        webservice Account account = null;
        webservice List<Account> childAccounts = new List<Account>();
        webservice List<Account> allAccounts = new List<Account>();
        
        
        webservice List<OCC_ApprovedAccount__c> approvedAccounts = new List<OCC_ApprovedAccount__c>();
        webservice List<String> approvedAccountIds = new List<String>();
        
        webservice String siteUrl = '';
        
        webservice Group approvalGroup = null;
        webservice List<String> rmfPOValues = new List<String>();
        webservice List<Alternative_Part_Number__c> alternativePartNumbers = new List<Alternative_Part_Number__c>();
        webservice List<Alternative_Part_Number__c> filteredAlternativePartNumbers = new List<Alternative_Part_Number__c>();

        webservice List<Delivery_Address__c> deliveryAddresses = new List<Delivery_Address__c>();
        webservice List<QOCTypeData> masterOrders = new List<QOCTypeData>();
    }
    
    global class QOCTypeData {
        webservice QuotesOrdersCredits_Header__c header;
        webservice List<QuoteOrderCredit_Details__c> details = new List<QuoteOrderCredit_Details__c>();
        webservice List<QOCAttachment> attachments = new List<QOCAttachment>();
        webservice List<ContentDocumentLink> contentDocs = new List<ContentDocumentLink>();
    }
    
    global class QOCAttachment {
        webservice String image;
        webservice String url;
        webservice String title;
    }
    
    global class RewardsResponse {
     
        webservice Boolean Success = false;
        webservice String Message = '';
        webservice String OrginalValue = '';
        webservice String Value = '';
        webservice User user = null;
    }
    
    global class RewardsRequest {
     
        webservice String Name = '';
        webservice String Email = '';
        webservice String AccountName = '';
    }
    
    global class RFQResponse {
        webservice Boolean Success = false;
        webservice String Message = '';
        webservice QOCTypeData quoteData;
    }
    
    global class RFQRequest {
        webservice String RFQData = '';
        webservice String Id = '';
        webservice String image;
        webservice List<ImageData> imageData = new List<ImageData>();
        webservice String imageTitle;
        webservice String typeStr;
        webservice String AccountNumber = '';
        webservice String jobReferenceNumber = 'Pending...';
        webservice String markNumber = 'Pending...';
    }
    
    global class EmailRequest {
        webservice String Email = '';
        webservice String Subject = '';
        webservice String Message = '';
    }
    
    global class ImageData{
         webservice String image;
         webservice String name;
        
    }
    
    global class ProfileResult{
        webservice string Message='';
        webservice Boolean Success = false;
    }
    
    global class ProfileRequest{
    	
    	public String contactId{get;set;}
        public String firstName{get;set;}
        public String lastName{get;set;}
        public String email{get;set;}
        public String phone{get;set;}
        public String month{get;set;}
        public String day{get;set;}
        public String year{get;set;}
    }
    
    global class UploadPhotoRequest{
        webservice String image;
        webservice String title;
        
    }
    
    global class UploadPhotoResult{
        webservice Boolean Success = false;
        webservice String Message = '';
        webservice User user = null;
        webservice Contact contact = null;
        
    }
    
    public static Boolean runningInASandbox() {
	  return OCCommunitiesResourceHelper.runningInASandbox();
	}
    
    @RemoteAction
    webservice static UploadPhotoResult uploadProfilePhoto(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.UploadPhotoRequest request = (OCCommunitiesResource.UploadPhotoRequest)parser.readValueAs(OCCommunitiesResource.UploadPhotoRequest.class);
        return OCCommunitiesResourceHelper.uploadProfilePhoto(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    @RemoteAction
    webservice static RewardsResponse getRewards() {
        return OCCommunitiesResourceHelper.getRewards(OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    @RemoteAction
    webservice static QOCDataResult findQOCById(String id){
        JSONParser parser = JSON.createParser(id);
        OCCommunitiesResource.QOCRequest request = (OCCommunitiesResource.QOCRequest)parser.readValueAs(OCCommunitiesResource.QOCRequest.class);
        return OCCommunitiesResourceHelper.findQOCById(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    

    @RemoteAction
    webservice static QOCDataResult getCommunitiesData(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.QOCRequest request = (OCCommunitiesResource.QOCRequest)parser.readValueAs(OCCommunitiesResource.QOCRequest.class);
        return OCCommunitiesResourceHelper.getCommunitiesData(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    @RemoteAction
    webservice static RFQResponse sendRFQ(String params) {
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.RFQRequest request = (OCCommunitiesResource.RFQRequest)parser.readValueAs(OCCommunitiesResource.RFQRequest.class);
        return OCCommunitiesResourceHelper.sendRFQ(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    
    @RemoteAction
    webservice static RFQResponse sendEmail(String params) {
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.EmailRequest request = (OCCommunitiesResource.EmailRequest)parser.readValueAs(OCCommunitiesResource.EmailRequest.class);
    
        return OCCommunitiesResourceHelper.sendEmail(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    @RemoteAction
    webservice static RewardsResponse redeemRewards(String params) { // redeemRewards(String name, String email, Integer amount, String message) {    
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.RewardsRequest request = (OCCommunitiesResource.RewardsRequest)parser.readValueAs(OCCommunitiesResource.RewardsRequest.class);
        
        return OCCommunitiesResourceHelper.redeemRewards(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    } 
    
    @RemoteAction
    webservice static ProfileResult updateProfile(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.ProfileRequest request = (OCCommunitiesResource.ProfileRequest)parser.readValueAs(OCCommunitiesResource.ProfileRequest.class);

        return OCCommunitiesResourceHelper.updateProfile(request);
    }

    @RemoteAction
    webservice static QOCDataResult getInitialData(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.QOCRequest request = (OCCommunitiesResource.QOCRequest)parser.readValueAs(OCCommunitiesResource.QOCRequest.class);
        return OCCommunitiesResourceHelper.getInitialData(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    
    
    ////////////
    
    global class AccountAccessRequest {
        webservice List<Account> CreateRequest = new List<Account>();
        webservice List<Account> DeleteAccountLinks = new List<Account>();
        
        webservice List<String> DeletedIds = new List<String>();
        webservice List<AccountRequest> Added = new List<AccountRequest>();
        
        webservice String RegionalManagerId = ''; 
    }
    
    global class AccountRequest {
    	webservice String Name = '';
    	webservice String Account = '';
    }
    
    global class AccountAccessResults {
        webservice String Message = '';
        webservice Boolean Success = false;
        webservice List<String> requestedIds = new List<String>();

    }
    
    @RemoteAction
    webservice static AccountAccessResults requestAccountAccess(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.AccountAccessRequest request = (OCCommunitiesResource.AccountAccessRequest)parser.readValueAs(OCCommunitiesResource.AccountAccessRequest.class);
        return OCCommunitiesResourceHelper.requestAccountAccess(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    
    //////////////
    
    global class DeleteAccountRequest {
    	//webservice Account currAccount = new Account();
    	webservice String Name = '';
    	webservice String Id = '';
    }
    
     global class DeleteAccountResult {
     	webservice String Message = '';
     	webservice Boolean Success = false;
    	webservice String  DeletedId = '';
    }
    
    @RemoteAction
    webservice static DeleteAccountResult deleteAccountAccess(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.DeleteAccountRequest request = (OCCommunitiesResource.DeleteAccountRequest)parser.readValueAs(OCCommunitiesResource.DeleteAccountRequest.class);
                    
        return OCCommunitiesResourceHelper.deleteAccountAccess(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
    
    
    global class NotificationResults{
    	webservice String Message = '';
    	webservice Boolean hasMessage = false;
    }
    
    @RemoteAction
    webservice static NotificationResults pollForNotifications(String params){
        return OCCommunitiesResourceHelper.pollForNotifications(OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }
         
    global class GetDataResults{
    	webservice Boolean Success = false;
    	webservice String Message = '';
    	webservice Integer totalCount = 0;
    	webservice List<QOCTypeData> quotes = new List<QOCTypeData>();
    	webservice List<QOCTypeData> orders = new List<QOCTypeData>();
    	webservice List<QOCTypeData> credits = new List<QOCTypeData>();
    	webservice List<String> Ids = new List<String>();
      
    }
    
    global class GetDataRequest{
    	webservice Integer offset = 0;
    	webservice String typeStr = '';
    	webservice String searchText = ''; 
    	webservice String url = ''; 
    }
    
    @RemoteAction
    webservice static GetDataResults getData(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.GetDataRequest request = (OCCommunitiesResource.GetDataRequest)parser.readValueAs(OCCommunitiesResource.GetDataRequest.class);

        return OCCommunitiesResourceHelper.getData(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }

    @RemoteAction
    webservice static GetDataResults getDataPortal(String params){
        JSONParser parser = JSON.createParser(params);
        OCCommunitiesResource.GetDataRequest request = (OCCommunitiesResource.GetDataRequest)parser.readValueAs(OCCommunitiesResource.GetDataRequest.class);
        return OCCommunitiesResourceHelper.getDataPortal(request,OCCommunitiesResourceHelper.getContactIdByUserId(UserInfo.getUserId()));
    }




    // global class alternativePartsRequest{
    //     List<String> accountIds = new List<String>();
    // }

    // @RemoteAction
    // webservice static List<Alternative_Part_Number__c> getAlternativePartNumbers(String params){
    //     JSONParser parser = JSON.createParser(params);
    //     OCCommunitiesResource.alternativePartsRequest request = (OCCommunitiesResource.alternativePartsRequest)parser.readValueAs(OCCommunitiesResource.alternativePartsRequest.class);
    //     return OCCommunitiesResourceHelper.getAlternativePartNumbers(request.accountIds);
    // }
}