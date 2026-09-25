<script setup>
import { ref, shallowRef } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "./Block.vue";
import DataTable from "./DataTable.vue";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";

const emit = defineEmits(["find"]);

const { invoke } = useToolInvoke();

const tasks = shallowRef([]);
const detail = shallowRef(null);
const selected = ref(null);
const error = ref("");
const pending = ref(true);

const state = {
  Finished: "text-allow",
  Running: "text-info",
  Queued: "text-text-muted",
  Paused: "text-confirm",
  Cancelled: "text-text-muted",
  Failed: "text-deny",
};

const columns = [
  { key: "TaskName", label: "Task", mono: true, class: "text-micro" },
  { key: "State", label: "State" },
  {
    key: "TimeQueued",
    label: "Queued",
    mono: true,
    class: "text-micro text-text-muted",
  },
  {
    key: "TimeFinished",
    label: "Finished",
    mono: true,
    class: "text-micro text-text-muted",
  },
  {
    key: "GUID",
    label: "GUID",
    mono: true,
    class: "text-micro text-text-muted",
  },
];

async function load() {
  pending.value = true;
  try {
    tasks.value = (await invoke("async.list", { maxRows: 200 }, true)).data;
  } catch (e) {
    error.value = e.message;
  } finally {
    pending.value = false;
  }
}
load();

async function open(row) {
  selected.value = row.GUID;
  detail.value = null;
  detail.value = (await invoke("async.get", { id: row.GUID }, true)).data;
}

async function act(tool) {
  if (await invoke(tool, { id: selected.value })) {
    await load();
    await open({ GUID: selected.value });
  }
}

const lines = (console) => {
  if (Array.isArray(console)) return console;
  try {
    return JSON.parse(console ?? "[]");
  } catch {
    return [String(console)];
  }
};
</script>

<template>
  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      title="ASYNC TASKS"
      :meta="`${tasks.length}`"
      meta-title="GET /api/admin/v2/async-results: the instance shows each account only its own tasks."
      class="min-w-0 flex-1"
    >
      <template #actions>
        <button
          class="h-[22px] rounded-control border border-line-strong px-2 text-micro text-text transition-colors hover:bg-surface-raised"
          @click="load"
        >
          Reload
        </button>
      </template>

      <DataTable
        :columns="columns"
        :rows="tasks"
        row-key="GUID"
        selectable
        :selected="selected"
        :state="pending ? 'loading' : error ? 'error' : 'ready'"
        :error="error"
        tool="async.list"
        empty="No async task yet"
        empty-hint="A task started by somebody else answers 404 rather than an empty row: the instance shows each account only its own."
        @select="open"
        @retry="load"
      >
        <template #State="{ row }">
          <span class="inline-flex items-center gap-1.5" :class="state[row.State] ?? 'text-text'">
            <span class="size-[5px] rounded-badge bg-current" />{{ row.State }}
          </span>
        </template>
        <template #TimeFinished="{ row }">{{ row.TimeFinished || "-" }}</template>
      </DataTable>

      <template #footer>
        <span class="truncate">
          Some of these are plain reads that simply arrive out of band: the block count of a database, a page of the
          system audit. Their only link to our journal is the GUID.
        </span>
      </template>
    </Block>

    <DetailPanel v-if="detail" title="TASK" :subject="detail.TaskName" @close="((detail = null), (selected = null))">
      <div class="border-b border-line px-2.5 py-[9px]">
        <FieldGrid
          :rows="[
            ['GUID', selected],
            ['State', detail.State],
            ['Queued', detail.TimeQueued],
            ['Finished', detail.TimeFinished],
            ['Failed', detail.FailureReason],
          ]"
        />
      </div>

      <div v-if="lines(detail.Console).length" class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">CONSOLE</div>
        <pre
          class="max-h-40 overflow-auto rounded-control border border-line bg-base p-2 text-micro whitespace-pre-wrap text-text-muted"
          >{{ lines(detail.Console).join("\n") }}</pre>
      </div>

      <div class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">RESULT</div>
        <pre
          class="max-h-56 overflow-auto rounded-control border border-line bg-base p-2 text-micro whitespace-pre-wrap text-text-muted"
          >{{ JSON.stringify(detail.Result, null, 2) }}</pre>
      </div>

      <div class="px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">OPERATIONS</div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="a in [
              { tool: 'async.pause', label: 'Pause' },
              { tool: 'async.resume', label: 'Resume' },
              { tool: 'async.cancel', label: 'Cancel' },
            ]"
            :key="a.tool"
            class="h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised"
            @click="act(a.tool)"
          >
            {{ a.label }}
          </button>
        </div>
        <button
          class="mt-2 text-micro text-text-muted underline transition-colors hover:text-text"
          @click="emit('find', selected)"
        >
          find it in the journal
        </button>
      </div>
    </DetailPanel>
  </div>
</template>
