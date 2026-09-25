<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { api } from "../composables/useApi";
import { t } from "../composables/useI18n";
import { tools } from "../composables/useShell";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import DecisionBadge from "../components/DecisionBadge.vue";
import DetailPanel from "../components/DetailPanel.vue";
import FieldGrid from "../components/FieldGrid.vue";
import FilterField from "../components/FilterField.vue";
import PolicySimulator from "../components/PolicySimulator.vue";
import ToolDialog from "../components/ToolDialog.vue";
import VersionBadge from "../components/VersionBadge.vue";

const route = useRoute();
const filter = ref("");
const selected = ref(null);
const dialogTool = ref(null);
const decisions = shallowRef({});
const simulating = ref(route.query.simulate === "1");

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const all = tools.value ?? [];
  return q ? all.filter((x) => `${x.name} ${x.title} ${x.path} ${x.category}`.toLowerCase().includes(q)) : all;
});

watch(
  [() => route.query.run, tools],
  ([name]) => {
    const tool = (tools.value ?? []).find((x) => x.name === name);
    if (!tool) return;
    selected.value = tool;
    if (tool.available !== false) dialogTool.value = tool;
  },
  { immediate: true },
);

watch(
  shown,
  async (rows) => {
    const wanted = rows.filter((r) => !(r.name in decisions.value)).slice(0, 24);
    if (!wanted.length) return;
    const answers = await Promise.allSettled(wanted.map((r) => api("/policy/simulate", { tool: r.name, args: {} })));
    const next = { ...decisions.value };
    answers.forEach((a, i) => (next[wanted[i].name] = a.status === "fulfilled" ? a.value.data : null));
    decisions.value = next;
  },
  { immediate: true },
);

const columns = [
  { key: "name", label: "Tool", mono: true, class: "text-text-bright" },
  {
    key: "title",
    label: "Title",
    class: "max-w-[340px] truncate text-text-muted",
  },
  { key: "category", label: "Category", class: "text-text-muted" },
  {
    key: "path",
    label: "Endpoint",
    mono: true,
    class: "max-w-[240px] truncate text-text-muted",
  },
  {
    key: "privilege",
    label: "Requires at least",
    mono: true,
    class: "text-text-muted",
  },
  { key: "mutating", label: "Writes" },
  { key: "decision", label: "Policy now" },
];

const facts = (tool) => [
  ["Category", tool.category],
  ["Writes", tool.mutating ? "yes" : "no"],
  ["Source", tool.source],
  ["Method", tool.method],
  ["Path", tool.path],
  ["Privilege", tool.privilege],
  ["Class", tool.class],
];
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" :placeholder="t('tools.filter')" />
    <button
      class="h-[var(--size-btn)] shrink-0 rounded-control border border-line-strong px-3 text-small text-text transition-colors hover:bg-surface-raised"
      :class="simulating && 'bg-surface-raised text-text-bright'"
      :title="t('sim.metaTitle')"
      @click="simulating = !simulating"
    >
      {{ t("tools.simulator") }}
    </button>
    <a
      href="/portal/api/openapi.json"
      target="_blank"
      rel="noreferrer"
      class="flex h-[var(--size-btn)] shrink-0 items-center rounded-control border border-line-strong px-3 text-small text-text no-underline transition-colors hover:bg-surface-raised"
      title="The same registry as an OpenAPI document, generated from it, not written beside it"
    >
      openapi.json
    </a>
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      title="REGISTRY"
      :meta="`${shown.length} of ${(tools ?? []).length}`"
      meta-title="Built by walking the subclasses of App.Tools.Base. The UI, the agent console and scripted callers all go through these and through nothing else."
      class="flex-1"
    >
      <DataTable
        :columns="columns"
        :rows="shown"
        row-key="name"
        selectable
        :selected="selected?.name"
        :state="(tools ?? []).length ? 'ready' : 'loading'"
        tool="/portal/api/tools"
        empty="Nothing matches"
        @select="selected = $event"
      >
        <template #name="{ row }">
          <span class="inline-flex items-center gap-1.5">
            <span :class="row.available === false && 'text-text-muted'">{{ row.name }}</span>
            <VersionBadge :tool="row" />
          </span>
        </template>
        <template #title="{ row }">
          <span :title="row.title">{{ row.title }}</span>
        </template>
        <template #path="{ row }">
          <span :title="`${row.method} ${row.path}`">{{ row.method }} {{ row.path }}</span>
        </template>
        <template #privilege="{ row }">{{ row.privilege || "-" }}</template>
        <template #mutating="{ row }">
          <span v-if="row.mutating" class="inline-flex items-center gap-1.5 text-confirm">
            <span class="size-[5px] rounded-badge bg-current" />writes
          </span>
          <span v-else class="text-text-muted">read</span>
        </template>
        <template #decision="{ row }">
          <DecisionBadge
            v-if="decisions[row.name]"
            :decision="decisions[row.name].decision"
            :rule="decisions[row.name].ruleId"
          />
        </template>
      </DataTable>
    </Block>

    <PolicySimulator v-if="simulating" :tools="tools ?? []" />

    <DetailPanel v-else-if="selected" title="TOOL" :subject="selected.name" @close="selected = null">
      <div class="border-b border-line px-2.5 py-[9px]">
        <p class="mb-1.5 text-micro text-text">{{ selected.title }}</p>
        <FieldGrid :rows="facts(selected)" label-width="80px" />
      </div>

      <div class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">THE POLICY, RIGHT NOW</div>
        <DecisionBadge
          v-if="decisions[selected.name]"
          :decision="decisions[selected.name].decision"
          :rule="decisions[selected.name].ruleId"
        />
        <p class="mt-1.5 text-micro text-text-muted">
          Asked of the same engine that decides the real call, with empty arguments. A rule that matches on an argument
          can still answer differently once one is filled in.
        </p>
        <button
          v-if="selected.available !== false"
          class="mt-2 h-[var(--size-btn)] rounded-control bg-accent px-[11px] text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover"
          @click="dialogTool = selected"
        >
          Run it
        </button>
        <RouterLink v-else to="/version" class="mt-2 block text-micro text-text-muted no-underline hover:text-text">
          {{ selected.unavailable?.reason }}, so it would answer 501, and the journal would carry the attempt. What this
          build does serve →
        </RouterLink>
      </div>

      <div class="px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">ARGUMENT SCHEMA</div>
        <pre
          class="overflow-x-auto rounded-control border border-line bg-base p-2 text-micro whitespace-pre-wrap text-text-muted"
          >{{ JSON.stringify(selected.schema, null, 2) }}</pre>
      </div>
    </DetailPanel>
  </div>

  <ToolDialog :tool="dialogTool" @close="dialogTool = null" />
</template>
