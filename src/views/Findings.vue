<script setup>
import { computed, ref, shallowRef } from "vue";
import { api } from "../composables/useApi";
import { t } from "../composables/useI18n";
import { useToolInvoke } from "../composables/useToolInvoke";
import { refreshShell } from "../composables/useShell";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import DecisionBadge from "../components/DecisionBadge.vue";
import DetailPanel from "../components/DetailPanel.vue";
import FilterField from "../components/FilterField.vue";
import FoldedCode from "../components/FoldedCode.vue";
import Icon from "../components/Icon.vue";
import RefreshButton from "../components/RefreshButton.vue";

const { invoke } = useToolInvoke();

const result = shallowRef(null);
const error = ref("");
const pending = ref(true);
const busy = ref("");
const filter = ref("");
const selected = ref(null);
const decisions = shallowRef({});

const rank = { high: 0, medium: 1, low: 2 };

async function load() {
  pending.value = true;
  error.value = "";
  try {
    const { data } = await invoke("insight.findings", {}, true);
    data.findings.sort((a, b) => rank[a.severity] - rank[b.severity]);
    data.findings.forEach((f, i) => (f.id = i));
    result.value = data;
    selected.value = data.findings[0] ?? null;
    askPolicy(data.findings);
  } catch (e) {
    error.value = e.message;
  } finally {
    pending.value = false;
  }
}
load();

async function askPolicy(findings) {
  const wanted = [...new Set(findings.filter((f) => f.fixTool).map((f) => f.fixTool))];
  const answers = await Promise.allSettled(wanted.map((t) => api("/policy/simulate", { tool: t, args: {} })));
  decisions.value = Object.fromEntries(
    answers.map((a, i) => [wanted[i], a.status === "fulfilled" ? a.value.data : null]).filter(([, v]) => v),
  );
}

async function fix(finding) {
  busy.value = finding.title;
  try {
    if (await invoke(finding.fixTool, finding.fixArgs)) {
      await load();
      refreshShell();
    }
  } catch {
  } finally {
    busy.value = "";
  }
}

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const all = result.value?.findings ?? [];
  return q ? all.filter((f) => `${f.title} ${f.evidence} ${f.probe} ${f.check}`.toLowerCase().includes(q)) : all;
});

const summary = computed(() => {
  const all = result.value?.findings ?? [];
  const n = (s) => all.filter((f) => f.severity === s).length;
  return {
    total: all.length,
    high: n("high"),
    medium: n("medium"),
    low: n("low"),
  };
});

const onMap = (f) =>
  ["web-apps", "privileged-users"].includes(f.check) ? (f.fixArgs?.name ?? f.fixArgs?.username ?? "") : "";

const broken = computed(() => (result.value?.checks ?? []).filter((c) => c.error));

const columns = computed(() => [
  {
    key: "severity",
    label: t("findings.col.severity"),
    width: "84px",
    sort: (f) => rank[f.severity],
  },
  {
    key: "check",
    label: t("findings.col.check"),
    mono: true,
    width: "120px",
    class: "text-text-muted",
  },
  {
    key: "title",
    label: t("findings.col.issue"),
    class: "max-w-[280px] truncate text-text-bright",
  },
  {
    key: "fix",
    label: t("findings.col.fix"),
    width: "118px",
    sort: (f) => decisions.value[f.fixTool]?.decision,
  },
]);

const tone = {
  high: "border-deny text-deny",
  medium: "border-confirm text-confirm",
  low: "border-line-strong text-text-muted",
};
const dot = { high: "bg-deny", medium: "bg-confirm", low: "bg-text-dim" };
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" :placeholder="t('findings.filter')" />
    <RefreshButton :busy="pending" :title="t('findings.rerun')" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      :title="t('findings.block')"
      :meta="t('findings.meta', summary)"
      :meta-title="t('findings.metaTitle')"
      class="flex-1"
    >
      <template v-if="broken.length" #actions>
        <span class="text-micro text-deny" :title="broken.map((c) => `${c.title}: ${c.error}`).join('\n')">
          {{ t("findings.checksFailed", { n: broken.length }) }}
        </span>
      </template>

      <p v-if="error" class="px-2.5 py-3 text-small text-deny">{{ error }}</p>
      <p v-else-if="pending && !result" class="px-2.5 py-3 text-small text-text-muted">
        {{ t("findings.running") }}
      </p>
      <div v-else-if="!summary.total" class="flex flex-1 flex-col items-center justify-center gap-2 p-6 text-center">
        <Icon name="policy" :size="34" class="text-allow" />
        <div class="text-display text-text-bright">
          {{ t("findings.clean") }}
        </div>
        <p class="max-w-[420px] text-small text-text-muted">
          {{ t("findings.cleanHint") }}
        </p>
      </div>

      <DataTable
        v-else
        :columns="columns"
        :rows="shown"
        row-key="id"
        sortable
        selectable
        :selected="selected?.id"
        :empty="t('audit.empty')"
        :empty-hint="t('findings.cleanHint')"
        @select="selected = $event"
      >
        <template #severity="{ row }">
          <span class="inline-flex items-center gap-1.5" :class="tone[row.severity].split(' ')[1]">
            <span class="size-[5px] rounded-badge" :class="dot[row.severity]" />{{ t(`severity.${row.severity}`) }}
          </span>
        </template>
        <template #title="{ row }">
          <span :title="row.title">{{ row.title }}</span>
        </template>
        <template #fix="{ row }">
          <DecisionBadge v-if="row.fixTool && decisions[row.fixTool]" :decision="decisions[row.fixTool].decision" />
          <span v-else-if="!row.fixTool" class="text-text-muted">{{ t("findings.noFix") }}</span>
        </template>
      </DataTable>
    </Block>

    <DetailPanel v-if="selected" :title="t('findings.detail')" :subject="selected.check" @close="selected = null">
      <div class="border-b border-line px-2.5 py-[9px]">
        <span
          class="inline-flex h-5 items-center gap-1.5 rounded-badge border px-[7px] text-micro font-medium"
          :class="tone[selected.severity]"
        >
          <span class="size-[5px] rounded-badge bg-current" />{{ t(`severity.${selected.severity}`) }}
        </span>
        <h2 class="mt-1.5 text-small font-medium text-text-bright">
          {{ selected.title }}
        </h2>
        <p class="mt-1.5 text-micro text-text">{{ selected.evidence }}</p>
      </div>

      <div v-if="selected.probe" class="border-b border-line px-2.5 py-[9px]">
        <FoldedCode :label="t('findings.probe')" :text="selected.probe" />
      </div>

      <div v-if="selected.fixTool" class="border-b border-line px-2.5 py-[9px]">
        <div class="flex items-center gap-2">
          <button
            :disabled="busy === selected.title || decisions[selected.fixTool]?.decision === 'deny'"
            class="h-[var(--size-btn)] rounded-control bg-accent px-[11px] text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:cursor-not-allowed disabled:opacity-40"
            :title="
              decisions[selected.fixTool]?.decision === 'deny'
                ? t('findings.denied', {
                    rule: decisions[selected.fixTool].ruleId,
                  })
                : `${selected.fixTool} ${JSON.stringify(selected.fixArgs)}\n${t('findings.fixTitle')}`
            "
            @click="fix(selected)"
          >
            {{ busy === selected.title ? t("findings.fixing") : t("findings.fixIt") }}
          </button>
          <DecisionBadge
            v-if="decisions[selected.fixTool]"
            :decision="decisions[selected.fixTool].decision"
            :rule="decisions[selected.fixTool].ruleId"
          />
        </div>
      </div>
      <p v-else class="border-b border-line px-2.5 py-[9px] text-micro text-text-muted">
        {{ t("findings.noFixLong") }}
      </p>

      <RouterLink
        v-if="onMap(selected)"
        :to="`/reach?focus=${onMap(selected)}`"
        class="block px-2.5 py-[9px] text-micro text-text-muted underline"
      >
        {{ t("findings.onMap") }}
      </RouterLink>

      <RouterLink
        v-if="selected.audit"
        :to="`/audit?${selected.audit}`"
        class="block px-2.5 py-[9px] text-micro text-text-muted underline"
      >
        {{ t("findings.inJournal") }}
      </RouterLink>
    </DetailPanel>
  </div>
</template>
