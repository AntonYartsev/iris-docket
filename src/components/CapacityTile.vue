<script setup>
import { facts } from "../composables/useShell";
import { t } from "../composables/useI18n";

const pct = (v) => (v === null ? "-" : Math.round(v));
const gb = (mb) => (mb === null ? "-" : `${(mb / 1024).toFixed(1)} GB`);
</script>

<template>
  <div class="min-w-0 border-l border-line px-3 py-2">
    <div class="text-micro tracking-[0.04em] text-text-muted">{{ t("health.capacity") }}</div>
    <div
      v-for="c in [
        {
          label: t('health.disk'),
          value: t('health.diskValue', { pct: pct(facts.disk), free: gb(facts.diskFreeMb) }),
          fill: facts.disk,
        },
        {
          label: t('health.licence', { days: facts.licenceDays === null ? '-' : Math.round(facts.licenceDays) }),
          value: t('health.licenceValue', { used: facts.licenceUsed ?? '-', of: facts.licenceUnits ?? '-' }),
          fill: facts.licence,
        },
      ]"
      :key="c.label"
      class="mt-2"
    >
      <div class="flex justify-between gap-2 text-micro whitespace-nowrap">
        <span class="truncate text-text-muted">{{ c.label }}</span>
        <span class="font-mono text-text">{{ c.value }}</span>
      </div>
      <div class="mt-1 h-1.5 overflow-hidden rounded-badge bg-surface-raised">
        <div
          class="h-full rounded-badge"
          :class="c.fill >= 90 ? 'bg-deny' : c.fill >= 75 ? 'bg-confirm' : 'bg-accent'"
          :style="{ width: `${Math.max(1, c.fill ?? 0)}%` }"
        />
      </div>
    </div>
    <div class="mt-2.5 flex flex-wrap gap-x-3 text-micro whitespace-nowrap text-text-muted">
      <span
        v-for="[k, v] in [
          ['health.processes', facts.processes],
          ['health.sessions', facts.sessions],
        ]"
        :key="k"
      >
        <span class="font-mono text-small text-text-bright">{{ v ?? "-" }}</span> {{ t(k) }}
      </span>
    </div>
  </div>
</template>
