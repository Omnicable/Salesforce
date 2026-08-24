/**
 * @description Batch class to delete, update records for fixing data post deployment
 * @param startDate The start date to update the Sent_to_Customer__c field
 * @param endDate The end date to update the Sent_to_Customer__c field
 * @param recordType The record type to update the Sent_to_Customer__c field
 * @param action The action to perform on the record
 */

public with sharing class InvoiceBatchUpdate implements Database.Batchable<SObject>, Database.Stateful {
    
    private Date startDate;
    private Date endDate;
    sObject recordType;
    String action;
    
    Integer total = 0;
    
    public InvoiceBatchUpdate(Date startDate, Date endDate, sObject recordType, String action) {
        this.startDate = startDate;
        this.endDate = endDate;
        this.recordType = recordType;
        this.action = action;
    }
    
    
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        if(action == 'FIX_CANCELLED_OPPORTUNITIES'){
            return Database.getQueryLocator([select id, Line_Status__c, TotalPrice, UnitPrice, Quantity from OpportunityLineItem where Line_Status__c = 'Cancelled' and TotalPrice != 0 ORDER BY OpportunityId]);
        }else if (action == 'FIX_CANCELLED_QUOTES'){
            return Database.getQueryLocator([select id, Line_Status__c, UnitPrice, Quantity, Quote_Order_Credit_Detail__r.Unit_Price__c from QuoteLineItem where Line_Status__c != 'Cancelled' and Quote_Order_Credit_Detail__r.Unit_Price__c != null ORDER BY QuoteId]);
        } else if (action == 'FIX_CANCELLED_ORDERS'){
            return Database.getQueryLocator([select id,  Line_Status__c, UnitPrice, Quantity, Quote_Order_Credit_Detail__r.Unit_Price__c from OrderItem where Line_Status__c != 'Cancelled' and Quote_Order_Credit_Detail__r.Unit_Price__c != null ORDER BY OrderId]);
        }else if(action == 'Total Sales Update'){
            return Database.getQueryLocator([SELECT Id, New_Total_Order_Sales__c, Total_Order_Sales__c
            FROM QuotesOrdersCredits_Header__c
            WHERE  Customer__r.OCC_Rewards__c = true and CreatedDate >= :startDate AND CreatedDate < :endDate]);
        } else if(recordType.getSObjectType() == Schema.SalesHistory__c.SObjectType) {
            return Database.getQueryLocator([SELECT Id, Invoice_Date__c
            FROM SalesHistory__c
            WHERE Invoice_Date__c >= :startDate AND Invoice_Date__c < :endDate]);
        }else if (recordType.getSObjectType() == Schema.Sales_History_Line_Item__c.SObjectType) {
            return Database.getQueryLocator([SELECT Id, InvoiceDate__c
            FROM Sales_History_Line_Item__c
            WHERE InvoiceDate__c >= :startDate AND InvoiceDate__c < :endDate]);
        }else if(recordType.getSObjectType() == Schema.QuotesOrdersCredits_Header__c.SObjectType) {
            return Database.getQueryLocator([SELECT Id, CreatedDate
            FROM QuotesOrdersCredits_Header__c
            WHERE CreatedDate >= :startDate AND CreatedDate < :endDate]);
        }else if (recordType.getSObjectType() == Schema.Vendor__c.SObjectType) {
            return Database.getQueryLocator([SELECT Id, CreatedDate
            FROM Vendor__c
            WHERE CreatedDate >= :startDate AND CreatedDate < :endDate]);
        } else if (recordType.getSObjectType() == Schema.Opportunity.SObjectType) {
            return Database.getQueryLocator([SELECT Id, Order_Number__c
            FROM Opportunity
            WHERE Amount = null]);
            
        }else if(recordType.getSObjectType() == Schema.Opportunity_Sync_Report__c.SObjectType) {
            return Database.getQueryLocator([SELECT Id
            FROM Opportunity_Sync_Report__c
            WHERE CreatedDate >= :startDate AND CreatedDate < :endDate]);
            
        }else {
            // Return an empty scope for unsupported types.
            return Database.getQueryLocator([SELECT Id FROM Sales_History_Line_Item__c WHERE Id = null]);
        }
        
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        System.debug('count: ' + scope.size());
        
        if(action == 'FIX_CANCELLED_OPPORTUNITIES'){
            for(OpportunityLineItem oli : (List<OpportunityLineItem>) scope) {
                oli.TotalPrice = 0;
            }
            update scope;
        }else if(action == 'FIX_CANCELLED_QUOTES'){
            for(QuoteLineItem qli : (List<QuoteLineItem>) scope) {
                qli.UnitPrice = qli.Quote_Order_Credit_Detail__r.Unit_Price__c;
            }
            update scope;
        }else if(action == 'FIX_CANCELLED_ORDERS'){
            for(OrderItem oi : (List<OrderItem>) scope) {
                oi.UnitPrice = oi.Quote_Order_Credit_Detail__r.Unit_Price__c;
            }
            update scope;
        }
        
        else  if(action  == 'OPPORTUNITY_AMOUNT'){
            List<String> orderNumbers = new List<String>();
            for(Opportunity opp : (List<Opportunity>) scope) {
                orderNumbers.add(opp.Order_Number__c);
            }
            List<QuoteOrderCredit_Details__c> details = [SELECT Id, Order_Header__c
            FROM QuoteOrderCredit_Details__c
            WHERE Order_Header__r.Order_Number__c IN :orderNumbers];
            
            update details;
            
            
        }else if(action == 'Total Sales Update'){
            List<QuotesOrdersCredits_Header__c> qohs = new List<QuotesOrdersCredits_Header__c>();
            for(QuotesOrdersCredits_Header__c qoh : (List<QuotesOrdersCredits_Header__c>) scope) {
                if(qoh.New_Total_Order_Sales__c != qoh.Total_Order_Sales__c) {
                    qoh.New_Total_Order_Sales__c = qoh.Total_Order_Sales__c;
                    qohs.add(qoh);
                }
            }
            update qohs;
        }else if(action == 'update') {
            update scope;
        }else if(action == 'delete') {
            delete scope;
        }else if(action == 'test'){
            total += scope.size();
            
            System.debug('scope: ' + scope);
        }
        
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('total: ' + total);
    }
    
    
}