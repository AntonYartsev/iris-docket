<script setup>
import { ref } from "vue";
import Icon from "./Icon.vue";

defineProps({
  title: { type: String, required: true },
  meta: { type: String, default: "" },
  metaTitle: { type: String, default: "" },
  collapsible: { type: Boolean, default: false },
  scroll: { type: Boolean, default: true },
});

const shut = ref(false);
</script>

<template>
  <section
    class="flex min-h-0 min-w-0 flex-col overflow-hidden rounded-card border border-line bg-surface"
    :class="shut && 'flex-none'"
  >
    <div class="flex min-h-[var(--size-panel-head)] shrink-0 items-center gap-2 border-b border-line bg-inset px-2.5">
      <span class="shrink-0 text-micro tracking-[0.04em] whitespace-nowrap text-text-muted">{{ title }}</span>
      <span v-if="meta" :title="metaTitle || meta" class="min-w-0 truncate text-micro text-text-muted">{{ meta }}</span>
      <div class="ml-auto flex shrink-0 items-center gap-2">
        <slot name="actions" />
        <button
          v-if="collapsible"
          class="flex size-[22px] items-center justify-center rounded-tight text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
          :title="shut ? 'Open this block' : 'Collapse this block'"
          @click="shut = !shut"
        >
          <Icon name="chevron" :size="14" :class="shut && '-rotate-90'" />
        </button>
      </div>
    </div>

    <div v-show="!shut" class="flex min-h-0 flex-1 flex-col" :class="scroll ? 'overflow-hidden' : 'overflow-y-auto'">
      <slot />
    </div>

    <div
      v-if="$slots.footer && !shut"
      class="flex h-[var(--size-panel-foot)] shrink-0 items-center gap-2 border-t border-line bg-inset px-2.5 text-micro text-text-muted"
    >
      <slot name="footer" />
    </div>
  </section>
</template>
