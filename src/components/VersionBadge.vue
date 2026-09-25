<script setup>
import Icon from "./Icon.vue";

defineProps({
  tool: { type: Object, required: true },
});
</script>

<template>
  <span
    v-if="tool.available === false"
    :title="tool.unavailable?.reason"
    class="inline-flex h-5 shrink-0 items-center gap-1 rounded-badge border border-line-strong px-[7px] text-micro font-medium whitespace-nowrap text-text-muted"
  >
    <Icon name="lock" :size="11" />not in {{ tool.unavailable?.version || "this version" }}
  </span>
</template>
