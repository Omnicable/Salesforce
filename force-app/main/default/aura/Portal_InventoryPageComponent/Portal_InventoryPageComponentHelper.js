({
    getData: function (cmp, searchTerm) {
        cmp.set('v.loading', true);
        var action = cmp.get('c.getAvailableInventory');
        let offset = cmp.get('v.offset');
        let limit = cmp.get('v.itemsPerPage');
        action.setParams({ searchTerm: searchTerm, offset: offset, limitCount: limit });
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let results = response.getReturnValue();
                cmp.set('v.inventoryCount', results.recordCount);
                results.records.forEach(res => {
                    res.count = 0;
                });

                cmp.set('v.data', results.records);

                let selectedIds = cmp.get('v.selectedIds')
                setTimeout(() => {
                    cmp.set('v.selectedIds', selectedIds);
                }, 100);

                let selectedRows = cmp.get('v.selectedRows');
                this.findCommonElement(cmp, results.records, selectedRows);

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
    onSearchInventory: function (cmp, searchTerm) {
        cmp.set('v.issearching', true);
        cmp.set('v.loading', true);
        let offset = cmp.get('v.offset');
        let limit = cmp.get('v.itemsPerPage');
        var action = cmp.get('c.getAvailableInventory');
        action.setParams({ searchTerm: searchTerm, offset: offset, limitCount: limit });
        action.setCallback(this, function (response) {
            cmp.set('v.loading', false);
            cmp.set('v.issearching', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let results = response.getReturnValue();
                //NOTE: empty array forces binding to update
                results.records.forEach(res => {
                    res.count = 0;
                });

                cmp.set('v.data', results.records);
                cmp.set('v.inventoryCount', results.recordCount);
                let selectedIds = cmp.get('v.selectedIds')
                setTimeout(() => {
                    cmp.set('v.selectedIds', selectedIds);
                }, 100);

                let selectedRows = cmp.get('v.selectedRows');
                this.findCommonElement(cmp, results.records, selectedRows);



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
    findCommonElement: function (cmp, allData, selected) {

        const myArrayFiltered = allData.filter((el) => {
            let index = 1
            return selected.some((f) => {
                if (f.Id == el.Id) {
                    el['count'] = index++;
                }
                // return f.Id === el.Id;
            });
        });

        cmp.set('v.selectedRows', selected);
        cmp.set('v.data', allData);

        let total = 0;
        selected.forEach(row => {
            total += row.Weight_Per_Foot__c;
        });

        cmp.set('v.totalWeight', total);

    },
    setColumns: function (cmp) {
        cmp.set('v.columns', [
            { label: 'Add', type: 'button-icon', initialWidth: 135, typeAttributes: { iconName: 'utility:add', title: 'Add', name: 'add_item', variant: 'border-filled' } },
            { label: 'Clear Item', type: 'button-icon', initialWidth: 135, typeAttributes: { iconName: 'utility:clear', title: 'clear', name: 'remove_items', variant: 'border-filled' } },
            { label: 'Selected', fieldName: 'count', type: 'text' },
            { label: 'Omni Item', fieldName: 'Name', type: 'text' },
            { label: 'Description', fieldName: 'Description__c', type: 'text' },
            { label: 'Customer Item Number', fieldName: 'Customer_PO__c', type: 'text' },
            { label: 'Lbs./Foot', fieldName: 'Weight_Per_Foot__c', type: 'number' },
            { label: 'Available', fieldName: 'Available__c', type: 'number' },
            { label: 'View Reels', type: 'button', initialWidth: 135, typeAttributes: { label: 'View Reels', name: 'view_details', title: 'Click to View Details' } },


        ]);
    },
    addItem: function (cmp, row) {
        let selectedRows = cmp.get('v.selectedRows');
        let allData = cmp.get('v.data');
        selectedRows.push(row);
        this.findCommonElement(cmp, allData, selectedRows);
        // cmp.set('v.selectedRows', selectedRows);
    },
    clearItems: function (cmp, row) {
        let selectedRows = cmp.get('v.selectedRows');
        let allData = cmp.get('v.data');
        let newSelection = selectedRows.filter((obj) => obj.Id !== row.Id);

        for (const obj of allData) {
            if (obj.Id === row.Id) {
                obj.count = 0;
            }
        }

        this.findCommonElement(cmp, allData, newSelection);
    },
    showRowDetails: function (cmp, row) {
        var modalBody;
        $A.createComponent("c:Portal_InventoryDetails", {
            inventoryDetails: row,
        },
            function (content, status) {
                if (status === "SUCCESS") {
                    modalBody = content;
                    cmp.find('overlayLib').showCustomModal({
                        inventoryDetails: row,
                        header: "Available Reels For: " + row.Name,
                        body: modalBody,
                        showCloseButton: true,
                        cssClass: "mymodal",
                        closeCallback: function () {


                        }
                    })
                }
            });
    },
    clear: function (cmp) {
        this.LightningConfirm.open({
            message: 'Are you sure you want to clear all selected inventory',
            theme: 'warning',
            label: 'Please Confirm',
        }).then(function (result) {
            if (result) {
                cmp.set('v.selectedRows', []);
                cmp.set('v.selectedIds', []);

                let allData = cmp.get('v.data');
                for (const obj of allData) {
                    obj.count = 0;
                }

                cmp.set('v.data', allData);
                localStorage.removeItem('pendingRelease');

            }
        });
    },
    addToRelease: function (cmp) {
        let releases = cmp.get('v.selectedRows');
        //const ids = releases.map(({ Id }) => Id);
        // const filtered = releases.filter(({ Id }, index) => !ids.includes(Id, index + 1));

        releases.forEach(element => {
            element.count = null;
        });


        this.LightningConfirm.open({
            message: 'Are you sure you want to create a request using the selected inventory items',
            theme: 'info',
            label: 'Please Confirm',
        }).then(function (result) {
            if (result) {
                localStorage.setItem('pendingRelease', JSON.stringify(releases));
                window.location = '../s/request-release';
            }
        });
    }
})