<script setup>
defineProps({
  tabs: { type: Array, required: true },
  size: { type: String, default: "md" },
});
const model = defineModel({ type: String, required: true });
</script>

<template>
  <button
    v-for="t in tabs"
    :key="t.key"
    class="flex shrink-0 items-center gap-1.5 rounded-control border border-line transition-colors"
    :class="[
      size === 'sm' ? 'h-[22px] px-2 text-micro' : 'h-[var(--size-btn)] px-[11px] text-small',
      model === t.key
        ? 'bg-surface-raised text-text-bright'
        : 'bg-surface text-text-muted hover:bg-surface-raised hover:text-text',
    ]"
    @click="model = t.key"
  >
    {{ t.label }}
    <span v-if="t.count !== undefined" class="text-micro text-text-muted">{{ t.count }}</span>
  </button>
</template>
