({
    getDefaultParts: function (cmp) {

        var action = cmp.get('c.getDefaultFilteredParts');
        action.setParams({ count: 20 });
        action.setCallback(this, function (response) {
            cmp.set('v.isSearching', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                let results = response.getReturnValue();
                cmp.set('v.results', results);
                cmp.set('v.defaultParts', results);

            } else {
                cmp.set('v.results', [{ Id: '', Name: 'No Results Found' }]);
            }
        });

        $A.enqueueAction(action);
    },
    onSearchChange: function (cmp, searchString) {
        //let object = cmp.get('v.object');
        //let field = cmp.get('v.field');
        //let limit = cmp.get('v.limit');

        var action = cmp.get('c.searchAlternateParts');
        action.setParams({ searchTerm: searchString });
        action.setCallback(this, function (response) {
            cmp.set('v.isSearching', false);
            var state = response.getState();
            if (state == 'SUCCESS') {
                debugger;
                let results = response.getReturnValue();
                cmp.set('v.results', results);

            } else {
                cmp.set('v.results', [{ Id: '', Name: 'No Results Found' }]);
            }
        });

        $A.enqueueAction(action);
    }
})