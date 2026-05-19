<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAnalysisStore } from '../stores/analysis'
import RadarChart from '../components/RadarChart.vue'
import PersonaCard from '../components/PersonaCard.vue'
import ScreenshotBtn from '../components/ScreenshotBtn.vue'

const props = defineProps<{ id: string }>()
const router = useRouter()
const store = useAnalysisStore()

const tab = ref<'score' | 'persona' | 'plan'>('score')

onMounted(() => {
  if (!store.result) {
    // Try loading from localStorage
    const saved = localStorage.getItem(`report-${props.id}`)
    if (saved) {
      store.result = JSON.parse(saved)
    } else {
      router.push({ name: 'home' })
    }
  }
})
</script>

<template>
  <div v-if="store.result" class="result-page">
    <header class="result-header">
      <h1>@{{ store.result.username }}</h1>
      <div class="composite">
        <span class="big-score">{{ store.result.composite_score }}</span>
        <span class="score-label">综合评分</span>
      </div>
    </header>

    <div class="tabs">
      <button :class="{ active: tab === 'score' }" @click="tab = 'score'">评分</button>
      <button :class="{ active: tab === 'persona' }" @click="tab = 'persona'">人格</button>
      <button :class="{ active: tab === 'plan' }" @click="tab = 'plan'">成长</button>
    </div>

    <section v-if="tab === 'score' && store.result.visualization_data?.radar">
      <RadarChart :data="store.result.visualization_data.radar" />
      <ScreenshotBtn />
    </section>

    <section v-if="tab === 'persona' && store.result.persona">
      <PersonaCard :persona="store.result.persona" />
    </section>

    <section v-if="tab === 'plan' && store.result.recommendations">
      <div class="recommendations">
        <h2>成长建议</h2>
        <pre>{{ JSON.stringify(store.result.recommendations, null, 2) }}</pre>
      </div>
    </section>

    <div class="actions">
      <button class="btn-secondary" @click="router.push({ name: 'home' })">分析另一个用户</button>
    </div>
  </div>
</template>

<style scoped>
.result-page {
  max-width: 720px;
  margin: 0 auto;
  padding: 40px 20px;
}

.result-header {
  text-align: center;
  margin-bottom: 32px;
}

.result-header h1 {
  font-size: 28px;
  color: #1a1a2e;
  margin: 0 0 12px;
}

.composite {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.big-score {
  font-size: 56px;
  font-weight: 800;
  color: #1a1a2e;
  line-height: 1;
}

.score-label {
  font-size: 14px;
  color: #888;
  margin-top: 4px;
}

.tabs {
  display: flex;
  gap: 0;
  margin-bottom: 32px;
  border-bottom: 2px solid #eee;
}

.tabs button {
  flex: 1;
  padding: 12px;
  border: none;
  background: none;
  font-size: 15px;
  color: #888;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
  transition: color 0.15s, border-color 0.15s;
}

.tabs button.active {
  color: #4f46e5;
  border-bottom-color: #4f46e5;
}

.actions {
  margin-top: 40px;
  text-align: center;
}

.btn-secondary {
  padding: 12px 28px;
  background: #fff;
  color: #4f46e5;
  border: 1px solid #4f46e5;
  border-radius: 8px;
  font-size: 15px;
  cursor: pointer;
}

.recommendations h2 {
  font-size: 20px;
  margin-bottom: 16px;
}

.recommendations pre {
  background: #f8f9fa;
  padding: 20px;
  border-radius: 8px;
  overflow-x: auto;
  font-size: 13px;
  line-height: 1.6;
}
</style>
