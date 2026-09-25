<script setup>
import { ref, watch } from "vue";
import Icon from "./Icon.vue";

const props = defineProps({
  busy: { type: Boolean, default: false },
  title: { type: String, required: true },
});

const spinning = ref(false);
watch(
  () => props.busy,
  (b) => b && (spinning.value = true),
  { immediate: true },
);
const lap = () => props.busy || (spinning.value = false);
</script>

<template>
  <button
    :disabled="busy"
    :aria-busy="busy"
    :title="title"
    class="flex size-[var(--size-btn)] shrink-0 items-center justify-center rounded-control border border-line-strong text-text-muted transition-colors hover:bg-surface-raised hover:text-text disabled:cursor-default disabled:hover:bg-transparent"
  >
    <Icon name="refresh" :class="spinning && 'text-accent motion-safe:animate-spin'" @animationiteration="lap" />
  </button>
</template>
