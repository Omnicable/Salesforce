({
    getReleases: function (cmp, searchTerm) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.getReleases');
        action.setParams({ type: 'Release', scope: 'myQuotes', offset: 0, searchTerm: searchTerm });
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            cmp.set('v.issearching', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let data = response.getReturnValue();
                cmp.set('v.myRecords', data.myRecords.records);
                cmp.set('v.myCount', data.myRecords.recordCount);
                cmp.set('v.otherRecords', data.otherRecords.records);
                cmp.set('v.otherCount', data.otherRecords.recordCount);
            } else {

            }
        });

        $A.enqueueAction(action);

    },
    getOrders: function (cmp, searchTerm) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.getOrders');
        action.setParams({ searchTerm: searchTerm, offset: 0 })
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            cmp.set('v.issearching', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                debugger;
                let data = response.getReturnValue();
                data.masterOrders.records.forEach(header => {
                    header.Order_Details__r.forEach(detail => {
                        if (1 - (detail.Qty_Shipped__c / detail.Qty_Ordered__c) >= .3) {
                            detail['trend'] = 'up';
                        } else if (1 - (detail.Qty_Shipped__c / detail.Qty_Ordered__c) < .3 && 1 - (detail.Qty_Shipped__c / detail.Qty_Ordered__c) != 0) {
                            detail['trend'] = 'neutral';
                        } else {
                            detail['trend'] = 'down';
                        }
                    });
                });
                cmp.set('v.myRecords', data.masterOrders.records);
                cmp.set('v.myCount', data.masterOrders.recordCount);
            } else {

            }
        });

        $A.enqueueAction(action);
    },
    getMyReleasesLocal: function (cmp, offset, page, tabName) {
        cmp.set('v.loading', true);
        let searchTerm = cmp.get('v.searchTerm');

        var action;
        if (searchTerm == '' || searchTerm == null) {
            var action = cmp.get('c.getMyReleases');
            action.setParams({ offset: offset });
        } else {
            var action = cmp.get('c.searchMyReleases');
            action.setParams({ searchTerm: searchTerm, offset: offset });
        }

        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let data = response.getReturnValue();
                if (tabName == 'my') {
                    cmp.set('v.myRecords', data.records);
                    cmp.set('v.myCount', data.recordCount);
                } else {
                    cmp.set('v.otherRecords', data.records);
                    cmp.set('v.otherCount', data.recordCount);
                }
            } else {

            }
        });

        $A.enqueueAction(action);
    },
    getOtherReleasesLocal: function (cmp, offset, page, tabName) {
        cmp.set('v.loading', true);
        let searchTerm = cmp.get('v.searchTerm');

        var action;
        if (searchTerm == '' || searchTerm == null) {
            var action = cmp.get('c.getOtherReleases');
            action.setParams({ offset: offset });
        } else {
            var action = cmp.get('c.searchOtherReleases');
            action.setParams({ searchTerm: searchTerm, offset: offset });
        }

        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let data = response.getReturnValue();
                if (tabName == 'my') {
                    cmp.set('v.myRecords', data.records);
                    cmp.set('v.myCount', data.recordCount);
                } else {
                    cmp.set('v.otherRecords', data.records);
                    cmp.set('v.otherCount', data.recordCount);
                }
            } else {

            }
        });

        $A.enqueueAction(action);
    },
    onSearchQOC: function (cmp, searchTerm) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.getAvailableInventory');
        action.setParams({ searchTerm: searchTerm, offset: 0 });
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let results = response.getReturnValue();
                //NOTE: empty array forces binding to update
                cmp.set('v.data', results);
                let selectedIds = cmp.get('v.selectedIds')
                setTimeout(() => {
                    cmp.set('v.selectedIds', selectedIds);
                }, 100);

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
})