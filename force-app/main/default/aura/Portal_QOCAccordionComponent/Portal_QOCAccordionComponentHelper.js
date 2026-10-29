({
    receiveRequest: function (cmp, id, value) {
        var action = cmp.get('c.toggleReleaseReceive');
        action.setParams({ Id: id, value: value });
        action.setCallback(this, function (response) {

            var state = response.getState();
            if (state == 'SUCCESS') {
                let results = response.getReturnValue()

            } else {
                let errorMessage = response.getError()[0].message;
                cmp.find('notifLib').showNotice({
                    "variant": "error",
                    "header": "Something has gone wrong!",
                    "message": errorMessage,
                    closeCallback: function () { }
                });
            }
        });

        $A.enqueueAction(action);
    },

    buildQuote: function (array, alternativePartNumbers) {

        if (typeof array == 'undefined' || array == null) {
            array = [];
        } else if (!Array.isArray(array)) {
            array = [array];
        }

        for (var i = 0; i < array.length; i++) {

            if (typeof array[i].attachments == 'undefined' || array[i].attachments == null) {
                array[i].attachments = [];
            } else if (!Array.isArray(array[i].attachments)) {
                array[i].attachments = [array[i].attachments];
            }

            if (typeof array[i].details == 'undefined' || array[i].details == null) {
                array[i].details = [];
            } else if (!Array.isArray(array[i].details)) {
                array[i].details = [array[i].details];
            }

            for (var j = 0; j < array[i].details.length; j++) {
                this.buildPutups(array[i].details[j]);

                /** TODO: get alternative part numbers */
                if (alternativePartNumbers.length > 0) {
                    array[i].details[j].cableNumber = '';
                    if (array[i].details[j].Line_Item__c && typeof alternativePartNumbers != 'undefined') {
                        const detail = array[i].details[j];

                        for (let index = 0; index < alternativePartNumbers.length; index++) {
                            const part = alternativePartNumbers[index];

                            if (typeof part.Part_Numbers__r != 'undefined' && part.Part_Numbers__r.Name == detail.Line_Item__c) {
                                array[i].details[j].cableNumber = part.Name;
                                if (part.Cable_Code__c) {
                                    array[i].details[j].Cable_Code__c = part.Cable_Code__c;
                                }
                            }

                        }
                    }
                }


                if (array[i].details[j].Expected_Date__c != 'undefined' && array[i].details[j].Expected_Date__c != null) {
                    var expectedDate = new Date(array[i].details[j].Expected_Date__c);
                    array[i].details[j].Expected_Date__c = (expectedDate.getUTCMonth() + Number(1)) + '/' + (expectedDate.getUTCDate()) + '/' + expectedDate.getFullYear();
                }

                if (array[i].details[j].Line_Status__c == 'Order Received') {
                    array[i].details[j].Line_Status__c = 'Open';
                }

                if (array[i].details[j].Line_Status__c == 'Shipping') {
                    array[i].details[j].Line_Status__c = 'In Process';
                }

            }

            var date = new Date(array[i].header.Date__c);
            var day = date.getDate();
            var utcdate = date.getUTCDate();
            var month = date.getUTCMonth();
            var year = date.getFullYear();
            array[i].header.Date__c = (date.getUTCMonth() + Number(1)) + '/' + (date.getUTCDate()) + '/' + date.getFullYear();

            var expDate = new Date(array[i].header.Date__c);
            var numberOfDaysToAdd = 3;
            expDate.setDate(expDate.getUTCDate() + numberOfDaysToAdd);

            array[i].header['ExpiredDate'] = (expDate.getUTCMonth() + Number(1)) + '/' + expDate.getUTCDate() + '/' + date.getFullYear();

            if (array[i].header.Status__c == 'Followed Up') {
                array[i].header.Status__c = 'Open'
            }

            if (array[i].header.Status__c == 'Shipping' || array[i].header.Status__c == 'Printed') {
                array[i].header.Status__c = 'In Process'
            }


            if (array[i].header.Status__c == 'Entered') {
                array[i].header.Status__c = 'Order Received'
            }

        }

        return array;
    },
    buildPutups: function (detail) {
        if (typeof detail != 'undefined') {
            detail['putups'] = [];
            if (typeof detail['Put_up_1__c'] != 'undefined' && detail['Put_up_1__c'] != null) {
                detail['putups'].push(detail['Put_up_1__c']);
            }
            if (typeof detail['Put_up_2__c'] != 'undefined' && detail['Put_up_2__c'] != null) {
                detail['putups'].push(detail['Put_up_2__c']);
            }
            if (typeof detail['Put_up_3__c'] != 'undefined' && detail['Put_up_3__c'] != null) {
                detail['putups'].push(detail['Put_up_3__c']);
            }
            if (typeof detail['Put_up_4__c'] != 'undefined' && detail['Put_up_4__c'] != null) {
                detail['putups'].push(detail['Put_up_4__c']);
            }
            if (typeof detail['Put_up_5__c'] != 'undefined' && detail['Put_up_5__c'] != null) {
                detail['putups'].push(detail['Put_up_5__c']);
            }
            if (typeof detail['Put_up_6__c'] != 'undefined' && detail['Put_up_6__c'] != null) {
                detail['putups'].push(detail['Put_up_6__c']);
            }
            if (typeof detail['Put_up_7__c'] != 'undefined' && detail['Put_up_7__c'] != null) {
                detail['putups'].push(detail['Put_up_7__c']);
            }

            //console.log(detail['putups']);
        }

    }
})