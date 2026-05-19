<script setup lang="ts">
import { ref } from 'vue'
import html2canvas from 'html2canvas'

const capturing = ref(false)

async function captureScreenshot() {
  capturing.value = true
  try {
    const el = document.querySelector('.result-page') as HTMLElement
    if (!el) return
    const canvas = await html2canvas(el, {
      backgroundColor: '#ffffff',
      scale: 2,
    })
    const link = document.createElement('a')
    link.download = 'github-profiler-report.png'
    link.href = canvas.toDataURL('image/png')
    link.click()
  } finally {
    capturing.value = false
  }
}
</script>

<template>
  <button class="screenshot-btn" :disabled="capturing" @click="captureScreenshot">
    {{ capturing ? '正在生成...' : '下载报告图片' }}
  </button>
</template>

<style scoped>
.screenshot-btn {
  display: block;
  margin: 24px auto;
  padding: 12px 32px;
  background: #1a1a2e;
  color: #fff;
  border: none;
  border-radius: 8px;
  font-size: 15px;
  cursor: pointer;
  transition: opacity 0.15s;
}

.screenshot-btn:hover {
  opacity: 0.9;
}

.screenshot-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
