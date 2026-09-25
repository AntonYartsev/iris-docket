<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { api } from "../composables/useApi";
import { alertsLog, badges, counted, facts, findings, refreshShell } from "../composables/useShell";
import { useToolInvoke } from "../composables/useToolInvoke";
import { t } from "../composables/useI18n";
import Block from "./Block.vue";

const { invoke } = useToolInvoke();
const RANK = { high: 0, medium: 1, low: 2 };
const DOT = { high: "bg-deny", medium: "bg-confirm", low: "bg-text-dim" };

const sorted = computed(() => [...findings.value].sort((a, b) => RANK[a.severity] - RANK[b.severity]));
const top = computed(() => sorted.value.slice(0, 4));
const count = (s) => findings.value.filter((f) => f.severity === s).length;
const checks = computed(() => {
  const n = {};
  for (const f of findings.value) n[f.check] = (n[f.check] ?? 0) + 1;
  return Object.entries(n)
    .sort((a, b) => b[1] - a[1])
    .map(([c, k]) => `${c.replace(/-/g, " ")} ${k}`)
    .join(" · ");
});

const decisions = shallowRef({});
watch(
  top,
  async (rows) => {
    const fixable = rows.filter((f) => f.fixTool);
    const asked = await Promise.allSettled(
      fixable.map((f) => api("/policy/simulate", { tool: f.fixTool, args: f.fixArgs ?? {} })),
    );
    decisions.value = Object.fromEntries(
      asked.map((a, i) => [fixable[i].title, a.status === "fulfilled" ? a.value.data : null]),
    );
  },
  { immediate: true },
);

const busy = ref("");
async function fix(f) {
  busy.value = f.title;
  try {
    // null = declined, not error
    if (await invoke(f.fixTool, f.fixArgs)) refreshShell();
  } catch {
  } finally {
    busy.value = "";
  }
}

const cells = computed(() => {
  const subs = facts.subsystems ? Object.values(facts.subsystems) : [];
  const normal = subs.filter((v) => v === "Normal").length;
  const backup = facts.lastBackup;
  return [
    {
      to: "/tasks",
      k: t("attention.backup"),
      title: backup,
      v: backup === "Never" ? t("attention.never") : backup.slice(0, 10) || "-",
      warn: backup === "Never",
    },
    {
      to: "/tasks",
      k: t("attention.suspended"),
      v: counted.value ? t("attention.tasks", { n: badges.tasks }) : "-",
      warn: badges.tasks > 0,
    },
    {
      to: "/logs",
      k: t("attention.logs"),
      v: alertsLog.value || !counted.value ? "-" : badges.logs,
      bad: badges.logs > 0,
      title: alertsLog.value,
    },
    {
      to: "/interop",
      k: t("attention.interop"),
      v: counted.value ? t("attention.errors", { n: badges.interop }) : "-",
      bad: badges.interop > 0,
    },
    {
      to: "/system",
      k: t("attention.subsystems"),
      v: subs.length ? `${normal}/${subs.length} ok` : "-",
      dot: subs.length ? (normal === subs.length ? "bg-allow" : "bg-deny") : "",
      bad: normal < subs.length,
    },
  ];
});
</script>

<template>
  <Block :title="t('attention.block')" :scroll="false">
    <template #actions>
      <RouterLink to="/findings" class="text-micro text-text-muted no-underline hover:text-text"
        >{{ t("attention.all") }} →</RouterLink
      >
    </template>

    <div class="flex min-h-0 flex-1 flex-col gap-2.5 overflow-y-auto px-3 py-2.5">
      <div class="flex items-center gap-3">
        <span class="text-display leading-none text-text-bright tabular-nums">{{
          counted ? findings.length : "-"
        }}</span>
        <div class="min-w-0 flex-1">
          <div class="flex h-2.5 gap-0.5 overflow-hidden rounded-badge bg-surface-raised">
            <i class="bg-deny" :style="{ flex: count('high') }" />
            <i class="bg-confirm" :style="{ flex: count('medium') }" />
            <i class="bg-text-dim" :style="{ flex: count('low') }" />
          </div>
          <div class="mt-1 flex gap-3 text-micro whitespace-nowrap">
            <span class="text-deny">{{ t("attention.high", { n: count("high") }) }}</span>
            <span class="text-confirm">{{ t("attention.medium", { n: count("medium") }) }}</span>
            <span class="text-text-muted">{{ t("attention.low", { n: count("low") }) }}</span>
            <span class="ml-auto truncate text-text-muted" :title="checks">{{ checks }}</span>
          </div>
        </div>
      </div>

      <div v-if="counted && !findings.length" class="text-small text-allow">{{ t("attention.clean") }}</div>
      <div>
        <div
          v-for="f in top"
          :key="f.title"
          class="grid h-[30px] grid-cols-[5px_minmax(0,1fr)_auto] items-center gap-2 border-b border-line last:border-b-0"
        >
          <span class="size-[5px] rounded-badge" :class="DOT[f.severity]" />
          <RouterLink
            to="/findings"
            class="truncate text-small text-text no-underline hover:text-text-bright"
            :title="f.evidence"
          >
            {{ f.title }}
          </RouterLink>
          <button
            v-if="f.fixTool"
            class="inline-flex h-[22px] items-center rounded-tight border border-line-strong px-2 text-micro text-text transition-colors hover:bg-surface-raised disabled:opacity-50"
            :disabled="busy === f.title || decisions[f.title]?.decision === 'deny'"
            :title="
              t('attention.fixTitle', {
                call: `${f.fixTool} ${JSON.stringify(f.fixArgs)}`,
                decision: decisions[f.title]?.decision ?? '-',
                rule: decisions[f.title]?.ruleId ?? '-',
              })
            "
            @click="fix(f)"
          >
            {{
              busy === f.title
                ? t("findings.fixing")
                : f.check === "failing-tasks"
                  ? t("attention.runAgain")
                  : t("findings.fixIt")
            }}
          </button>
          <span v-else class="text-micro text-text-muted">{{ t("findings.noFix") }}</span>
        </div>
      </div>

      <div class="mt-auto grid grid-cols-5 gap-1.5">
        <RouterLink
          v-for="c in cells"
          :key="c.k"
          :to="c.to"
          :title="c.title"
          class="min-w-0 rounded-control border border-line bg-inset px-2 py-1.5 no-underline transition-colors hover:border-line-strong"
        >
          <div class="truncate text-[11.5px] text-text-muted">{{ c.k }}</div>
          <div
            class="flex items-center gap-1.5 truncate font-mono text-small"
            :class="c.bad ? 'text-deny' : c.warn ? 'text-confirm' : 'text-text-bright'"
          >
            <span v-if="c.dot" class="size-[5px] shrink-0 rounded-badge" :class="c.dot" />{{ c.v }}
          </div>
        </RouterLink>
      </div>
    </div>
  </Block>
</template>
