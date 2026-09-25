<script setup>
import { onMounted, onUnmounted } from "vue";
import Icon from "./Icon.vue";

defineProps({
  title: { type: String, required: true },
  subject: { type: String, default: "" },
});
const emit = defineEmits(["close"]);

// capture, so dialogs close first
const onKey = (e) =>
  e.key === "Escape" && !document.querySelector("[aria-modal='true'], :popover-open") && emit("close");
onMounted(() => window.addEventListener("keydown", onKey, true));
onUnmounted(() => window.removeEventListener("keydown", onKey, true));
</script>

<template>
  <section
    data-zone="detail"
    class="flex min-h-0 shrink-0 flex-col overflow-hidden rounded-card border border-line bg-surface"
  >
    <div class="flex min-h-[var(--size-panel-head)] shrink-0 items-center gap-2 border-b border-line bg-inset px-2.5">
      <span class="shrink-0 text-micro tracking-[0.04em] whitespace-nowrap text-text-muted">{{ title }}</span>
      <span class="min-w-0 truncate font-mono text-micro text-text-bright">{{ subject }}</span>
      <button
        class="ml-auto flex size-[22px] shrink-0 items-center justify-center rounded-tight text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
        title="Close the detail panel"
        @click="$emit('close')"
      >
        <Icon name="close" :size="14" />
      </button>
    </div>
    <div class="min-h-0 flex-1 overflow-y-auto">
      <slot />
    </div>
  </section>
</template>
