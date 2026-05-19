<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface LeaderboardEntry {
  username: string
  avatar_url: string | null
  composite_score: number
  productivity: number
  influence: number
  quality: number
  collaboration: number
  knowledge_sharing: number
  growth_potential: number
  profile_tags: string[]
  scored_at: string
}

const entries = ref<LeaderboardEntry[]>([])
const loading = ref(true)
const error = ref('')

async function loadLeaderboard() {
  try {
    const resp = await fetch('/api/leaderboard?limit=50')
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`)
    entries.value = await resp.json()
  } catch (e) {
    error.value = '排行榜暂时不可用'
  } finally {
    loading.value = false
  }
}

onMounted(loadLeaderboard)
</script>

<template>
  <div class="leaderboard-page">
    <h1>排行榜</h1>

    <div v-if="loading" class="loading">加载中...</div>

    <div v-else-if="error" class="error">{{ error }}</div>

    <div v-else-if="entries.length === 0" class="empty">
      <p>还没有评分数据。成为第一个上传的人！</p>
    </div>

    <table v-else class="lb-table">
      <thead>
        <tr>
          <th>#</th>
          <th>用户</th>
          <th>综合</th>
          <th>生产力</th>
          <th>影响力</th>
          <th>质量</th>
          <th>协作</th>
          <th>分享</th>
          <th>成长</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(e, i) in entries" :key="e.username">
          <td class="rank">{{ i + 1 }}</td>
          <td class="user-cell">
            <img v-if="e.avatar_url" :src="e.avatar_url" class="avatar" alt="" />
            <span>{{ e.username }}</span>
          </td>
          <td class="composite">{{ e.composite_score }}</td>
          <td>{{ e.productivity }}</td>
          <td>{{ e.influence }}</td>
          <td>{{ e.quality }}</td>
          <td>{{ e.collaboration }}</td>
          <td>{{ e.knowledge_sharing }}</td>
          <td>{{ e.growth_potential }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.leaderboard-page {
  max-width: 960px;
  margin: 0 auto;
  padding: 40px 20px;
}

h1 {
  font-size: 28px;
  color: #1a1a2e;
  margin: 0 0 32px;
  text-align: center;
}

.lb-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.lb-table th,
.lb-table td {
  padding: 10px 8px;
  text-align: center;
  border-bottom: 1px solid #f3f4f6;
}

.lb-table th {
  font-weight: 600;
  color: #666;
  font-size: 13px;
  white-space: nowrap;
}

.lb-table tbody tr:hover {
  background: #f9fafb;
}

.rank {
  font-weight: 700;
  color: #4f46e5;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: flex-start;
  text-align: left;
}

.avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
}

.composite {
  font-weight: 700;
  color: #1a1a2e;
}

.loading, .error, .empty {
  text-align: center;
  padding: 60px 20px;
  color: #888;
}
</style>
