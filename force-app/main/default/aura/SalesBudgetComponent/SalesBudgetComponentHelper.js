({
  /**
   * description: query data for chart
   * @param {} component 
   * @param {string} range 
   */
  runQuery: function (component, range, grouping) {
    component.set('v.isLoading', true);
    component.set('v.noResults', false);
    var action = component.get("c.queryReportTotal");
    action.setParam('showDetails', false);
    action.setParam('range', range);
    action.setParam('grouping', grouping);

    action.setCallback(this, function (response) {
      var state = response.getState();
      component.set('v.isLoading', false);

      if (state == 'SUCCESS') {
        var data = response.getReturnValue();
        let results = JSON.parse(data);
        component.set('v.reportTitle', results.title);
        component.set('v.chartData', results);
        component.set('v.lastRunDate', results.lastRunDate);
        component.set('v.showGrouping', results.showGrouping);

        if (results.reports.length == 0 || results.reports[0].aggregatelineItems.length == 0) {
          component.set('v.noResults', true);
          component.find('barChart').getElement().style.height = '300px';
          d3.selectAll("#barChart > svg").remove();
        } else {
          component.find('barChart').getElement().style.height = '600px';
          this.showVerticalChart(component, this.prepData(results));
        }
      }
    });

    $A.enqueueAction(action);
  },

  prepData: function (results) {
    let report = results.reports[0];

    report.aggregatelineItems.forEach(lineItem => {
      lineItem.month = this.toMonthName(lineItem.month);
    });

    return results

  },

  /**
   * description: Convert month number to name
   * @param {int} monthNumber 
   * @returns {string} monthName
   */
  toMonthName: function (monthNumber) {
    const date = new Date();
    date.setMonth(monthNumber - 1);

    return date.toLocaleString('en-US', {
      month: 'long',
    });
  },

  /**
  * description: Create chart from data
  * @deprecated Use showVerticalChart instead
  * @param {*} component 
  * @param {*} results 
  */
  showVerticalChart: function (component, results) {
    let report = results.reports[0];
    let title = results.title;
    let grouping = report.grouping;
    let group;
    component.set('v.reportTitle', title);
    d3.selectAll("#barChart > svg").remove();
    d3.selectAll(".tooltip-cont > div").remove();


    // Define the div for the tooltip
    var div = d3.select(".tooltip-cont").append("div")
      .attr("class", "tooltip")
      .attr('style', 'position: absolute; opacity: 0;');

    let currencyFormat = Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    });

    let percentageFormat = Intl.NumberFormat('default', {
      style: 'percent',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });

    let columnsToSum = ['invoice', 'target'];

    let groupedData = d3.rollup(report.aggregatelineItems,
      v => Object.fromEntries(columnsToSum.map(col => [col, d3.sum(v, d => +d[col])])),
      d => d[grouping]);

    let sortedData;
    let dateMap = component.get('v.dateMap');

    if (grouping == 'region') {

      sortedData = Array.from(groupedData, ([groupField, obj]) => {
        obj[grouping] = groupField;

        obj.percentage = obj.invoice == 0 || obj.target == 0 ? 0 : obj.invoice / obj.target;
        return obj;
      }).sort((a, b) => d3.ascending(parseInt(a[grouping]), parseInt(b[grouping])));

    } else if (grouping == 'managerName') {

      sortedData = Array.from(groupedData, ([groupField, obj]) => {
        obj[grouping] = groupField;

        obj.percentage = obj.invoice == 0 || obj.target == 0 ? 0 : obj.invoice / obj.target;
        return obj;
      }).sort((a, b) => d3.ascending(a[grouping], b[grouping]));

    } else {

      sortedData = Array.from(groupedData, ([groupField, obj]) => {
        obj[grouping] = groupField;
        obj.percentage = obj.invoice == 0 || obj.target == 0 ? 0 : obj.invoice / obj.target;
        return obj;
      }).sort((a, b) => d3.ascending(parseInt(dateMap[a[grouping]]), parseInt(dateMap[b[grouping]])));

    }

    //TODO works until larget width use the lengh times x bandwidth calc
    const margin = 80;
    const width = Math.max(document.getElementById("barChart").offsetWidth - 2 * margin, 700);
    const xScale = d3.scaleBand()
      .range([0, width])
      .domain(sortedData.map((s) => s[grouping]))
      .padding(0.4)

    const length = sortedData.length;
    let barWidth = Math.max(xScale.bandwidth(), 75) + 30;
    let trueWidth;

    var actualWidth = width;
    var svgWidth = width;
    if (width < length * barWidth) {
      trueWidth = Math.max(length * barWidth, 600);
      actualWidth = trueWidth;
      svgWidth = actualWidth + 100;
    } else {
      trueWidth = 'auto';
      svgWidth = 'auto';
    }

    xScale.range([0, Math.max(actualWidth, width)]);

    const svg = d3.select('#barChart').append("svg").attr('width', svgWidth).attr('height', 600);
    const height = 600 - 2 * margin;
    const chart = svg.append('g')
      .attr('transform', `translate(${margin}, ${margin})`);

    const yScale = d3.scaleLinear()
      .range([height, 0])
      .domain([0, d3.max(sortedData.map((s) => Math.max(s.invoice, s.target)))]);

    const makeYLines = () => d3.axisLeft()
      .scale(yScale)

    chart.append('g')
      .attr('transform', `translate(0, ${height})`)
      .call(d3.axisBottom(xScale));

    chart.append('g').call(d3.axisLeft(yScale).ticks(width / 80, "s"));

    chart.append('g')
      .attr('class', 'grid')
      .call(makeYLines()
        .tickSize(-actualWidth, 0, 0)
        .tickFormat('')
      )

    const barGroups = chart.selectAll()
      .data(sortedData)
      .enter()
      .append('g')
      .on("mouseover", function (event, d) {
        const [x, y] = d3.pointer(event);

        div.transition()
          .duration(200)
          .style("opacity", .9);

        debugger;
        if (grouping == 'region') {
          group = 'Region Number: ';
        } else if (grouping == 'month') {
          group = 'Month: ';
        } else {
          group = 'Manager: ';
        }

        div.html(`
          <div>
            <div> ${group}  ${d[grouping]}</div>
            <div> Invoice: ${currencyFormat.format(d.invoice)} </div>
            <div> Target: ${currencyFormat.format(d.target)}</div>
            <div> Percentage: ${percentageFormat.format(d.percentage)}</div>
          </div>`)
          .style("left", (x) + "px")
          .style("top", (y - 45) + "px");
      })
      .on("mouseout", function (d) {
        div.transition()
          .duration(200)
          .style("opacity", 0)
          .style("left", (0) + "px").style("top", (0) + "px");
      }).on('mousemove', function (event) {
        const [x, y] = d3.pointer(event);
        div.style("left", (x) + "px").style("top", (y - 45) + "px");
      }
      );

    barGroups
      .append('rect')
      .attr('class', 'target')
      .attr('x', (g) => xScale(g[grouping]) + Math.max(xScale.bandwidth(), 75) / 2)
      .attr('y', (g) => yScale(g.target))
      .attr('height', (g) => height - yScale(g.target))
      .attr('width', Math.max(xScale.bandwidth(), 75) / 2)

    barGroups
      .append('rect')
      .attr('class', 'bar')
      .attr('x', (g) => xScale(g[grouping]))
      .attr('y', (g) => yScale(g.invoice))
      .attr('height', (g) => height - yScale(g.invoice))
      .attr('width', Math.max(xScale.bandwidth(), 75) / 2)

    barGroups
      .append('text')
      .attr('class', 'value')
      //.attr('fill', (a) => a.invoice >= a.target ? '#07834a' : '#c23934')
      .attr('x', (a) => xScale(a[grouping]) + Math.max(xScale.bandwidth(), 75) / 4)
      .attr('y', (a) => yScale(0) > yScale(a.invoice) ? Math.min(yScale(a.invoice) + 20, yScale(0) - 10) : Math.min(yScale(0) - 10, yScale(a.invoice) - 10))
      .attr('text-anchor', 'middle')
      .text((a) => d3.format(".2s")(a.invoice))

    barGroups.append('text')
      .attr('class', 'value')
      .attr('x', (a) => xScale(a[grouping]) + Math.max(xScale.bandwidth(), 75) * .75)
      .attr('y', (a) => yScale(0) > yScale(a.target) ? Math.min(yScale(a.target) + 20, yScale(0) - 10) : Math.min(yScale(0) - 10, yScale(a.target) - 10))
      .attr('text-anchor', 'middle')
      .text((a) => d3.format(".2s")(a.target))


    svg
      .append('text')
      .attr('class', 'label')
      .attr('x', -(height / 2) - margin)
      .attr('y', margin / 2.4)
      .attr('transform', 'rotate(-90)')
      .attr('text-anchor', 'middle')
      .text('Sum of Total Invoice $')

    svg.append('text')
      .attr('class', 'label')
      .attr('x', width / 2 + margin)
      .attr('y', height + margin * 1.7)
      .attr('text-anchor', 'middle')
      .text(grouping == 'region' ? 'Region Number' : grouping == 'month' ? 'Month' : 'Manager')

    svg.append('text')
      .attr('class', 'title')
      .attr('x', actualWidth / 2 + margin)
      .attr('y', 40)
      .attr('text-anchor', 'middle')
      .text(title)
  },

  /**
   * description: Create chart from data
   * @deprecated Use showVerticalChart instead
   * @param {*} component 
   * @param {*} report 
   */
  showChart: function (component, report) {
    let currencyFormat = Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    });

    let percentageFormat = Intl.NumberFormat('default', {
      style: 'percent',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });

    d3.selectAll("#barChart > svg").remove();
    let svgWidth = document.getElementById("barChart").offsetWidth - 100;

    report.reports.forEach(report => {
      let data = report.chartData;
      let margin = { top: 20, right: 20, bottom: 30, left: 80 };
      let svgHeight = 65 * Object.keys(data).length;
      let height = svgHeight - margin.top - margin.bottom, width = svgWidth - margin.left - margin.right;

      let sourceNames = [], sourceCount = [];

      let x = d3.scaleLinear().rangeRound([0, width]), y = d3.scaleBand().rangeRound([0, height]).padding(0.1);
      for (let key in data) {
        if (data.hasOwnProperty(key)) {
          sourceNames.push(key);
          sourceCount.push(parseInt(data[key]));
        }
      }
      x.domain([0, d3.max(sourceCount, function (d) { return d; })]);
      y.domain(sourceNames);

      let svg = d3.select("#barChart").append("svg").attr('class', 'chart-sect');
      svg.append("text")
        .attr("x", svgWidth / 2)
        .attr("y", margin.top)
        .attr("text-anchor", "left")
        .attr("class", "slds-text-title_bold")
        .text(report.title).append("tspan")
        .style("fill", report.percentage >= 1 ? 'green' : 'red')
        .text('  (' + percentageFormat.format(report.percentage) + ')')
      svg.attr('height', svgHeight)
        .attr('width', '100%');

      svg = svg.append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      svg.append("g")
        .attr("transform", "translate(0, " + height + ")")
        .call(d3.axisBottom(x).ticks(width / 100, "s"));

      svg.append("g")
        .call(d3.axisLeft(y))
        ;

      // Create rectangles
      let bars = svg.selectAll('.bar')
        .data(sourceNames)
        .enter()
        .append("g")
        .attr("class", "bar-cont");

      bars.append('rect')
        .attr('class', 'bar')
        .attr("x", function (d) { return 0; })
        .attr("y", function (d) { return y(d); })
        .attr("width", function (d) { return x(data[d]) })
        .attr("height", function (d) { return y.bandwidth(); })

      // bars.append("path")
      //     .attr('class', 'target')
      //     .attr("d", function (d) {
      //         var rv = "M" + x(data['Target']) + "," + y(d);
      //         rv += "V" + (y(d) + y.bandwidth()) + 'Z';
      //         return rv;
      //     });

      bars.append("text")
        .text(function (d) {
          return currencyFormat.format(data[d]);
        })
        .attr("x", function (d) {
          return x(data[d]) + 15;
        })
        .attr("y", function (d) {
          console.log(d);
          return y(d) + y.bandwidth() * (0.5 + 0.1); // here 0.1 is the padding scale
        })
        .attr("font-family", "sans-serif")
        .attr("font-size", "14px")
        .attr("fill", "black")
        .attr("text-anchor", "left");
    });
  }

})