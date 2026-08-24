/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class CatalogApiTest {

    static testMethod void myUnitTest() {
    	
    	Spec_Sheet__c spec = new Spec_Sheet__c();
    	spec.Name = 'One';
    	spec.ExtID__c = '111';
    	spec.Voltage__c = '1';
    	spec.Cable_Type__c = 'Type';
        spec.Color_Code__c = '[]';
    	insert(spec);
    	
    	Part_Numbers__c part = new Part_Numbers__c();     	
        part.ExtID__c = '111';
        part.Spec_Sheet__c = spec.Id;
        part.Pairs__c = '4';
        part.Triads__c = '4';
        part.Breaker_Frame__c = 'Test';
        insert(part);
        
        Catalog_Field_Ignore__c ignore = new Catalog_Field_Ignore__c();
        ignore.Name = 'AWG__c';
        ignore.Spec_Sheet__c = spec.Id;
    	insert(ignore);
    	
    	CatalogApi.APIResult result1 = CatalogApi.doGet();

        System.debug(result1.Message);

        CatalogApi.doPost();
        
    	RestContext.request = new RestRequest();
    	RestContext.request.addParameter('get_spec_sheets', 'true');
    	RestContext.request.addParameter('get_part_numbers', 'true');
    	//time_stamp = req.params.get('time_stamp');
    	
    	CatalogApi.doGet();
    	
        delete(ignore);
    }
}