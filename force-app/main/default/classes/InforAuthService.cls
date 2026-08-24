/**
 * @description
 * OAuth authentication helper for Infor M3 integrations.
 *
 * Retrieves, caches, and refreshes access tokens stored on {@link ERPSettings__c}.
 * Callers typically invoke {@link #getAccessToken()} before building Infor API requests
 * (for example, via {@link InforBaseAPIService#buildRequest()}).
 *
 * Token lifecycle:
 * - Returns the cached token when {@code tokenExpiration__c} is still in the future
 * - Authenticates with the password grant when the token is missing or expired
 * - Persists the token across up to five 255-character fields to support long tokens
 *
 * Required {@link ERPSettings__c} fields for authentication:
 * - {@code clientID__c}, {@code clientSecret__c}, {@code tokenURL__c}
 * - {@code username__c}, {@code password__c}
 *
 * @see ERPSettings__c
 * @see InforBaseAPIService
 * @see InforIntegrationService
 */
public with sharing class InforAuthService {
    
    /**
     * @description Data transfer object for OAuth token endpoint responses.
     */
    public class TokenResponse {
        /** @description Bearer access token returned by the token endpoint. */
        public String access_token;
        /** @description Refresh token returned when the grant supports token renewal. */
        public String refresh_token;
        /** @description Token type (typically {@code Bearer}). */
        public String token_type;
        /** @description Token lifetime in seconds from issuance. */
        public Integer expires_in;
    }
    
    /**
     * @description
     * Returns a valid Infor access token from org-default {@link ERPSettings__c}.
     *
     * When a cached token exists and {@code tokenExpiration__c} is greater than or equal to
     * the current time, the cached value is returned without a callout. Otherwise, when
     * {@code clientID__c}, {@code clientSecret__c}, and {@code tokenURL__c} are configured,
     * {@link #authenticateWithClientCredentials(ERPSettings__c)} is invoked to obtain and
     * persist a new token.
     *
     * @return Access token string, or {@code null} when settings are missing or credentials
     *         are not configured.
     */
    public static String getAccessToken() {
        ERPSettings__c settings = ERPSettings__c.getOrgDefaults();
        
        System.debug('settings: ' + JSON.serialize(settings));
        
        String token = getTokenFields(settings);
        if( token != null && settings.tokenExpiration__c != null && settings.tokenExpiration__c >= Datetime.now()) {
            System.debug('token: ' + token);
            return token;
        }
        
        if (settings.clientID__c != null && settings.clientSecret__c != null && settings.tokenURL__c != null) {
            System.debug('authenticating with client credentials');
            return authenticateWithClientCredentials(settings);
        }
        
        return null;
    }
    
    /**
     * @description
     * Authenticates against the Infor OAuth token endpoint using the password grant.
     *
     * Sends a {@code POST} request to {@code settings.tokenURL__c} with
     * {@code application/x-www-form-urlencoded} body containing:
     * - {@code grant_type=password}
     * - {@code client_id}, {@code client_secret}
     * - {@code username}, {@code password}
     *
     * On success, updates {@link ERPSettings__c} with:
     * - Access token (split via {@link #setTokenFields(ERPSettings__c, String)})
     * - {@code tokenExpiration__c} when {@code expires_in} is present
     * - {@code refreshToken__c} when {@code refresh_token} is present
     *
     * @param settings Org-default ERP settings containing token URL and credentials.
     * @return Access token string from the token response, or {@code null} when authentication fails.
     */
    public static String authenticateWithClientCredentials(ERPSettings__c settings) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.tokenURL__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'grant_type=password' +
            '&client_id=' + EncodingUtil.urlEncode(settings.clientID__c, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(settings.clientSecret__c, 'UTF-8') +
            '&username=' + EncodingUtil.urlEncode(settings.username__c, 'UTF-8') +
            '&password=' + EncodingUtil.urlEncode(settings.password__c, 'UTF-8');
        
        req.setBody(body);
        
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            System.debug('Authentication failed: ' + res.getBody());
        }
        System.debug('Authentication response: ' + res.getBody());
        
        Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        // Update ERPSettings__c with new access token and expiration
        String accessToken = (String) tokenData.get('access_token');
        settings.accessToken__c = accessToken;
        
        System.debug('accessToken: ' + accessToken);
        
        // Split access_token into 5 different fields with max 255 characters each
        InforAuthService.setTokenFields(settings, accessToken);
        
        if (tokenData.containsKey('expires_in')) {
            // expires_in is in seconds from now
            settings.tokenExpiration__c = Datetime.now().addSeconds(((Decimal) tokenData.get('expires_in')).intValue());
        }
        if (tokenData.containsKey('refresh_token')) {
            settings.refreshToken__c = (String) tokenData.get('refresh_token');
        }
        saveSettings(settings);
        return (String) tokenData.get('access_token');
    }
    
    /**
     * @description Updates org-default ERP settings when the running user has update permission.
     * @param settings ERP settings record to persist.
     */
    private static void saveSettings(ERPSettings__c settings) {
        try{
            update settings;
        } catch (Exception e) {
            System.debug('Error updating ERP Settings: ' + e.getMessage());
        }
        
    }
    
    /**
     * @description
     * Reassembles a full access token from the split token fields on {@link ERPSettings__c}.
     *
     * Reads and concatenates, in order:
     * - {@code accessToken__c}
     * - {@code accessToken2__c}
     * - {@code accessToken3__c}
     * - {@code accessToken4__c}
     * - {@code accessToken5__c}
     *
     * @param settings ERP settings record containing token part fields.
     * @return Full access token string, or {@code null} when no token parts are set.
     */
    public static String getTokenFields(ERPSettings__c settings) {
        
        String token = '';
        if (settings.accessToken__c != null) {
            token += settings.accessToken__c;
        }
        if (settings.accessToken2__c != null) {
            token += settings.accessToken2__c;
        }
        if (settings.accessToken3__c != null) {
            token += settings.accessToken3__c;
        }
        if (settings.accessToken4__c != null) {
            token += settings.accessToken4__c;
        }
        if (settings.accessToken5__c != null) {
            token += settings.accessToken5__c;
        }
        
        return token != '' ? token : null;
    }
    
    /**
     * @description
     * Splits a long access token into up to five 255-character fields on {@link ERPSettings__c}.
     *
     * Field assignment:
     * - {@code accessToken__c} — characters 0–254
     * - {@code accessToken2__c} — characters 255–509
     * - {@code accessToken3__c} — characters 510–764
     * - {@code accessToken4__c} — characters 765–1019
     * - {@code accessToken5__c} — characters 1020–1274
     *
     * When {@code accessToken} is {@code null}, no fields are modified.
     *
     * @param settings ERP settings record to populate with token parts.
     * @param accessToken Full access token to split across token part fields.
     */
    public static void setTokenFields(ERPSettings__c settings, String accessToken) {
        if (accessToken != null) {
            Integer partLength = 255;
            Integer totalLength = accessToken.length();
            
            settings.accessToken__c = (totalLength > 0) ? accessToken.substring(0, Math.min(partLength, totalLength)) : null;
            settings.accessToken2__c = (totalLength > partLength) ? accessToken.substring(partLength, Math.min(partLength * 2, totalLength)) : null;
            settings.accessToken3__c = (totalLength > partLength * 2) ? accessToken.substring(partLength * 2, Math.min(partLength * 3, totalLength)) : null;
            settings.accessToken4__c = (totalLength > partLength * 3) ? accessToken.substring(partLength * 3, Math.min(partLength * 4, totalLength)) : null;
            settings.accessToken5__c = (totalLength > partLength * 4) ? accessToken.substring(partLength * 4, Math.min(partLength * 5, totalLength)) : null;
        }
    }
    
}