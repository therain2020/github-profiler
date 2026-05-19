<script setup lang="ts">
defineProps<{
  current: number
  total: number
  label: string
}>()
</script>

<template>
  <div class="progress-container">
    <div class="progress-bar-bg">
      <div
        class="progress-bar-fill"
        :style="{ width: total > 0 ? (current / total) * 100 + '%' : '0%' }"
      ></div>
    </div>
    <p class="progress-label">{{ label }}</p>
    <p class="progress-count">{{ current }} / {{ total }}</p>
  </div>
</template>

<style scoped>
.progress-container {
  text-align: center;
}

.progress-bar-bg {
  width: 100%;
  height: 6px;
  background: #e5e7eb;
  border-radius: 3px;
  overflow: hidden;
}

.progress-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, #4f46e5, #7c3aed);
  border-radius: 3px;
  transition: width 0.4s ease;
}

.progress-label {
  margin-top: 16px;
  font-size: 16px;
  color: #333;
  font-weight: 500;
}

.progress-count {
  margin-top: 4px;
  font-size: 13px;
  color: #999;
}
</style>
