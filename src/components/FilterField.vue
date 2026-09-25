<script setup>
import Icon from "./Icon.vue";

defineProps({
  placeholder: { type: String, default: "Filter rows" },
  width: { type: String, default: "220px" },
});
const model = defineModel({ type: String, default: "" });
</script>

<template>
  <div
    class="flex h-[var(--size-field)] min-w-0 items-center gap-1.5 rounded-control border border-line-strong bg-surface px-2"
    :class="width === 'auto' ? 'flex-1' : 'shrink-0'"
    :style="width !== 'auto' && { width }"
  >
    <Icon name="search" :size="13" class="text-text-muted" />
    <input
      v-model="model"
      :placeholder="placeholder"
      class="min-w-0 flex-1 border-0 bg-transparent text-small outline-none placeholder:text-text-muted"
    />
  </div>
</template>
