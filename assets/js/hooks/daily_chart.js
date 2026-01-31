import { select } from 'd3-selection'
import { scaleBand, scaleLinear } from 'd3-scale'
import { axisBottom, axisLeft } from 'd3-axis'
import { max } from 'd3-array'

export default {
  mounted() {
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  renderChart() {
    const data = JSON.parse(this.el.dataset.chart)

    // Clear previous chart
    select(this.el).selectAll('*').remove()

    if (!data || data.length === 0) {
      return
    }

    // Dimensions and margins
    const margin = { top: 20, right: 20, bottom: 40, left: 50 }
    const width = this.el.clientWidth - margin.left - margin.right
    const height = 120 - margin.top - margin.bottom

    // Create SVG
    const svg = select(this.el)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)

    // Create tooltip div (attached to body for proper positioning)
    const tooltip = select('body').selectAll('.chart-tooltip').data([null])
      .join('div')
      .attr('class', 'chart-tooltip')
      .style('position', 'absolute')
      .style('visibility', 'hidden')
      .style('background-color', 'rgba(0, 0, 0, 0.8)')
      .style('color', 'white')
      .style('padding', '8px 12px')
      .style('border-radius', '4px')
      .style('font-size', '12px')
      .style('pointer-events', 'none')
      .style('z-index', '1000')

    // Scales
    const x0 = scaleBand()
      .domain(data.map(d => d.date))
      .range([0, width])
      .paddingInner(0.1)
      .paddingOuter(0.1)

    const x1 = scaleBand()
      .domain(['page_views', 'unique_visitors'])
      .range([0, x0.bandwidth()])
      .padding(0.05)

    const y = scaleLinear()
      .domain([0, max(data, d => Math.max(d.page_views, d.unique_visitors))])
      .nice()
      .range([height, 0])

    // Colors (theme colors)
    const colors = {
      page_views: '#661419',      // maroon
      unique_visitors: '#bc6428'  // autumn
    }

    // Labels for tooltip
    const labels = {
      page_views: 'Page Views',
      unique_visitors: 'Unique Visitors'
    }

    // Draw bars
    const barGroups = svg.selectAll('.bar-group')
      .data(data)
      .enter()
      .append('g')
      .attr('class', 'bar-group')
      .attr('transform', d => `translate(${x0(d.date)},0)`)

    // Helper function to format numbers with commas
    const formatNumber = (num) => num.toLocaleString()

    // Page views bars
    barGroups.append('rect')
      .attr('x', x1('page_views'))
      .attr('y', d => y(d.page_views))
      .attr('width', x1.bandwidth())
      .attr('height', d => height - y(d.page_views))
      .attr('fill', colors.page_views)
      .style('cursor', 'pointer')
      .on('mouseover', function(event, d) {
        select(this).attr('opacity', 0.8)
        tooltip
          .style('visibility', 'visible')
          .html(`<strong>${d.date}</strong><br/>${labels.page_views}: ${formatNumber(d.page_views)}`)
      })
      .on('mousemove', function(event) {
        tooltip
          .style('top', (event.pageY - 10) + 'px')
          .style('left', (event.pageX + 10) + 'px')
      })
      .on('mouseout', function() {
        select(this).attr('opacity', 1)
        tooltip.style('visibility', 'hidden')
      })

    // Unique visitors bars
    barGroups.append('rect')
      .attr('x', x1('unique_visitors'))
      .attr('y', d => y(d.unique_visitors))
      .attr('width', x1.bandwidth())
      .attr('height', d => height - y(d.unique_visitors))
      .attr('fill', colors.unique_visitors)
      .style('cursor', 'pointer')
      .on('mouseover', function(event, d) {
        select(this).attr('opacity', 0.8)
        tooltip
          .style('visibility', 'visible')
          .html(`<strong>${d.date}</strong><br/>${labels.unique_visitors}: ${formatNumber(d.unique_visitors)}`)
      })
      .on('mousemove', function(event) {
        tooltip
          .style('top', (event.pageY - 10) + 'px')
          .style('left', (event.pageX + 10) + 'px')
      })
      .on('mouseout', function() {
        select(this).attr('opacity', 1)
        tooltip.style('visibility', 'hidden')
      })

    // Determine label filtering based on data length
    // Show every label for 7 days, every 3rd for 30 days, every 7th for 90 days
    const tickValues = data.length <= 7 ? data.map(d => d.date) :
                       data.length <= 30 ? data.filter((_, i) => i % 3 === 0).map(d => d.date) :
                       data.filter((_, i) => i % 7 === 0).map(d => d.date)

    // X axis
    svg.append('g')
      .attr('transform', `translate(0,${height})`)
      .call(axisBottom(x0).tickValues(tickValues))
      .selectAll('text')
      .style('text-anchor', 'middle')

    // Y axis
    svg.append('g')
      .call(axisLeft(y).ticks(5))

    // X axis label
    svg.append('text')
      .attr('x', width / 2)
      .attr('y', height + margin.bottom - 5)
      .attr('text-anchor', 'middle')
      .style('font-size', '12px')
      .style('fill', '#6b7280')
      .text('Date')

    // Y axis label
    svg.append('text')
      .attr('transform', 'rotate(-90)')
      .attr('x', -height / 2)
      .attr('y', -margin.left + 15)
      .attr('text-anchor', 'middle')
      .style('font-size', '12px')
      .style('fill', '#6b7280')
      .text('Count')
  }
}
