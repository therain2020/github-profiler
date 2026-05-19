<script setup lang="ts">
defineProps<{
  persona: Record<string, unknown>
}>()
</script>

<template>
  <div class="persona-card">
    <div class="card-inner">
      <h2 class="alias">{{ persona.alias || persona.distilled_self?.tech_role }}</h2>
      <p class="realm">{{ persona.realm }}</p>

      <div v-if="persona.personality_tags" class="tags">
        <span v-for="tag in persona.personality_tags" :key="tag" class="tag">{{ tag }}</span>
      </div>

      <blockquote v-if="persona.quote" class="quote">
        "{{ persona.quote }}"
      </blockquote>

      <div v-if="persona.similarity" class="similarity">
        相似度: {{ persona.similarity }}%
      </div>
    </div>
  </div>
</template>

<style scoped>
.persona-card {
  background: linear-gradient(135deg, #1a1a2e, #16213e, #0f3460);
  border-radius: 16px;
  padding: 36px 28px;
  color: #fff;
  text-align: center;
}

.alias {
  font-size: 24px;
  font-weight: 700;
  margin: 0 0 8px;
}

.realm {
  font-size: 14px;
  color: rgba(255,255,255,0.6);
  margin: 0 0 20px;
}

.tags {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 8px;
  margin-bottom: 24px;
}

.tag {
  font-size: 13px;
  padding: 4px 14px;
  border-radius: 20px;
  background: rgba(255,255,255,0.12);
  color: rgba(255,255,255,0.85);
}

.quote {
  font-size: 15px;
  font-style: italic;
  color: rgba(255,255,255,0.7);
  border: none;
  margin: 0 0 20px;
  line-height: 1.6;
}

.similarity {
  font-size: 13px;
  color: rgba(255,255,255,0.5);
}
</style>
