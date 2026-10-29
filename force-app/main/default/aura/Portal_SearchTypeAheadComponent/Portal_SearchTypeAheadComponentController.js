({
    doInit: function (cmp, event, helper) {
        helper.getDefaultParts(cmp);
    },
    clearSearchValue: function (cmp, event, helper) {
        cmp.set('v.searchValue', '');
    },
    searchHandler: function (cmp, event, helper) {
        console.log('searchHandler');

        const searchString = cmp.find('enter-search').get('v.value');
        if (searchString.length >= 2) {

            cmp.set('v.isSearching', true);
            cmp.set('v.openDropDown', true);

            if (cmp.get("v.inputTimer")) {
                clearTimeout(cmp.get("v.inputTimer"));
            }

            var inputTimer = setTimeout($A.getCallback(function () {
                helper.onSearchChange(cmp, searchString);
            }), 800);
            cmp.set("v.inputTimer", inputTimer);
        } else if (searchString.length == 0) {

            if (cmp.get("v.inputTimer")) {
                clearTimeout(cmp.get("v.inputTimer"));
            }

            cmp.set('v.isSearching', false);
            let defaults = cmp.get('v.defaultParts');
            cmp.set('v.results', defaults);
            cmp.set("v.openDropDown", true);

        } else {
            cmp.set('v.isSearching', false);
            cmp.set("v.results", []);
            cmp.set("v.openDropDown", false);
        }
    },
    setCable: function (cmp, event, helper) {
        let value = event.currentTarget.dataset.name
        let description = event.currentTarget.dataset.description;
        let itemNumber = event.currentTarget.dataset.number;
        cmp.set('v.searchValue', value);
        cmp.set('v.openDropDown', false);

        let newR = cmp.get('v.newRelease');
        newR.cableNumber = value;
        newR.description = description;
        newR.itemNumber = itemNumber;
        cmp.set('v.newRelease', newR);
    },
    possibleClear: function (cmp, event, helper) {
        console.log('possible clear');
        const searchString = cmp.find('enter-search').get('v.value');
        if (searchString == '') {
            cmp.set('v.searchValue', '');
            cmp.set('v.openDropDown', true);

            let newR = cmp.get('v.newRelease');
            newR.cableNumber = '';
            newR.description = '';
            cmp.set('v.newRelease', newR);

            let defaults = cmp.get('v.defaultParts');
            cmp.set('v.results', defaults);
        }
    },
    onFocus: function (cmp, event, helper) {
        let results = cmp.get("v.results");
        if (results.length > 0) {
            setTimeout($A.getCallback(function () {
                cmp.set('v.openDropDown', true);
            }), 300);
        }
    },
    onBlur: function (cmp, event, helper) {
        setTimeout($A.getCallback(function () {
            cmp.set('v.openDropDown', false);
        }), 300);
    }

})