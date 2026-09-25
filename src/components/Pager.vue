<script setup>
import { t } from "../composables/useI18n";
import Icon from "./Icon.vue";

defineProps({
  range: { type: String, default: "" },
  newer: Boolean,
  older: Boolean,
});
defineEmits(["newest", "newer", "older"]);

const step =
  "flex size-5 items-center justify-center rounded-tight border border-line-strong text-text-muted transition-colors hover:bg-surface-raised hover:text-text disabled:opacity-40 disabled:hover:bg-transparent";
</script>

<template>
  <div class="flex shrink-0 items-center gap-1">
    <button
      v-if="newer"
      class="h-5 rounded-tight px-1.5 text-micro text-text-muted underline transition-colors hover:text-text"
      @click="$emit('newest')"
    >
      {{ t("pager.newest") }}
    </button>
    <button :disabled="!newer" :title="t('pager.newer')" :class="step" @click="$emit('newer')">
      <Icon name="left" :size="12" />
    </button>
    <span v-if="range" class="px-1 font-mono whitespace-nowrap">{{ range }}</span>
    <button :disabled="!older" :title="t('pager.older')" :class="step" @click="$emit('older')">
      <Icon name="right" :size="12" />
    </button>
  </div>
</template>
