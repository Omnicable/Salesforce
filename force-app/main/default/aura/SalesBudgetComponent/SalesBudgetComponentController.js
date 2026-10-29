({
    /**
     * description: run report and add event listener to resize chart when window size changes
     * @param {*} component 
     * @param {*} event 
     * @param {*} helper 
     */
    runReport: function (component, event, helper) {
        let range = component.find('view').get('v.value');
        let grouping = component.get('v.grouping');
        helper.runQuery(component, range != null ? range : 'THIS_MONTH', grouping);

        window.addEventListener('resize', function () {

            let resizeTimer = component.get('v.resizeTimer');
            clearTimeout(resizeTimer);

            let data = component.get("v.chartData");
            let noResults = component.get('v.noResults');

            if (!noResults && data) {
                resizeTimer = setTimeout(() => {
                    helper.showVerticalChart(component, data);
                }, 700);

                component.set('v.resizeTimer', resizeTimer);
            }

        }, true);
    },

    /**
     * description: view full report with all line items
     * @param {*} component 
     * @param {*} event 
     * @param {*} helper 
     */
    viewReport: function (component, event, helper) {
        let title = component.get('v.reportTitle');
        let range = component.find('view').get('v.value') != null ? component.find('view').get('v.value') : 'THIS_MONTH';
        var url = '/apex/SalesBudgetReport?title=' + title + '&range=' + range;
        window.open(url, '_target');
    },

    /**
     * description: Run report when date range changes
     * @param {*} component 
     * @param {*} evt 
     * @param {*} helper 
     */
    onChange: function (component, evt, helper) {
        let value = component.find('view').get('v.value');
        let grouping = component.get('v.grouping');
        helper.runQuery(component, value, grouping);
    },

    /**
     * description: Run report when date range changes
     * @param {*} component 
     * @param {*} evt 
     * @param {*} helper 
     */
    onGroupingChange: function (component, evt, helper) {
        debugger;
        let value = component.find('view').get('v.value');
        let grouping = component.get('v.grouping');
        helper.runQuery(component, value, grouping);
    }
})