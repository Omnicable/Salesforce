({
    doInit: function (component, event, helper) {
        helper.doInit(component);
    },
    submitRFQ: function (cmp, event, helper) {
        let requestValid = helper.validateRelease(cmp)
        let itemsValid = helper.validateReleaseItems(cmp);

        if (requestValid.length == 0 && itemsValid.length == 0) {
            let releaseItems = cmp.get('v.releaseItems');
            let deliveryDate = cmp.find('deliveryDate').get('v.value');
            let deliveryAddressId = cmp.find('deliveryAddress').get('v.value');
            let deliveryAddress = helper.getAddressById(cmp, deliveryAddressId);
            let deliveryContact = cmp.find('deliveryContact').get('v.value');
            let jobReference = cmp.find('jobReference').get('v.value');
            let rmfPO = cmp.find('rmfPO').get('v.value');
            let specialInstructions = cmp.find('specialInstructions').get('v.value');
            let totalWeight = cmp.get('v.totalWeight');
            let request = { 'totalWeight': totalWeight, 'specialInstructions': specialInstructions, 'rmfPO': rmfPO, 'jobReference': jobReference, 'deliveryAddress': deliveryAddress, 'deliveryContact': deliveryContact, 'rawDeliveryDate': deliveryDate, 'deliveryDate': $A.localizationService.formatDate(deliveryDate), 'releaseItems': releaseItems }
            let attachments = cmp.get('v.attachments');
            let contentVersions = [];
            attachments.forEach(attachment => {
                contentVersions.push(attachment.contentVersionId);
            });

            helper.createRFQ(cmp, request, releaseItems, contentVersions);
        } else {

            helper.showToast(cmp, ['Required Information Missing']);
            // helper.showToast(cmp, requestValid.concat(itemsValid));
        }

    },
    clearReleaseItems: function (cmp, event, helper) {
        helper.clearReleaseItems(cmp);
    },
    addReleaseItem: function (component, event, helper) {
        let releaseItems = component.get('v.releaseItems');
        let newRelease = component.get('v.newRelease');
        let missingFields = [];

        if (newRelease.qty == '' || newRelease.qty == undefined) {
            missingFields.push('Qty');
        }
        if (newRelease.lengthValue == '' || newRelease.lengthValue == undefined) {
            missingFields.push('Length');
        }

        if (newRelease.cableNumber == '' || newRelease.cableNumber == undefined) {
            missingFields.push('Cable#');
        }

        if (missingFields.length == 0) {
            // let jobAreas = component.get('v.jobAreas');
            // let area = jobAreas.filter(area => area.Name == newRelease.area);
            // newRelease.areaManager = area[0].Area_Account_Manager__r.Name;
            newRelease.totalQty = parseInt(newRelease.qty) * parseInt(newRelease.lengthValue);
            releaseItems.push(JSON.parse(JSON.stringify(newRelease)));
            component.set('v.releaseItems', releaseItems);
            localStorage.setItem('currentReleases', JSON.stringify(releaseItems));
            helper.resetNewRelease(component, newRelease);
            helper.calculateTotalWeight(component);
        } else {

            helper.showToast(component, missingFields)

        }

    },
    handleUploadFinished: function (component, event, helper) {
        let attachments = component.get('v.attachments');
        var uploadedFiles = event.getParam("files");
        uploadedFiles.forEach(file => {
            attachments.push(file);
        });
        component.set('v.attachments', attachments);
    },
    removeReleaseItem: function (component, event, helper) {
        let index = event.getSource().get('v.name');
        let releaseItems = component.get('v.releaseItems');
        releaseItems.splice(index, 1);
        component.set('v.releaseItems', releaseItems);
        localStorage.setItem('currentReleases', JSON.stringify(releaseItems));
        helper.calculateTotalWeight(component);
    },
    removeFile: function (component, event, helper) {
        let index = event.getSource().get('v.name');
        let attachments = component.get('v.attachments');
        attachments.splice(index, 1);
        component.set('v.attachments', attachments);
    },
    setCableNumber: function (cmp, event, helper) {
        let value = event.getParam('value');
        let description = event.getParam('description');
        let newRelease = cmp.get('v.newRelease');
        newRelease.cableNumber = value;
        newRelease.description = description;
        cmp.set('v.newRelease', newRelease);
    },
    addressChange: function (cmp, event, helper) {
        let value = cmp.find('deliveryAddress').get('v.value');
        if (value == 'new') {
            helper.openPrompt(cmp);
        }

    },

    recalculateTotalWeight: function (cmp, event, helper) {
        helper.calculateTotalWeight(cmp);
    }
})