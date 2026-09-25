<script setup>
import { t } from "../composables/useI18n";

defineProps({
  counts: { type: Array, required: true },
  pinned: { type: String, default: "" },
  previewing: { type: Boolean, default: false },
});
defineEmits(["unpin"]);
</script>

<template>
  <div class="flex min-w-0 flex-1 items-center gap-4 px-1">
    <span v-for="c in counts" :key="c.key" class="shrink-0 text-small whitespace-nowrap text-text-muted">
      {{ t(c.key) }}
      <span class="font-mono" :class="c.changed ? 'text-confirm' : 'text-text-bright'">{{ c.text }}</span>
    </span>
    <button
      v-if="pinned"
      class="rounded-badge border border-accent px-[7px] text-micro text-text-bright transition-colors hover:bg-surface-raised"
      :title="t('reach.pinnedTitle')"
      @click="$emit('unpin')"
    >
      {{ t("reach.pinned", { node: pinned }) }}
    </button>
    <span v-if="previewing" class="ml-auto truncate text-small text-confirm">{{ t("reach.previewOn") }}</span>
  </div>
</template>
