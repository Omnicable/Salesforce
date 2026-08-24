/**
 * @description Test class for InforAuthService
 */
@isTest
private class InforAuthServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create ERP Settings custom settings
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new ERPSettings__c();
        }
        settings.clientID__c = 'test_client_id';
        settings.clientSecret__c = 'test_client_secret';
        settings.username__c = 'test_username';
        settings.password__c = 'test_password';
        settings.tokenURL__c = 'https://test.example.com/oauth/token';
        settings.baseURL__c = 'https://test.example.com';
        upsert settings;
    }
    
    @isTest
    static void testGetAccessToken_ValidToken() {
        // Setup: Create settings with valid token
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        settings.accessToken__c = 'valid_access_token';
        settings.tokenExpiration__c = Datetime.now().addHours(1);
        update settings;
        
        Test.startTest();
        String token = InforAuthService.getAccessToken();
        Test.stopTest();
        
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals('valid_access_token', token, 'Should return existing valid token');
    }
    
    @isTest
    static void testGetAccessToken_ExpiredToken() {
        // Setup: Create settings with expired token
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        settings.accessToken__c = 'expired_token';
        settings.tokenExpiration__c = Datetime.now().addHours(-1);
        
        // Mock HTTP response for authentication
        String mockResponse = '{"access_token":"new_access_token","token_type":"Bearer","expires_in":3600,"refresh_token":"refresh_token_value"}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(200, mockResponse));
        
        update settings;
        
        Test.startTest();
        String token = InforAuthService.getAccessToken();
        Test.stopTest();
        
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals('new_access_token', token, 'Should return new token from authentication');
        
        // Verify settings were updated
        ERPSettings__c updatedSettings = ERPSettings__c.getOrgDefaults();
        System.assertNotEquals(null, updatedSettings.tokenExpiration__c, 'Token expiration should be set');
        System.assert(updatedSettings.tokenExpiration__c > Datetime.now(), 'Token expiration should be in the future');
    }

    @isTest
    static void testGetAccessToken_ExpiredToken_UsesRefreshToken() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        settings.accessToken__c = 'expired_token';
        settings.tokenExpiration__c = Datetime.now().addHours(-1);
        settings.refreshToken__c = 'refresh_token_value';
        update settings;

        String refreshResponse = '{"access_token":"refreshed_access_token","token_type":"Bearer","expires_in":3600,"refresh_token":"new_refresh_token"}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(200, refreshResponse));

        Test.startTest();
        String token = InforAuthService.getAccessToken();
        Test.stopTest();

        System.assertEquals('refreshed_access_token', token, 'Should return refreshed access token');

        ERPSettings__c updatedSettings = ERPSettings__c.getOrgDefaults();
        System.assert(updatedSettings.tokenExpiration__c > Datetime.now(), 'Refreshed token expiration should be in the future');
        System.assertEquals('new_refresh_token', updatedSettings.refreshToken__c, 'Refresh token should be updated from refresh response');
    }
    
    @isTest
    static void testGetAccessToken_NoToken() {
        // Setup: Create settings without token
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        settings.accessToken__c = null;
        settings.tokenExpiration__c = null;
        
        // Mock HTTP response for authentication
        String mockResponse = '{"access_token":"new_access_token","token_type":"Bearer","expires_in":3600,"refresh_token":"refresh_token_value"}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(200, mockResponse));
        
        update settings;
        
        Test.startTest();
        String token = InforAuthService.getAccessToken();
        Test.stopTest();
        
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals('new_access_token', token, 'Should return new token from authentication');
    }
    
    @isTest
    static void testGetAccessToken_MissingCredentials() {
        // Setup: Remove credentials
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        settings.clientID__c = null;
        settings.clientSecret__c = null;
        settings.tokenURL__c = null;
        settings.accessToken__c = null;
        settings.tokenExpiration__c = null;
        update settings;
        
        Test.startTest();
        String token = InforAuthService.getAccessToken();
        Test.stopTest();
        
        System.assertEquals(null, token, 'Token should be null when credentials are missing');
    }
    
    @isTest
    static void testAuthenticateWithClientCredentials_Success() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        
        // Mock HTTP response
        String mockResponse = '{"access_token":"test_access_token_123456789","token_type":"Bearer","expires_in":3600,"refresh_token":"test_refresh_token"}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(200, mockResponse));
        
        Test.startTest();
        String token = InforAuthService.authenticateWithClientCredentials(settings);
        Test.stopTest();
        
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals('test_access_token_123456789', token, 'Should return access token from response');
        
        // Verify settings were updated
        ERPSettings__c updatedSettings = ERPSettings__c.getOrgDefaults();
        System.assertNotEquals(null, updatedSettings.accessToken__c, 'Access token should be set');
        System.assertNotEquals(null, updatedSettings.tokenExpiration__c, 'Token expiration should be set');
        System.assertEquals('test_refresh_token', updatedSettings.refreshToken__c, 'Refresh token should be set');
    }
    
    @isTest
    static void testAuthenticateWithClientCredentials_Non200Response() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        
        // Mock HTTP error response
        String mockResponse = '{"error":"invalid_client","error_description":"Invalid client credentials"}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(401, mockResponse));
        
        Test.startTest();
        String token = InforAuthService.authenticateWithClientCredentials(settings);
        Test.stopTest();
        
        // Method should still return null or handle error gracefully
        // Based on the implementation, it doesn't throw, so it should return null
        System.assertEquals(null, token, 'Token should be null on authentication failure');
    }
    
    @isTest
    static void testAuthenticateWithClientCredentials_LongToken() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        
        // Create a token longer than 255 characters to test token splitting
        String longToken = 'a'.repeat(500);
        String mockResponse = '{"access_token":"' + longToken + '","token_type":"Bearer","expires_in":3600}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(200, mockResponse));
        
        Test.startTest();
        String token = InforAuthService.authenticateWithClientCredentials(settings);
        Test.stopTest();
        
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals(longToken, token, 'Should return full token');
        
        // Verify token was split across multiple fields
        ERPSettings__c updatedSettings = ERPSettings__c.getOrgDefaults();
        System.assertNotEquals(null, updatedSettings.accessToken__c, 'Access token part 1 should be set');
        System.assertNotEquals(null, updatedSettings.accessToken2__c, 'Access token part 2 should be set');
        // Token should be split across multiple fields
    }
    
    @isTest
    static void testGetAccessToken_NoSettings() {
        // Delete all settings
        List<ERPSettings__c> settingsList = [SELECT Id FROM ERPSettings__c];
        if (!settingsList.isEmpty()) {
            delete settingsList;
        }
        
        Test.startTest();
        String token = InforAuthService.getAccessToken();
        Test.stopTest();
        
        // Should handle gracefully when settings are null
        System.assertEquals(null, token, 'Token should be null when settings are null');
    }
    
    @isTest
    static void testAuthenticateWithClientCredentials_NoExpiresIn() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        
        // Mock HTTP response without expires_in
        String mockResponse = '{"access_token":"test_token","token_type":"Bearer"}';
        Test.setMock(HttpCalloutMock.class, new InforHttpCalloutMock(200, mockResponse));
        
        Test.startTest();
        String token = InforAuthService.authenticateWithClientCredentials(settings);
        Test.stopTest();
        
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals('test_token', token, 'Should return access token');
    }
}