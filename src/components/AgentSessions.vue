<script setup>
import { t } from "../composables/useI18n";
import Block from "./Block.vue";
import Icon from "./Icon.vue";

defineProps({
  sessions: { type: Array, default: () => [] },
  current: { type: String, default: "" },
});
defineEmits(["open", "remove"]);

const meta = (s) => [s.updatedAt ? s.updatedAt.slice(5, 16) : "", `${s.messages} msg`].filter(Boolean).join(" · ");
</script>

<template>
  <Block :title="t('agent.conversations')" class="w-[220px] shrink-0">
    <div class="min-h-0 flex-1 space-y-0.5 overflow-y-auto p-1.5">
      <div v-for="s in sessions" :key="s.id" class="relative">
        <button
          class="w-full rounded-control border py-1.5 pr-7 pl-2 text-left transition-colors"
          :class="
            s.id === current
              ? 'border-line-strong bg-surface-raised text-text-bright'
              : 'border-transparent text-text-muted hover:bg-surface-raised'
          "
          @click="$emit('open', s.id)"
        >
          <span class="line-clamp-2 text-micro">{{ s.title }}</span>
          <span class="mt-0.5 block font-mono text-micro text-text-muted">{{ meta(s) }}</span>
        </button>
        <button
          class="absolute top-1 right-1 flex size-5 items-center justify-center rounded-tight text-text-muted transition-colors hover:bg-surface hover:text-deny"
          :title="t('agent.removeTitle')"
          @click="$emit('remove', s.id)"
        >
          <Icon name="close" :size="12" />
        </button>
      </div>
      <p v-if="!sessions.length" class="px-2 py-1.5 text-micro text-text-muted">
        {{ t("agent.none") }}
      </p>
    </div>
  </Block>
</template>
