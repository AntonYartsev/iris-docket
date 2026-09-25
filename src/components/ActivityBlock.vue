<script setup>
import { computed, shallowRef, watch } from "vue";
import { api } from "../composables/useApi";
import { events, policy, poll } from "../composables/useShell";
import { t } from "../composables/useI18n";
import Block from "./Block.vue";

const stats = shallowRef(null);
const chain = shallowRef(null);

watch(
  events,
  async () => {
    const [s, c] = await Promise.allSettled([poll("audit.stats"), api("/audit/verify")]);
    if (s.status === "fulfilled") stats.value = s.value.data;
    chain.value = c.status === "fulfilled" ? c.value.data : { error: c.reason?.message };
  },
  { immediate: true },
);

const total = computed(() => stats.value?.total ?? {});
const kpis = computed(() => [
  { n: total.value.calls, label: t("activity.calls"), tone: "text-text-bright" },
  { n: total.value.changes, label: t("activity.changes"), tone: "text-text-bright" },
  { n: total.value.asked, label: t("activity.asked"), tone: "text-confirm" },
  { n: total.value.refused, label: t("activity.refused"), tone: "text-deny" },
  {
    n: total.value.failed,
    label: total.value.calls
      ? t("activity.failedPct", { pct: Math.round((total.value.failed / total.value.calls) * 100) })
      : t("activity.failed"),
    tone: "text-deny",
  },
  {
    n: stats.value?.latency.p95,
    label: t("activity.p95"),
    title: t("activity.p95Title", { p50: stats.value?.latency.p50 ?? "-" }),
    tone: "text-text-bright",
    unit: " ms",
  },
]);

const peak = computed(() => Math.max(1, ...(stats.value?.hours ?? []).map((h) => h.calls)));
const marks = (h) => [
  ...Array(h.refused).fill("bg-deny"),
  ...Array(h.asked).fill("bg-confirm"),
  ...Array(Math.max(0, h.changes - h.asked)).fill("bg-accent"),
];

const WHO = { user: "activity.people", agent: "activity.agent", script: "activity.scripts" };
const who = computed(() => {
  const w = stats.value?.who ?? {};
  return ["user", "agent", "script"].map((k) => ({ key: k, label: t(WHO[k]), n: w[k] ?? 0 }));
});
const SEG = { user: "bg-accent", agent: "bg-allow", script: "bg-confirm" };

const pill = computed(() =>
  !chain.value
    ? ["border-line-strong text-text-muted", t("activity.chain.walking"), ""]
    : chain.value.ok
      ? [
          "border-allow text-allow",
          t("activity.chain.ok"),
          t("activity.chain.okTitle", { n: chain.value.entries.toLocaleString() }),
        ]
      : chain.value.error
        ? ["border-confirm text-confirm", t("activity.chain.unknown"), chain.value.error]
        : ["border-deny text-deny", t("activity.chain.broken", { n: chain.value.brokenAt }), chain.value.reason],
);
const fmt = (n) =>
  n === undefined || n === null || n === "" ? "-" : n >= 10_000 ? `${(n / 1000).toFixed(1)}k` : n.toLocaleString();
</script>

<template>
  <Block :title="t('activity.block')" :scroll="false">
    <template #actions>
      <RouterLink v-if="policy" to="/policy" class="text-micro text-text-muted no-underline hover:text-text">
        {{ t("activity.policy") }} <span class="font-mono text-text-bright">v{{ policy.config?.version }}</span>
      </RouterLink>
      <RouterLink
        to="/audit"
        class="inline-flex h-5 items-center rounded-badge border px-[7px] text-micro font-medium no-underline"
        :class="pill[0]"
        :title="pill[2]"
      >
        {{ pill[1] }}
      </RouterLink>
    </template>

    <div class="grid min-h-0 flex-1 grid-cols-[minmax(0,1fr)_240px]">
      <div class="flex min-h-0 min-w-0 flex-col px-3 py-2.5">
        <div class="grid grid-cols-6 gap-2">
          <div v-for="k in kpis" :key="k.label" class="min-w-0">
            <div
              :key="k.n"
              class="animate-number text-lead whitespace-nowrap tabular-nums min-[1400px]:text-title"
              :class="k.n ? k.tone : 'text-text-muted'"
            >
              {{ fmt(k.n) }}<span v-if="k.unit && k.n" class="text-small text-text-muted">{{ k.unit }}</span>
            </div>
            <div class="truncate text-micro text-text-muted" :title="k.title || k.label">{{ k.label }}</div>
          </div>
        </div>

        <div class="relative mt-2 flex min-h-[56px] flex-1 items-end gap-[3px] border-b border-line pt-4">
          <span class="absolute top-0 right-0 font-mono text-[10.5px] text-text-dim">
            {{ t("activity.perHour", { n: peak.toLocaleString() }) }}
          </span>
          <div
            v-for="h in stats?.hours ?? []"
            :key="h.hour"
            class="flex h-full min-w-0 flex-1 flex-col items-center justify-end gap-[3px]"
            :title="t('activity.hourTitle', { ...h })"
          >
            <span
              v-for="(m, i) in marks(h).slice(0, 4)"
              :key="i"
              class="size-[5px] shrink-0 rounded-badge"
              :class="m"
            />
            <span v-if="marks(h).length > 4" class="font-mono text-[10px] leading-none text-text-muted"
              >+{{ marks(h).length - 4 }}</span
            >
            <div
              class="flex w-full flex-col justify-end overflow-hidden rounded-t-[2px]"
              :style="{ height: `${(h.calls / peak) * 100}%` }"
            >
              <div class="w-full flex-1 bg-accent/45" />
              <div
                v-if="h.failed"
                class="w-full shrink-0 bg-deny"
                :style="{ height: `${Math.max(2, (h.failed / h.calls) * 100)}%` }"
              />
            </div>
          </div>
        </div>
        <div class="flex gap-[3px] font-mono text-[10.5px] text-text-dim">
          <span v-for="(h, i) in stats?.hours ?? []" :key="h.hour" class="flex-1 text-center">
            {{ i % 3 ? "" : String(h.hour).padStart(2, "0") }}
          </span>
        </div>

        <div class="mt-1 flex items-center gap-3.5 text-micro whitespace-nowrap text-text-muted">
          <span class="inline-flex items-center gap-1.5"
            ><i class="size-2 rounded-[2px] bg-accent/45" />{{ t("activity.legend.calls") }}</span
          >
          <span class="inline-flex items-center gap-1.5"
            ><i class="size-[5px] rounded-badge bg-accent" />{{ t("activity.legend.change") }}</span
          >
          <span class="inline-flex items-center gap-1.5"
            ><i class="size-[5px] rounded-badge bg-confirm" />{{ t("activity.legend.asked") }}</span
          >
          <span class="inline-flex items-center gap-1.5"
            ><i class="size-[5px] rounded-badge bg-deny" />{{ t("activity.legend.bad") }}</span
          >
        </div>
      </div>

      <div class="flex min-h-0 flex-col gap-3 overflow-y-auto border-l border-line px-3 py-2.5">
        <div>
          <div class="flex h-2 gap-0.5 overflow-hidden rounded-badge bg-surface-raised">
            <i v-for="w in who" :key="w.key" :class="SEG[w.key]" :style="{ flex: w.n }" />
          </div>
          <div v-for="w in who" :key="w.key" class="mt-1 flex justify-between text-micro">
            <span class="inline-flex items-center gap-1.5 text-text-muted"
              ><i class="size-[5px] rounded-badge" :class="SEG[w.key]" />{{ w.label }}</span
            >
            <span class="font-mono" :class="w.n ? 'text-text' : 'text-text-muted'">{{ w.n.toLocaleString() }}</span>
          </div>
        </div>
        <div class="min-w-0">
          <div class="text-micro tracking-[0.04em] text-text-muted">{{ t("activity.failing") }}</div>
          <RouterLink
            v-for="f in stats?.failing ?? []"
            :key="f.tool"
            :to="`/audit?q=${encodeURIComponent(f.tool)}`"
            class="mt-1 flex justify-between gap-2 text-micro no-underline"
            :title="f.error"
          >
            <span class="truncate font-mono text-text">{{ f.tool }}</span>
            <span class="font-mono text-deny">{{ f.n }}</span>
          </RouterLink>
          <p v-if="!stats?.failing.length" class="mt-1 text-micro text-text-muted">{{ t("activity.noFailures") }}</p>
        </div>
      </div>
    </div>
  </Block>
</template>
