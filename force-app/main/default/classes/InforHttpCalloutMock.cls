/**
 * @description HTTP Mock class for testing Infor API callouts
 */
@isTest
global class InforHttpCalloutMock implements HttpCalloutMock {
    
    private Integer statusCode;
    private String responseBody;
    private Map<String, String> responseHeaders;
    
    /**
     * @description Constructor with status code and response body
     * @param statusCode HTTP status code
     * @param responseBody Response body as string
     */
    public InforHttpCalloutMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
        this.responseHeaders = new Map<String, String>();
    }
    
    /**
     * @description Constructor with status code, response body, and headers
     * @param statusCode HTTP status code
     * @param responseBody Response body as string
     * @param responseHeaders Map of response headers
     */
    public InforHttpCalloutMock(Integer statusCode, String responseBody, Map<String, String> responseHeaders) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
        this.responseHeaders = responseHeaders != null ? responseHeaders : new Map<String, String>();
    }
    
    /**
     * @description Implement HttpCalloutMock interface
     * @param req HTTP request
     * @return HttpResponse Mock HTTP response
     */
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(responseBody);
        
        // Set response headers
        if (responseHeaders != null && !responseHeaders.isEmpty()) {
            for (String key : responseHeaders.keySet()) {
                res.setHeader(key, responseHeaders.get(key));
            }
        }
        
        return res;
    }
}