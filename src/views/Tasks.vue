<script setup>
import { computed, ref, shallowRef } from "vue";
import { useRoute } from "vue-router";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import FilterField from "../components/FilterField.vue";
import RefreshButton from "../components/RefreshButton.vue";
import TaskDetail from "../components/TaskDetail.vue";

const { invoke } = useToolInvoke();

const tasks = shallowRef([]);
const selected = ref(null);
const filter = ref("");
const ns = ref("");
const { query } = useRoute();
const status = ref(["suspended", "failed"].includes(query.state) ? query.state : "");
const busy = ref(false);
const state = ref("loading");
const error = ref("");
const truncated = ref(false);

async function load() {
  busy.value = true;
  try {
    const [list, states, history] = await Promise.all([
      invoke("task.list", { maxRows: 1000 }, true),
      invoke("task.states", {}, true),
      invoke("task.history", { maxRows: 1000 }, true).catch(() => ({ data: [] })),
    ]);
    const flags = Object.fromEntries(states.data.map((s) => [s.id, s]));
    const last = {};
    for (const r of history.data) last[r.TaskId] ??= !(String(r.Status) === "1" && !+r.ErrNumber);
    tasks.value = list.data.map((t) => ({
      ...t,
      suspended: !!flags[t.Id]?.suspended,
      mode: flags[t.Id]?.mode,
      failed: !!last[t.Id],
    }));
    truncated.value = !!list.meta.truncated;
    if (selected.value) selected.value = tasks.value.find((t) => t.Id === selected.value.Id) ?? null;
    state.value = "ready";
  } catch (e) {
    error.value = e.message;
    state.value = e.code === "policy_denied" ? "denied" : "error";
  } finally {
    busy.value = false;
  }
}
load();

const suspended = computed(() => tasks.value.filter((t) => t.suspended).length);

const namespaces = computed(() => [...new Set(tasks.value.map((t) => t.Namespace))].sort());

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  return tasks.value.filter(
    (t) =>
      (!ns.value || t.Namespace === ns.value) &&
      (!status.value ||
        (status.value === "failed" ? t.failed && !t.suspended : t.suspended === (status.value === "suspended"))) &&
      (!q || JSON.stringify(t).toLowerCase().includes(q)),
  );
});

const columns = [
  {
    key: "Name",
    label: "Task",
    class: "max-w-[280px] truncate text-text-bright",
  },
  {
    key: "Namespace",
    label: "Namespace",
    mono: true,
    class: "text-text-muted",
  },
  { key: "Type", label: "Type", class: "text-text-muted" },
  {
    key: "NextScheduled",
    label: "Next run",
    mono: true,
    class: "text-text-muted",
  },
  {
    key: "LastFinished",
    label: "Last finished",
    mono: true,
    class: "text-text-muted",
  },
  { key: "suspended", label: "State" },
];
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" placeholder="Filter tasks" />
    <select
      v-model="ns"
      class="h-[var(--size-field)] shrink-0 rounded-control border border-line-strong bg-surface px-2 text-small text-text"
    >
      <option value="">any namespace</option>
      <option v-for="n in namespaces" :key="n" :value="n">{{ n }}</option>
    </select>
    <select
      v-model="status"
      class="h-[var(--size-field)] shrink-0 rounded-control border border-line-strong bg-surface px-2 text-small text-text"
    >
      <option value="">any state</option>
      <option value="scheduled">scheduled</option>
      <option value="suspended">suspended</option>
      <option value="failed">failed last run</option>
    </select>
    <RefreshButton :busy="busy" title="Read the schedule and the suspended flags again" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      title="TASKS"
      :meta="`${shown.length} of ${tasks.length}`"
      meta-title="GET /api/admin/v2/tasks for the schedule, %SYS.Task for the suspended flag. The API reports Suspended: false for every task, including ones it suspended itself."
      class="flex-1"
    >
      <template #actions>
        <span v-if="suspended" class="inline-flex items-center gap-1.5 text-micro text-confirm">
          <span class="size-[5px] rounded-badge bg-current" />{{ suspended }}
          suspended
        </span>
      </template>

      <DataTable
        :columns="columns"
        :rows="shown"
        row-key="Id"
        selectable
        :selected="selected?.Id"
        :state="state"
        :error="error"
        tool="task.list"
        :truncated="truncated"
        empty="No tasks match"
        @select="selected = $event"
        @retry="load"
      >
        <template #NextScheduled="{ row }">{{ row.NextScheduled || "-" }}</template>
        <template #LastFinished="{ row }">{{ row.LastFinished || "never" }}</template>
        <template #suspended="{ row }">
          <span
            class="inline-flex items-center gap-1.5"
            :class="row.suspended ? 'text-confirm' : row.failed ? 'text-deny' : 'text-text-muted'"
            :title="row.mode || (row.failed ? 'In the schedule; its last run failed.' : 'In the schedule.')"
          >
            <span class="size-[5px] rounded-badge bg-current" />{{
              row.suspended ? "suspended" : row.failed ? "failed last run" : "scheduled"
            }}
          </span>
        </template>
      </DataTable>
    </Block>

    <TaskDetail v-if="selected" :key="selected.Id" :task="selected" @changed="load" @close="selected = null" />
  </div>
</template>
