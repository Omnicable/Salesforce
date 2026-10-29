({
    onload: function (cmp, event, helper) {
        cmp.set('v.newAddress', null);
        helper.getContactId(cmp);
    },
    onsubmit: function (cmp, event, helpeer) {
        var userId = $A.get("$SObjectType.CurrentUser.Id");
        let contactId = cmp.get('v.contactId');
        var fields = event.getParam('fields');
        fields.Contact__c = contactId;
        cmp.set('v.isloading', true);
        // cmp.find('newAddressForm').submit(fields);
    },
    handleSuccess: function (cmp, event, helper) {
        cmp.set('v.isloading', false);
        var updatedRecord = JSON.parse(JSON.stringify(event.getParams()));
        helper.handleSuccess(cmp, updatedRecord);
    },
    handleCancel: function (cmp, event, helper) {
        cmp.find("overlayLib").notifyClose();
    },
})