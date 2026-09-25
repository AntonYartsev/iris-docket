<script setup>
import { computed, inject, onUnmounted, ref, shallowRef } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import { stored } from "../composables/useStored";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import TabBar from "../components/TabBar.vue";
import FilterField from "../components/FilterField.vue";
import RefreshButton from "../components/RefreshButton.vue";
import ProcessDetail from "../components/ProcessDetail.vue";
import DatabaseDetail from "../components/DatabaseDetail.vue";

const { invoke } = useToolInvoke();
const scope = inject("scope", ref(""));

const MAX = 1000;

const TABS = {
  processes: {
    label: "Processes",
    tool: "process.list",
    title: "PROCESSES",
    key: "Pid",
  },
  devices: {
    label: "Devices",
    tool: "device.list",
    title: "DEVICES",
    key: "Name",
  },
  databases: {
    label: "Databases",
    tool: "databaseDir.list",
    title: "DATABASES",
    key: "Directory",
  },
  counters: {
    label: "Counters",
    tool: "monitor.systemUsage",
    title: "SYSTEM USAGE",
    key: "name",
  },
};

const columns = {
  processes: [
    { key: "Pid", label: "PID", mono: true, class: "text-text-bright" },
    { key: "Username", label: "User", sort: (r) => r.Username || r.OSUserName },
    { key: "Nspace", label: "Namespace", mono: true, class: "text-text-muted" },
    {
      key: "Routine",
      label: "Routine",
      mono: true,
      class: "max-w-[180px] truncate",
    },
    { key: "State", label: "State" },
    { key: "cpuNow", label: "CPU now", mono: true, right: true },
    { key: "gps", label: "Globals/s", mono: true, right: true, class: "text-text-muted" },
    {
      key: "CPUTime",
      label: "CPU ms",
      mono: true,
      right: true,
      class: "text-text-muted",
    },
    // Globals, not GlobalReferences here
    {
      key: "Globals",
      label: "Global refs",
      mono: true,
      right: true,
      class: "text-text-muted",
    },
    {
      key: "ElapsedTime",
      label: "Elapsed",
      mono: true,
      right: true,
      class: "text-text-muted",
      sort: (r) => seconds(r.ElapsedTime),
    },
  ],
  devices: [
    { key: "Name", label: "Device", mono: true, class: "text-text-bright" },
    {
      key: "PhysicalDevice",
      label: "Physical",
      mono: true,
      class: "max-w-[220px] truncate text-text-muted",
    },
    { key: "Type", label: "Type" },
    { key: "SubType", label: "Subtype", class: "text-text-muted" },
    {
      key: "Description",
      label: "Description",
      class: "max-w-[320px] truncate text-text-muted",
    },
  ],
  databases: [
    {
      key: "Directory",
      label: "Directory",
      mono: true,
      class: "max-w-[280px] truncate text-text-bright",
    },
    {
      key: "Resource",
      label: "Resource",
      mono: true,
      class: "text-text-muted",
    },
    { key: "Status", label: "Status" },
    { key: "Size", label: "Size MB", mono: true, right: true },
    {
      key: "free",
      label: "Free MB",
      mono: true,
      right: true,
      class: "text-text-muted",
    },
    { key: "Encrypted", label: "Encrypted" },
  ],
  counters: [
    { key: "name", label: "Counter", class: "text-text" },
    {
      key: "value",
      label: "Value",
      mono: true,
      right: true,
      class: "text-text-bright",
    },
  ],
};

const tab = stored("system.tab", "processes", Object.keys(TABS));
const filter = ref("");
const live = stored("system.live", true);
const who = ref("");
const phase = ref("");
const rows = shallowRef({
  processes: [],
  devices: [],
  databases: [],
  counters: [],
});
const truncated = ref({});
const selected = ref(null);
const state = ref("loading");
const error = ref("");

const FREE = "iris_db_size_mb,iris_db_free_space";

// totals since start, so diff
const previous = new Map();

function sample(list) {
  const t = Date.now();
  const out = list.map((p) => {
    const a = previous.get(p.Pid);
    previous.set(p.Pid, { t, cpu: p.CPUTime, globals: p.Globals });
    // pid reused, counters reset
    if (!a || p.CPUTime < a.cpu) return { ...p, cpuNow: null, gps: null };
    const ms = t - a.t;
    return { ...p, cpuNow: ((p.CPUTime - a.cpu) / ms) * 100, gps: Math.round(((p.Globals - a.globals) / ms) * 1000) };
  });
  const alive = new Set(list.map((p) => p.Pid));
  for (const pid of previous.keys()) if (!alive.has(pid)) previous.delete(pid);
  return out;
}

function seconds(elapsed) {
  const parts = (elapsed ?? "").match(/\d+/g)?.map(Number).reverse() ?? [];
  return [1, 60, 3600, 86400].reduce((sum, unit, i) => sum + (parts[i] ?? 0) * unit, 0);
}

const READ = {
  async processes() {
    const r = await invoke("process.list", { maxRows: MAX }, true);
    return [sample(r.data), r.meta.truncated];
  },
  async devices() {
    const r = await invoke("device.list", { names: "*", maxRows: MAX }, true);
    return [r.data, r.meta.truncated];
  },
  async databases() {
    const [dbs, met] = await Promise.all([
      invoke("databaseDir.list", { maxRows: MAX }, true),
      invoke("monitor.metrics", { names: FREE }, true),
    ]);
    const samples = (n) => met.data.find((m) => m.name === n)?.samples ?? [];
    const nameByDir = Object.fromEntries(samples("iris_db_size_mb").map((s) => [s.labels.dir, s.labels.id]));
    const freeByName = Object.fromEntries(samples("iris_db_free_space").map((s) => [s.labels.id, s.value]));
    return [dbs.data.map((d) => ({ ...d, free: freeByName[nameByDir[d.Directory]] })), dbs.meta.truncated];
  },
  async counters() {
    const r = await invoke("monitor.systemUsage", {}, true);
    return [Object.entries(r.data).map(([name, value]) => ({ name, value })), false];
  },
};

function failed(e) {
  error.value = e.message;
  state.value = e.code === "policy_denied" ? "denied" : "error";
}

async function load() {
  state.value = "loading";
  try {
    const keys = Object.keys(READ);
    const got = await Promise.all(keys.map((k) => READ[k]()));
    rows.value = Object.fromEntries(keys.map((k, i) => [k, got[i][0]]));
    truncated.value = Object.fromEntries(keys.map((k, i) => [k, got[i][1]]));
    state.value = "ready";
  } catch (e) {
    failed(e);
  }
}
load();

async function tick() {
  if (!live.value || state.value === "loading" || document.hidden) return;
  const key = tab.value;
  try {
    const [list, cut] = await READ[key]();
    rows.value = { ...rows.value, [key]: list };
    truncated.value = { ...truncated.value, [key]: cut };
  } catch (e) {
    failed(e);
  }
}
const timer = setInterval(tick, 10_000);
onUnmounted(() => clearInterval(timer));

const system = (p) => !p.Username;
const states = computed(() => [...new Set(rows.value.processes.map((p) => p.State))].sort());

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  let list = rows.value[tab.value] ?? [];
  if (scope.value && tab.value === "processes") list = list.filter((r) => r.Nspace === scope.value);
  if (tab.value === "processes" && who.value) list = list.filter((r) => system(r) === (who.value === "system"));
  if (tab.value === "processes" && phase.value) list = list.filter((r) => r.State === phase.value);
  return q ? list.filter((r) => JSON.stringify(r).toLowerCase().includes(q)) : list;
});

const tabs = computed(() =>
  Object.entries(TABS).map(([key, t]) => ({
    key,
    label: t.label,
    count: (rows.value[key] ?? []).length,
  })),
);

const suspended = computed(() => rows.value.processes.filter((p) => p.State === "SUSP").length);

const PANEL_HAS = ["Nspace", "CPUTime", "Globals", "ElapsedTime"];
const shownColumns = computed(() =>
  tab.value === "processes" && selected.value?.kind === "process"
    ? columns.processes.filter((c) => !PANEL_HAS.includes(c.key))
    : columns[tab.value],
);

const meta = computed(() => `${shown.value.length} of ${(rows.value[tab.value] ?? []).length}`);

const STATE_TONE = {
  RUN: "text-accent",
  RUNW: "text-accent",
  SUSP: "text-deny",
};

function pick(row) {
  if (tab.value === "processes") selected.value = { kind: "process", id: row.Pid };
  else if (tab.value === "databases") selected.value = { kind: "database", id: row.Directory, row };
}
</script>

<template>
  <div class="flex min-w-0 shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" />
    <TabBar v-model="tab" :tabs="tabs" />
    <button
      class="inline-flex h-[var(--size-btn)] w-[92px] shrink-0 items-center justify-center gap-1.5 rounded-control border border-line-strong px-3 text-small transition-colors"
      :class="live ? 'bg-surface-raised text-text' : 'text-text-muted hover:bg-surface-raised'"
      :title="
        live
          ? `Reading ${TABS[tab].label.toLowerCase()} every 10 seconds, whichever tab is open. Click to stop.`
          : 'Not reading on its own. Click to read the open tab every 10 seconds.'
      "
      @click="live = !live"
    >
      <span class="size-1.5 rounded-badge" :class="live ? 'bg-allow' : 'bg-text-dim'" />
      {{ live ? "live" : "paused" }}
    </button>
    <RefreshButton
      :busy="state === 'loading'"
      title="Read the processes, devices, databases and counters again"
      @click="load"
    />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      :title="TABS[tab].title"
      :meta="meta"
      :meta-title="`Rows come from ${TABS[tab].tool}. The privilege is the one the registry declares for it; the observed requirement can be higher.`"
      class="flex-1"
    >
      <template #actions>
        <span v-if="tab === 'processes' && suspended" class="inline-flex items-center gap-1.5 text-micro text-deny">
          <span class="size-[5px] rounded-badge bg-current" />{{ suspended }}
          SUSP
        </span>
        <template v-if="tab === 'processes'">
          <select
            v-model="who"
            class="h-[22px] rounded-control border border-line-strong bg-surface px-1.5 text-micro text-text"
          >
            <option value="">all processes</option>
            <option value="user">user processes</option>
            <option value="system">system daemons</option>
          </select>
          <select
            v-model="phase"
            class="h-[22px] rounded-control border border-line-strong bg-surface px-1.5 text-micro text-text"
          >
            <option value="">any state</option>
            <option v-for="st in states" :key="st" :value="st">{{ st }}</option>
          </select>
        </template>
      </template>

      <DataTable
        :columns="shownColumns"
        :rows="shown"
        :row-key="TABS[tab].key"
        :selected="selected?.id"
        :selectable="tab === 'processes' || tab === 'databases'"
        sortable
        :state="state"
        :error="error"
        :tool="TABS[tab].tool"
        :truncated="!!truncated[tab]"
        :empty="filter ? 'Nothing matches the filter' : 'The instance reports none'"
        :empty-hint="
          filter
            ? `Nothing in ${shown.length ? '' : 'these rows '}matches “${filter}”.`
            : `${TABS[tab].tool} answered with an empty list. That is a real answer, not a failure.`
        "
        @select="pick"
        @retry="load"
      >
        <template #State="{ row }">
          <span class="inline-flex items-center gap-1.5 font-mono" :class="STATE_TONE[row.State] ?? 'text-text-muted'">
            <span class="size-[5px] rounded-badge bg-current" />{{ row.State }}
          </span>
        </template>
        <template #Username="{ row }">{{ row.Username || row.OSUserName || "-" }}</template>
        <template #Nspace="{ row }">{{ row.Nspace || "-" }}</template>
        <template #CPUTime="{ row }">{{ row.CPUTime?.toLocaleString() ?? "-" }}</template>
        <template #Globals="{ row }">{{ row.Globals?.toLocaleString() ?? "-" }}</template>
        <template #cpuNow="{ row }">
          <span v-if="row.cpuNow === null" class="text-text-dim" title="A rate needs two reads - the next one is due">
            -
          </span>
          <span v-else :class="row.cpuNow >= 1 ? 'text-text-bright' : 'text-text-muted'">
            {{ row.cpuNow.toFixed(1) }}%
          </span>
        </template>
        <template #gps="{ row }">{{ row.gps?.toLocaleString() ?? "-" }}</template>
        <template #free="{ row }">{{ row.free?.toLocaleString() ?? "-" }}</template>
        <template #Encrypted="{ row }">
          <span class="text-text-muted">{{ row.Encrypted ? "yes" : "no" }}</span>
        </template>
        <template #value="{ row }">{{ row.value?.toLocaleString?.() ?? row.value }}</template>
      </DataTable>
    </Block>

    <ProcessDetail
      v-if="tab === 'processes' && selected?.kind === 'process'"
      :key="selected.id"
      :pid="selected.id"
      @changed="load"
      @close="selected = null"
    />
    <DatabaseDetail
      v-else-if="tab === 'databases' && selected?.kind === 'database'"
      :key="selected.id"
      :database="selected.row"
      @changed="load"
      @close="selected = null"
    />
  </div>
</template>
