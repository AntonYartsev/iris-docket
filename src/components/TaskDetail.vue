<script setup>
import { computed, ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";

const props = defineProps({
  task: { type: Object, required: true },
});
const emit = defineEmits(["changed", "close"]);

const { invoke } = useToolInvoke();

const detail = ref(null);
const history = ref([]);
const error = ref("");

const load = async () => {
  error.value = "";
  detail.value = null;
  history.value = [];
  try {
    const [d, h] = await Promise.all([
      invoke("task.get", { id: props.task.Id }, true),
      invoke("task.history", { taskId: props.task.Id, maxRows: 20 }, true),
    ]);
    detail.value = d.data;
    history.value = h.data;
  } catch (e) {
    error.value = e.message;
  }
};
watch(() => props.task.Id, load, { immediate: true });

const act = async (tool, args) => {
  if (await invoke(tool, { id: props.task.Id, ...args })) {
    emit("changed");
    await load();
  }
};

const schedule = computed(() => [
  ["Runs", detail.value && [detail.value.TimePeriod, detail.value.DailyFrequency].filter(Boolean).join(", ")],
  ["Daily from", detail.value?.DailyStartTime],
  ["Starting", detail.value?.StartDate],
  ["Next", props.task.NextScheduled],
  ["Last finished", props.task.LastFinished],
  ["Class", detail.value?.TaskClass],
  ["Runs as", detail.value?.RunAsUser],
  ["Namespace", props.task.Namespace],
  ["Priority", detail.value?.Priority],
  ["Suspend on error", detail.value && (detail.value.SuspendOnError ? "yes" : "no")],
]);
</script>

<template>
  <DetailPanel title="TASK" :subject="task.Name" @close="emit('close')">
    <div class="border-b border-line px-2.5 py-[9px]">
      <p class="mb-1.5 text-micro text-text-muted">
        {{ task.Description || "No description." }}
      </p>
      <p v-if="error" class="mb-1.5 text-micro text-deny">{{ error }}</p>
      <FieldGrid :rows="schedule" label-width="116px" />
    </div>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">OPERATIONS</div>
      <div class="flex flex-wrap gap-1.5">
        <button
          class="h-[var(--size-btn)] rounded-control bg-accent px-[11px] text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover"
          @click="act('task.run', { RunNow: true })"
        >
          Run now
        </button>
        <button
          :disabled="task.suspended"
          :title="
            task.suspended ? 'This task is already suspended.' : 'Takes it out of the schedule; the definition stays.'
          "
          class="h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised disabled:cursor-not-allowed disabled:opacity-40"
          @click="act('task.suspend', { LeaveInQueue: true })"
        >
          Suspend
        </button>
        <button
          :disabled="!task.suspended"
          :title="
            task.suspended
              ? 'Puts it back in the schedule.'
              : 'This task is already scheduled; resume applies only to a suspended one.'
          "
          class="h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised disabled:cursor-not-allowed disabled:opacity-40"
          @click="act('task.resume', {})"
        >
          Resume
        </button>
      </div>
      <p v-if="task.suspended" class="mt-[7px] text-micro text-confirm">
        Suspended{{ task.mode ? `: ${task.mode}` : "" }}. The SysAdmin API's own task list reports this task as
        scheduled; the flag comes from <code class="text-text">%SYS.Task</code>.
      </p>
    </div>

    <div class="px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">LAST RUNS</div>
      <div v-for="h in history" :key="h.LogDatetime" class="flex min-w-0 items-baseline gap-2 py-px text-micro">
        <span class="size-[5px] shrink-0 rounded-badge" :class="h.Result === 'Success' ? 'bg-allow' : 'bg-deny'" />
        <span class="shrink-0 font-mono text-text-muted">{{ h.LastStart?.slice(5, 16) }}</span>
        <span class="min-w-0 flex-1 truncate" :class="h.Result === 'Success' ? 'text-text' : 'text-deny'">
          {{ h.Result }}<span v-if="h.ErrNumber" class="font-mono"> #{{ h.ErrNumber }}</span>
        </span>
        <span class="shrink-0 text-text-muted">{{ h.Username }}</span>
      </div>
      <p v-if="!history.length" class="text-micro text-text-muted">This task has not run yet.</p>
    </div>
  </DetailPanel>
</template>
