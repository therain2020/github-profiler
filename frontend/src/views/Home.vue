<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAnalysisStore } from '../stores/analysis'

const router = useRouter()
const store = useAnalysisStore()

const username = ref('')
const ghToken = ref('')
const provider = ref('deepseek')
const apiKey = ref('')
const model = ref('')

const providers = [
  { value: 'deepseek', label: 'DeepSeek', defaultModel: 'deepseek-chat' },
  { value: 'qwen', label: '通义千问', defaultModel: 'qwen-plus' },
  { value: 'openai', label: 'OpenAI', defaultModel: 'gpt-4o-mini' },
  { value: 'claude', label: 'Claude', defaultModel: 'claude-sonnet-4-6' },
]

const options = {
  scoring: ref(true),
  distill: ref(true),
  optimize: ref(true),
}

function startAnalysis() {
  if (!username.value.trim() || !ghToken.value.trim() || !apiKey.value.trim()) return

  const selected = providers.find(p => p.value === provider.value)!
  store.setCredentials(ghToken.value, provider.value, apiKey.value, model.value || selected.defaultModel)
  store.username = username.value
  store.reset()

  router.push({ name: 'analyzing', params: { username: username.value } })
}
</script>

<template>
  <div class="home">
    <header class="hero">
      <h1>GitHub Profiler</h1>
      <p class="subtitle">用你的数据，发现世界上的另一个自己</p>
    </header>

    <form class="input-form" @submit.prevent="startAnalysis">
      <div class="form-group">
        <label for="username">GitHub 用户名</label>
        <input
          id="username"
          v-model="username"
          type="text"
          placeholder="例如: torvalds"
          required
        />
      </div>

      <div class="form-group">
        <label for="ghToken">
          GitHub Token
          <span class="hint">仅需读取权限，用完建议吊销</span>
        </label>
        <input
          id="ghToken"
          v-model="ghToken"
          type="password"
          placeholder="ghp_..."
          required
        />
      </div>

      <div class="form-row">
        <div class="form-group">
          <label for="provider">大模型</label>
          <select id="provider" v-model="provider">
            <option v-for="p in providers" :key="p.value" :value="p.value">
              {{ p.label }}
            </option>
          </select>
        </div>

        <div class="form-group">
          <label for="apiKey">API Key</label>
          <input
            id="apiKey"
            v-model="apiKey"
            type="password"
            placeholder="sk-..."
            required
          />
        </div>
      </div>

      <div class="form-group">
        <label for="model">模型 (可选，留空用默认)</label>
        <input
          id="model"
          v-model="model"
          type="text"
          :placeholder="providers.find(p => p.value === provider)?.defaultModel"
        />
      </div>

      <fieldset>
        <legend>分析内容</legend>
        <label class="checkbox-label"><input type="checkbox" v-model="options.scoring" checked /> 六维评分</label>
        <label class="checkbox-label"><input type="checkbox" v-model="options.distill" checked /> 人格蒸馏</label>
        <label class="checkbox-label"><input type="checkbox" v-model="options.optimize" checked /> 成长方案</label>
      </fieldset>

      <button type="submit" class="btn-primary">开始分析</button>
    </form>

    <nav class="bottom-nav">
      <router-link to="/leaderboard">查看排行榜</router-link>
    </nav>
  </div>
</template>

<style scoped>
.home {
  max-width: 560px;
  margin: 0 auto;
  padding: 40px 20px;
}

.hero {
  text-align: center;
  margin-bottom: 40px;
}

.hero h1 {
  font-size: 32px;
  font-weight: 700;
  color: #1a1a2e;
  margin: 0 0 8px;
}

.subtitle {
  color: #666;
  font-size: 16px;
  margin: 0;
}

.input-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-group label {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.hint {
  font-size: 12px;
  color: #999;
  font-weight: 400;
  margin-left: 8px;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

input, select {
  padding: 10px 14px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 15px;
  font-family: inherit;
  transition: border-color 0.2s;
}

input:focus, select:focus {
  outline: none;
  border-color: #4f46e5;
  box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
}

fieldset {
  border: 1px solid #eee;
  border-radius: 8px;
  padding: 14px 18px;
  display: flex;
  gap: 20px;
  flex-wrap: wrap;
}

legend {
  font-size: 14px;
  font-weight: 500;
  color: #333;
  padding: 0 6px;
}

.checkbox-label {
  font-size: 14px;
  color: #555;
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
}

.btn-primary {
  padding: 14px;
  background: linear-gradient(135deg, #4f46e5, #7c3aed);
  color: #fff;
  border: none;
  border-radius: 10px;
  font-size: 17px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.15s, box-shadow 0.15s;
}

.btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 16px rgba(79, 70, 229, 0.3);
}

.btn-primary:active {
  transform: translateY(0);
}

.bottom-nav {
  margin-top: 32px;
  text-align: center;
}

.bottom-nav a {
  color: #4f46e5;
  text-decoration: none;
  font-size: 15px;
}
</style>
