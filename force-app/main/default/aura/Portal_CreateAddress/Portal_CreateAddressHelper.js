({
    getContactId: function (cmp) {
        var action = cmp.get('c.getContact');
        action.setCallback(this, function (response) {
            cmp.set('v.isloading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let contact = response.getReturnValue();
                cmp.set('v.contactId', contact.Id);
            } else {
                console.log(response.getError()[0].message);
            }
        });

        $A.enqueueAction(action);
    },
    buildRecord: function (record) {
        let recordObj = record.response.fields;
        for (const key in recordObj) {
            recordObj[key] = recordObj[key].value;
        }
        recordObj.Id = record.response.id;
        if (recordObj.Display_Name__c == null) {
            recordObj.Display_Name__c = recordObj.Street_Address__c + ', ' + recordObj.City__c, + ', ' + recordObj.State__c, + ', ' + recordObj.Zip_Code__c;
        }
        return recordObj;
    },
    handleSuccess: function (cmp, record) {
        let newAddress = this.buildRecord(record);
        cmp.set('v.newAddress', newAddress);
        cmp.find("overlayLib").notifyClose();
        this.showToast('success', 'Saved', 'New delivery address is now available to use.')
    },
    handleCancel: function (component, event, helper) {
        //closes the modal or popover from the component
        component.find("overlayLib").notifyClose();
    },
    showToast: function (success, title, message) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "mode": 'dismissible',
            "duration": 3000,
            "type": success
        });
        toastEvent.fire();
    },

})