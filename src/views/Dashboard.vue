<script setup>
import { computed } from "vue";
import { FAST_MS, apiState, facts, info, latency, polls } from "../composables/useShell";
import { t } from "../composables/useI18n";
import HealthBlock from "../components/HealthBlock.vue";
import ActivityBlock from "../components/ActivityBlock.vue";
import AttentionBlock from "../components/AttentionBlock.vue";
import StorageBlock from "../components/StorageBlock.vue";
import SchedulerBlock from "../components/SchedulerBlock.vue";
import ChangesBlock from "../components/ChangesBlock.vue";

const PRODUCT = { irisforhealth: "IRIS for Health", iris: "IRIS", healthconnect: "HealthConnect" };
const instance = computed(() => {
  const i = info.value?.instance ?? {};
  const p = info.value?.portal ?? {};
  const build = (i.serverVersion?.match(/\(Build ([^)]+)\)/) ?? [])[1];
  return {
    name: `${PRODUCT[i.product] ?? i.product ?? ""} ${p.capabilities?.version ?? ""}`.trim(),
    detail: [build && `build ${build}`, p.instanceName && p.host && `${p.instanceName}@${p.host}`]
      .filter(Boolean)
      .join(" · "),
    full: i.serverVersion ?? "",
  };
});

const DOT = { ok: "bg-allow", slow: "bg-confirm", limited: "bg-confirm", down: "bg-deny", waiting: "bg-text-dim" };
const STATE = {
  0: ["border-allow text-allow", "OK"],
  1: ["border-confirm text-confirm", "warning"],
  2: ["border-deny text-deny", "alert"],
  "-1": ["border-deny text-deny", "hung"],
};
const state = computed(() => STATE[facts.state] ?? null);
const chip = "inline-flex h-[var(--size-btn)] shrink-0 items-center gap-2 rounded-control border px-3 text-small";
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <div class="flex min-w-0 flex-1 items-baseline gap-2.5 px-1" :title="instance.full">
      <span class="shrink-0 text-body font-medium text-text-bright">{{ instance.name }}</span>
      <span class="truncate font-mono text-micro text-text-muted">{{ instance.detail }}</span>
    </div>

    <span :class="chip" class="border-line" :title="t(`status.api.${apiState}`)">
      <span
        :key="polls"
        class="size-1.5 animate-poll rounded-badge"
        :class="DOT[apiState]"
        :style="{ animationDuration: `${FAST_MS}ms` }"
      />
      <span class="text-text-muted">/api/admin</span>
      <span class="font-mono text-text-bright">{{ latency }} ms</span>
    </span>
    <span v-if="facts.uptime" :class="chip" class="border-line text-text-muted">
      {{ t("dash.up") }}
      <span class="font-mono text-text-bright">{{ facts.uptime.replace(/^0d /, "") }}</span>
    </span>
    <span v-if="state" :class="[chip, state[0]]" :title="t('dash.state', { state: state[1], n: facts.state })">
      {{ state[1] }}
    </span>
  </div>

  <div class="grid min-h-0 flex-1 grid-cols-12 grid-rows-[auto_minmax(0,1.2fr)_minmax(0,1fr)] gap-panel">
    <HealthBlock class="col-span-12" />
    <ActivityBlock class="col-span-7" />
    <AttentionBlock class="col-span-5" />
    <StorageBlock class="col-span-4" />
    <SchedulerBlock class="col-span-4" />
    <ChangesBlock class="col-span-4" />
  </div>
</template>
