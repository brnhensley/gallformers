import { describe, test, expect } from 'vitest'
import { mountHook } from '../test/hook_test_helper.js'
import DailyChart from './daily_chart.js'

const SAMPLE_DATA = [
  { date: '2026-03-01', page_views: 150, unique_visitors: 80 },
  { date: '2026-03-02', page_views: 200, unique_visitors: 120 },
  { date: '2026-03-03', page_views: 175, unique_visitors: 95 }
]

function chartHTML(data = SAMPLE_DATA) {
  return `<div data-chart='${JSON.stringify(data)}' style="width: 400px;"></div>`
}

describe('DailyChart', () => {
  test('renders SVG with data', () => {
    const hook = mountHook(DailyChart, chartHTML())
    hook.mounted()

    const svg = hook.el.querySelector('svg')
    expect(svg).toBeTruthy()
  })

  test('creates bar groups for each data point', () => {
    const hook = mountHook(DailyChart, chartHTML())
    hook.mounted()

    const barGroups = hook.el.querySelectorAll('.bar-group')
    expect(barGroups).toHaveLength(3)
  })

  test('each bar group has two bars (page_views + unique_visitors)', () => {
    const hook = mountHook(DailyChart, chartHTML())
    hook.mounted()

    const barGroups = hook.el.querySelectorAll('.bar-group')
    barGroups.forEach(group => {
      const rects = group.querySelectorAll('rect')
      expect(rects).toHaveLength(2)
    })
  })

  test('renders nothing for empty data', () => {
    const hook = mountHook(DailyChart, chartHTML([]))
    hook.mounted()

    const svg = hook.el.querySelector('svg')
    expect(svg).toBeNull()
  })

  test('renders nothing for null data', () => {
    const hook = mountHook(DailyChart, '<div data-chart="null"></div>')
    hook.mounted()

    expect(hook.el.querySelector('svg')).toBeNull()
  })

  test('updated re-renders the chart', () => {
    const hook = mountHook(DailyChart, chartHTML())
    hook.mounted()

    expect(hook.el.querySelectorAll('.bar-group')).toHaveLength(3)

    // Simulate LiveView updating with new data
    hook.el.dataset.chart = JSON.stringify([
      { date: '2026-03-01', page_views: 100, unique_visitors: 50 }
    ])
    hook.updated()

    expect(hook.el.querySelectorAll('.bar-group')).toHaveLength(1)
  })

  test('creates tooltip element', () => {
    const hook = mountHook(DailyChart, chartHTML())
    hook.mounted()

    const tooltip = document.body.querySelector('.chart-tooltip')
    expect(tooltip).toBeTruthy()
  })

  test('renders axes', () => {
    const hook = mountHook(DailyChart, chartHTML())
    hook.mounted()

    // d3 axes create <g> elements with class 'tick'
    const svg = hook.el.querySelector('svg')
    const ticks = svg.querySelectorAll('.tick')
    expect(ticks.length).toBeGreaterThan(0)
  })
})
