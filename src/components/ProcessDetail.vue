<script setup>
import { computed, ref, watch } from "vue";
import { api } from "../composables/useApi";
import { useToolInvoke } from "../composables/useToolInvoke";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";

const props = defineProps({ pid: { type: Number, required: true } });
const emit = defineEmits(["changed", "close"]);

const { invoke } = useToolInvoke();

const detail = ref(null);
const error = ref("");
const journal = ref([]);

async function load() {
  error.value = "";
  detail.value = null;
  try {
    detail.value = (await invoke("process.get", { id: props.pid }, true)).data;
  } catch (e) {
    error.value = e.message;
  }
  journal.value = await api(`/audit?q=${props.pid}&limit=6`)
    .then((r) => r.data)
    .catch(() => []);
}
watch(() => props.pid, load, { immediate: true });

const act = async (tool) => {
  if (await invoke(tool, { id: props.pid })) {
    emit("changed");
    await load();
  }
};

const suspended = computed(() => detail.value?.State === "SUSP");

const facts = computed(() => [
  ["State", detail.value?.State],
  ["Namespace", detail.value?.NameSpace],
  ["Routine", detail.value?.CurrentLineAndRoutine || detail.value?.Routine],
  ["OS user", detail.value?.UserName || detail.value?.OSUserName],
  ["Roles", detail.value?.Roles?.join(", ")],
  ["Client IP", detail.value?.ClientIPAddress || detail.value?.ClientNodeName],
  ["Device", detail.value?.CurrentDevice],
  ["Commands", detail.value?.CommandsExecuted?.toLocaleString()],
  ["Global refs", detail.value?.GlobalReferences?.toLocaleString()],
  ["CPU time, ms", detail.value?.CPUTime?.toLocaleString()],
  ["Memory, KB", detail.value?.MemoryUsed?.toLocaleString()],
  ["Started", detail.value?.StartTimeUTC],
  ["Parent PID", detail.value?.ParentPid],
  ["In transaction", detail.value && (detail.value.InTransaction ? "yes" : "no")],
]);

const tone = { allow: "bg-allow", confirm: "bg-confirm", deny: "bg-deny" };
</script>

<template>
  <DetailPanel title="PROCESS" :subject="String(pid)" @close="emit('close')">
    <div class="border-b border-line px-2.5 py-[9px]">
      <p v-if="error" class="text-micro text-deny">{{ error }}</p>
      <FieldGrid v-else :rows="facts" />
    </div>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">OPERATIONS</div>
      <div class="flex flex-wrap gap-1.5">
        <button
          :disabled="!detail?.CanBeSuspended"
          :title="
            detail?.CanBeSuspended
              ? 'Asks a human first: the policy rule write-ask.'
              : 'The instance reports this process as not suspendable: it is one of its own.'
          "
          class="h-[var(--size-btn)] rounded-control bg-accent px-[11px] text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:cursor-not-allowed disabled:opacity-40"
          @click="act(suspended ? 'process.resume' : 'process.suspend')"
        >
          {{ suspended ? "Resume" : "Suspend" }}
        </button>
        <button
          :disabled="!suspended"
          :title="
            suspended
              ? 'Puts it back in the queue.'
              : `This process is ${detail?.State ?? '-'}. process.resume applies only to a suspended process.`
          "
          class="h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised disabled:cursor-not-allowed disabled:opacity-40"
          @click="act('process.resume')"
        >
          Resume
        </button>
        <button
          :disabled="!detail?.CanBeTerminated"
          title="Terminating a process is confirmed like any other write, and refused outright for the process serving this request."
          class="h-[var(--size-btn)] rounded-control border border-deny px-[11px] text-small text-deny transition-colors hover:bg-deny-soft disabled:cursor-not-allowed disabled:opacity-40"
          @click="act('process.terminate')"
        >
          Terminate
        </button>
      </div>
      <p class="mt-[7px] text-micro text-text-muted">
        The portal refuses <code class="text-text">process.terminate</code> and
        <code class="text-text">process.suspend</code> on the process serving your request: it would kill the reply
        before the operation reached the journal.
      </p>
    </div>

    <div class="px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">THIS PROCESS IN THE JOURNAL</div>
      <RouterLink
        v-for="j in journal"
        :key="j.seq"
        :to="`/audit?q=${pid}`"
        class="flex min-w-0 items-center gap-[7px] py-[3px] text-micro no-underline"
      >
        <span class="size-[5px] shrink-0 rounded-badge" :class="tone[j.decision] ?? 'bg-text-dim'" />
        <span class="shrink-0 font-mono text-text-muted">#{{ j.seq }}</span>
        <span class="min-w-0 flex-1 truncate font-mono text-text">{{ j.tool }}</span>
        <span class="shrink-0 text-text-muted">{{ j.ts?.slice(11, 16) }}</span>
      </RouterLink>
      <p v-if="!journal.length" class="text-micro text-text-muted">Nothing yet.</p>

      <p class="mt-2 border-t border-line pt-2 text-micro text-text-muted">
        <code class="text-text">process.get</code> also returns this process's local variables. They are not shown:
        whatever is passing through a process is passing through those, and a read-only screen is no reason to put a
        password on a monitor.
      </p>
    </div>
  </DetailPanel>
</template>
