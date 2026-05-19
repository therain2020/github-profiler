<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAnalysisStore } from '../stores/analysis'
import ProgressBar from '../components/ProgressBar.vue'

const props = defineProps<{ username: string }>()
const router = useRouter()
const store = useAnalysisStore()

const fetchPhase = ref(0)
const fetchPhaseLabel = ref('')
const analysisPhase = ref('')

let eventSource: EventSource | null = null

function buildAnalysisUrl(): string {
  const params = new URLSearchParams({
    github_token: store.githubToken,
    llm_provider: store.llmProvider,
    llm_key: store.llmKey,
  })
  if (store.llmModel) params.set('llm_model', store.llmModel)
  return `/api/analyze/${props.username}?${params}`
}

function startSSE() {
  import.meta.env.DEV ? startDevFlow() : startProdSSE()
}

function startProdSSE() {
  eventSource = new EventSource(buildAnalysisUrl())

  eventSource.addEventListener('progress', (e) => {
    const data = JSON.parse(e.data)
    if (data.stage === 'fetch') {
      fetchPhase.value = data.step
      fetchPhaseLabel.value = data.label
      store.progress = { step: data.step, total: data.total, label: data.label }
    } else if (data.stage === 'analysis') {
      analysisPhase.value = data.label
    }
  })

  eventSource.addEventListener('complete', (e) => {
    const data = JSON.parse(e.data)
    store.result = data
    store.isAnalyzing = false
    eventSource?.close()
    router.push({ name: 'result', params: { id: data.id } })
  })

  eventSource.addEventListener('error', (e) => {
    const data = e.data ? JSON.parse(e.data) : { message: '未知错误' }
    store.error = data.message
    store.isAnalyzing = false
    eventSource?.close()
  })

  eventSource.onerror = () => {
    store.error = '连接中断，请重试'
    store.isAnalyzing = false
    eventSource?.close()
  }
}

function startDevFlow() {
  // Mock SSE flow for local dev
  const phases = [
    { stage: 'fetch', step: 1, label: '正在获取用户资料...' },
    { stage: 'fetch', step: 2, label: '正在获取仓库列表...' },
    { stage: 'fetch', step: 3, label: '正在获取组织...' },
    { stage: 'fetch', step: 4, label: '正在获取贡献记录...' },
    { stage: 'fetch', step: 5, label: '正在获取 PR/Issue 活动...' },
    { stage: 'fetch', step: 6, label: '正在深度抓取仓库内容...' },
    { stage: 'fetch', step: 7, label: '正在获取 Gist...' },
    { stage: 'analysis', label: '正在生成六维评分...' },
    { stage: 'analysis', label: '正在蒸馏人格画像...' },
    { stage: 'analysis', label: '正在生成成长方案...' },
  ]

  let i = 0
  const timer = setInterval(() => {
    if (i >= phases.length) {
      clearInterval(timer)
      store.isAnalyzing = false
      store.error = null
      alert('Dev mode: mock analysis complete. Backend not connected.')
      router.push({ name: 'home' })
      return
    }
    const p = phases[i]
    if (p.stage === 'fetch') {
      fetchPhase.value = p.step!
      fetchPhaseLabel.value = p.label
      store.progress = { step: p.step!, total: 7, label: p.label }
    } else {
      analysisPhase.value = p.label
    }
    i++
  }, 800)
}

onMounted(() => {
  store.isAnalyzing = true
  store.error = null
  startSSE()
})

onUnmounted(() => {
  eventSource?.close()
})
</script>

<template>
  <div class="analyzing">
    <ProgressBar
      :current="fetchPhase"
      :total="7"
      :label="fetchPhaseLabel || '准备中...'"
    />

    <div v-if="analysisPhase" class="analysis-status">
      <div class="spinner"></div>
      <p>{{ analysisPhase }}</p>
    </div>

    <div v-if="store.error" class="error-box">
      <p>{{ store.error }}</p>
      <router-link to="/" class="retry-link">返回首页重试</router-link>
    </div>
  </div>
</template>

<style scoped>
.analyzing {
  max-width: 520px;
  margin: 80px auto;
  padding: 0 20px;
}

.analysis-status {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 32px;
  color: #666;
  font-size: 15px;
}

.spinner {
  width: 20px;
  height: 20px;
  border: 2px solid #e5e7eb;
  border-top-color: #4f46e5;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error-box {
  margin-top: 32px;
  padding: 20px;
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 10px;
  text-align: center;
}

.error-box p {
  color: #dc2626;
  margin: 0 0 12px;
}

.retry-link {
  color: #4f46e5;
  text-decoration: none;
}
</style>
