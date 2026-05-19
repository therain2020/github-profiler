<script setup lang="ts">
import { onMounted, ref } from 'vue'
import * as echarts from 'echarts'

const props = defineProps<{
  data: {
    dimensions: string[]
    values: number[]
    another_me_values?: number[]
  }
}>()

const chartRef = ref<HTMLDivElement>()

onMounted(() => {
  if (!chartRef.value) return
  const chart = echarts.init(chartRef.value)

  const indicator = props.data.dimensions.map((name) => ({
    name,
    max: 100,
  }))

  const series: echarts.RadarSeriesOption[] = [
    {
      type: 'radar',
      name: '你',
      data: [{ value: props.data.values, name: '你' }],
      symbol: 'circle',
      symbolSize: 4,
      lineStyle: { color: '#4f46e5', width: 2 },
      areaStyle: { color: 'rgba(79, 70, 229, 0.1)' },
      itemStyle: { color: '#4f46e5' },
    },
  ]

  if (props.data.another_me_values) {
    series.push({
      type: 'radar',
      name: '世界上的另一个我',
      data: [{ value: props.data.another_me_values, name: '镜像' }],
      symbol: 'diamond',
      symbolSize: 4,
      lineStyle: { color: '#f59e0b', width: 2, type: 'dashed' },
      areaStyle: { color: 'rgba(245, 158, 11, 0.05)' },
      itemStyle: { color: '#f59e0b' },
    })
  }

  chart.setOption({
    radar: {
      indicator,
      center: ['50%', '55%'],
      radius: '65%',
      axisName: { fontSize: 12, color: '#666' },
    },
    series,
  })

  const observer = new ResizeObserver(() => chart.resize())
  observer.observe(chartRef.value)
})
</script>

<template>
  <div ref="chartRef" class="radar-chart"></div>
</template>

<style scoped>
.radar-chart {
  width: 100%;
  height: 400px;
}
</style>
