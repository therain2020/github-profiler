import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export interface ProgressEvent {
  step: number
  total: number
  label: string
}

export interface AnalysisResult {
  id: string
  username: string
  score: Record<string, number>
  composite_score: number
  summary: Record<string, string[]>
  persona?: Record<string, unknown>
  recommendations?: Record<string, unknown>
  visualization_data?: Record<string, unknown>
}

export const useAnalysisStore = defineStore('analysis', () => {
  const username = ref('')
  const githubToken = ref('')
  const llmProvider = ref('deepseek')
  const llmKey = ref('')
  const llmModel = ref('')

  const progress = ref<ProgressEvent | null>(null)
  const error = ref<string | null>(null)
  const result = ref<AnalysisResult | null>(null)
  const isAnalyzing = ref(false)

  const progressPercent = computed(() => {
    if (!progress.value || progress.value.total === 0) return 0
    return Math.round((progress.value.step / progress.value.total) * 100)
  })

  function setCredentials(ghToken: string, provider: string, key: string, model?: string) {
    githubToken.value = ghToken
    llmProvider.value = provider
    llmKey.value = key
    if (model) llmModel.value = model
  }

  function clearCredentials() {
    githubToken.value = ''
    llmKey.value = ''
  }

  function reset() {
    progress.value = null
    error.value = null
    result.value = null
    isAnalyzing.value = false
  }

  return {
    username,
    githubToken,
    llmProvider,
    llmKey,
    llmModel,
    progress,
    error,
    result,
    isAnalyzing,
    progressPercent,
    setCredentials,
    clearCredentials,
    reset,
  }
})
