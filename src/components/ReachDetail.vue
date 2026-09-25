<script setup>
import { t } from "../composables/useI18n";
import DecisionBadge from "./DecisionBadge.vue";
import { RANK } from "../composables/useReachLayout";

const TONE = { high: "border-deny text-deny", medium: "border-confirm text-confirm" };

defineProps({
  link: { type: Object, required: true },
  decision: { type: Object, default: null },
  previewing: { type: Boolean, default: false },
  busy: { type: Boolean, default: false },
  auditId: { type: [Number, String], default: 0 },
});
defineEmits(["preview", "apply"]);
</script>

<template>
  <div class="border-b border-line px-2.5 py-[9px]">
    <span
      class="inline-flex h-5 items-center gap-1.5 rounded-badge border px-[7px] text-micro font-medium"
      :class="TONE[link.severity] ?? 'border-line-strong text-text-muted'"
    >
      <span class="size-[5px] rounded-badge bg-current" />{{ t(`reach.legend.${RANK[link.severity] ?? 0}`) }}
    </span>
    <h2 class="mt-1.5 font-mono text-micro break-words text-text-bright">{{ link.path }}</h2>
    <p class="mt-1.5 text-micro text-text">{{ link.evidence }}</p>
  </div>

  <div v-if="link.probe" class="border-b border-line px-2.5 py-[9px]">
    <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">{{ t("findings.probe") }}</div>
    <p class="font-mono text-micro break-words text-text">{{ link.probe }}</p>
  </div>

  <div v-if="link.fix" class="border-b border-line px-2.5 py-[9px]">
    <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">{{ t("findings.theFix") }}</div>
    <p class="mb-1.5 font-mono text-micro break-all text-text">
      {{ link.fix.tool }} {{ JSON.stringify(link.fix.args) }}
    </p>
    <div class="flex flex-wrap items-center gap-2">
      <button
        class="h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised"
        :title="t('reach.previewTitle')"
        @click="$emit('preview')"
      >
        {{ previewing ? t("reach.previewOff") : t("reach.preview") }}
      </button>
      <button
        :disabled="busy || decision?.decision === 'deny'"
        class="h-[var(--size-btn)] rounded-control bg-accent px-[11px] text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:cursor-not-allowed disabled:opacity-40"
        :title="
          decision?.decision === 'deny' ? t('findings.denied', { rule: decision.ruleId }) : t('findings.fixTitle')
        "
        @click="$emit('apply')"
      >
        {{ busy ? t("findings.fixing") : t("reach.apply") }}
      </button>
      <DecisionBadge v-if="decision" :decision="decision.decision" :rule="decision.ruleId" />
    </div>
  </div>
  <p v-else class="border-b border-line px-2.5 py-[9px] text-micro text-text-muted">
    {{ link.noFixReason || t("findings.noFixLong") }}
  </p>

  <RouterLink
    v-if="auditId"
    :to="`/audit?q=${auditId}`"
    class="block px-2.5 py-[9px] text-micro text-text-muted underline"
  >
    {{ t("findings.inJournal") }}
  </RouterLink>
</template>
