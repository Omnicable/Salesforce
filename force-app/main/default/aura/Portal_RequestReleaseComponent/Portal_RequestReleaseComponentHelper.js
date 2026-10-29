({
    doInit: function (component) {
        component.set('v.loading', true);
        var action = component.get('c.getRequestReleaseData');
        action.setParams({ type: 'Release', scope: 'myQuotes', offset: 0, searchTerm: '' });
        action.setCallback(this, function (response) {
            component.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let data = response.getReturnValue();
                component.set('v.filteredAltParts', data.defaultPartList);
                component.set('v.deliveryAddresses', data.deliveryAddresses);
                // component.set('v.rmfPOValues', data.rmfPOValues);
                component.set('v.jobAreas', data.jobAreas);
                component.set('v.contact', data.contact);

                let deliveryContacts = [];
                deliveryContacts.push(data.contact.Email);
                deliveryContacts.push(data.contact.Phone);
                component.set('v.deliveryContacts', deliveryContacts);
            }

            this.checkLocalStorage(component);
        });

        $A.enqueueAction(action);
    },
    checkLocalStorage: function (cmp) {
        let currentReleases = localStorage.getItem('currentReleases');
        if (currentReleases == null) {
            currentReleases = [];
        } else {
            currentReleases = JSON.parse(currentReleases);
        }
        let releases = localStorage.getItem('pendingRelease');
        if (releases != null) {
            let releaseItems = [];
            let pendingReleases = JSON.parse(releases);

            pendingReleases.forEach(item => {
                currentReleases.push({ qty: item.count, lengthValue: '', itemNumber: item.Name, cableNumber: item.Customer_PO__c, description: item.Description__c, info: '', area: '', paralleling: false, pullingHeads: 'none', weight: item.Weight_Per_Foot__c });
            });
        }

        cmp.set('v.releaseItems', currentReleases);
        localStorage.setItem('currentReleases', JSON.stringify(currentReleases));
        this.calculateTotalWeight(cmp);
        localStorage.removeItem('pendingRelease');
    },
    createRFQ: function (cmp, request, releaseItems, attachments) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.sendRFQ');
        action.setParams({ typeStr: 'RFQ', newRequest: request, releaseItems: releaseItems, attachments: attachments });
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let data = response.getReturnValue();
                this.showSuccessToast(cmp, 'Submission Successful', data.message);
                this.resetNewRelease(cmp, request);
                this.resetDeliveryForm(cmp);
                localStorage.clear();
                cmp.set('v.totalWeight', 0);
            } else if (state == 'INCOMPLETE') {
                this.showToast(cmp, 'Server could not be reached. Check your internet connection');
            } else {
                console.log(response.getError()[0].message);
            }
        });

        $A.enqueueAction(action);
    },
    validateRelease: function (cmp) {
        let deliveryDate = cmp.find('deliveryDate');
        let deliveryAddress = cmp.find('deliveryAddress');
        let deliveryContact = cmp.find('deliveryContact');
        let rmfPO = cmp.find('rmfPO');
        let errors = [];

        if (deliveryDate.get('v.value') == '') {
            errors.push('Delivery Requirement');
            deliveryDate.reportValidity();
        }
        if (deliveryContact.get('v.value') == '') {
            errors.push('Preferred Contact');
            deliveryContact.focus();
            deliveryContact.checkValidity();
        }
        if (deliveryAddress.get('v.value') == '') {
            errors.push('Delivery Address');
            deliveryAddress.focus();
            deliveryAddress.checkValidity();
        }
        if (rmfPO.get('v.value') == '') {
            errors.push('Customer PO #');
            rmfPO.focus();
            rmfPO.checkValidity();
        }

        return errors;
    },
    validateReleaseItems: function (cmp) {

        let errors = [];
        let releases = cmp.get('v.releaseItems');
        let index = 1;
        releases.forEach(item => {
            item.totalQty = item.qty * item.lengthValue;
            item.error = false;
            if (item.qty == '' || item.lengthValue == '') {
                item.error = true;
                errors.push('Line Item: ' + index++ + ' missing required information')
            }

        });

        cmp.set('v.releaseItems', releases);
        localStorage.setItem('currentReleases', JSON.stringify(releases));
        return errors;
    },
    getAddressById: function (cmp, id) {
        let addressess = cmp.get('v.deliveryAddresses');
        let selectedAddress = addressess.find(x => x.Id === id);
        return selectedAddress;
    },
    resetDeliveryForm: function (cmp) {
        cmp.set('v.releaseItems', []);
        cmp.set('v.attachments', []);
        cmp.find('deliveryDate').set('v.value', '');
        cmp.find('deliveryAddress').set('v.value', '');
        cmp.find('deliveryContact').set('v.value', '');
        cmp.find('jobReference').set('v.value', '');
        cmp.find('rmfPO').set('v.value', '');
        cmp.find('specialInstructions').set('v.value', '');
    },
    resetNewRelease: function (cmp, newRelease) {
        let jobAreas = cmp.get('v.jobAreas');

        for (const key in newRelease) {
            if (key == 'pullingHeads') {
                newRelease[key] = 'none';
            } else if (key == 'paralleling') {
                newRelease[key] = false;
            } else if (key == 'area') {
                newRelease[key] = '';
                //newRelease[key] = jobAreas[0].Name;
            } else {
                newRelease[key] = '';
            }
        }

        cmp.set('v.newRelease', newRelease);
        let childComp = cmp.find('searchTypeAhead');
        childComp.clearSearchValue('');
    },
    calculateTotalWeight: function (cmp) {
        let totalWeight = 0;
        let releases = cmp.get('v.releaseItems');
        releases.forEach(release => {
            if (release.weight != null) {
                totalWeight += (release.qty * release.lengthValue) * release.weight;
            }

        });
        localStorage.setItem('currentReleases', JSON.stringify(releases));
        cmp.set('v.totalWeight', totalWeight);
    },
    clearReleaseItems: function (cmp) {
        this.LightningConfirm.open({
            message: 'Are you sure you\'d like to remove all request line items',
            theme: 'warning',
            label: 'Please Confirm',
        }).then(function (result) {
            if (result) {
                cmp.set('v.releaseItems', []);
                localStorage.clear();
                cmp.set('v.totalWeight', 0);

            }
        });
    },
    showToast: function (component, errors) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": "The following fields are required and missing",
            "message": errors.toString(),
            "mode": 'dismissible',
            "duration": 3000,
            "type": "error"
        });
        toastEvent.fire();
    },
    showSuccessToast: function (cmp, title, message) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "mode": 'dismissible',
            "duration": 3000,
            "type": "success"
        });
        toastEvent.fire();
    },
    openPrompt: function (cmp) {

        var modalBody;
        $A.createComponent("c:Portal_CreateAddress", {
            newAddress: cmp.getReference('v.newAddress')
        },
            function (content, status) {
                if (status === "SUCCESS") {
                    modalBody = content;
                    cmp.find('overlayLib').showCustomModal({
                        header: 'Save New Address',
                        body: modalBody,
                        showCloseButton: true,
                        cssClass: "slds-modal_medium",
                        closeCallback: function () {
                            let newAddress = cmp.get('v.newAddress');
                            if (newAddress != null && newAddress.Id != null) {
                                let addresses = cmp.get('v.deliveryAddresses');
                                addresses.push(newAddress);
                                cmp.set('v.deliveryAddresses', addresses);
                                cmp.set('v.deliveryAddress', newAddress.Id);
                            } else {
                                cmp.set('v.deliveryAddress', '');
                            }
                        }
                    })
                }
            });



        // var _this = this;
        // this.LightningPrompt.open({
        //     message: 'Add New Delivery Address',
        //     variant: 'headerless',
        //     label: 'New Delivery Address',
        //     defaultValue: '',
        // }).then(function (result) {

        //     if (result != null && result != '') {
        //         let addresses = cmp.get('v.deliveryAddresses');
        //         addresses.push({ Name: result });
        //         cmp.set('v.deliveryAddresses', addresses);
        //         cmp.set('v.deliveryAddress', result);

        //         setTimeout($A.getCallback(function () {
        //             _this.addDeliveryAddress(cmp, result);
        //         }), 50);


        //     } else {
        //         cmp.set('v.deliveryAddress', '');
        //     }
        // });
    },
    // addDeliveryAddress: function (cmp, newAddress) {
    //     cmp.set('v.loading', true);
    //     let contact = cmp.get('v.contact');
    //     var action = cmp.get('c.createDeliveryAddress');
    //     action.setParams({ newAddress: newAddress, accountId: contact.AccountId });
    //     action.setCallback(this, function (response) {
    //         cmp.set('v.loading', false);
    //         var state = response.getState();
    //         if (state == 'SUCCESS') {
    //             let data = response.getReturnValue();
    //             if (data) {
    //                 this.showSuccessToast(cmp, 'Success ', newAddress + ' successfully added.');
    //             }
    //         } else {
    //             console.log(response.getError()[0].message);
    //         }
    //     });

    //     $A.enqueueAction(action);
    // }
})