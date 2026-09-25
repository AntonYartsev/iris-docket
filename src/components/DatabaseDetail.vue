<script setup>
import { computed, ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";

const props = defineProps({ database: { type: Object, required: true } });
const emit = defineEmits(["changed", "close"]);

const { invoke } = useToolInvoke();

const info = ref(null);
const error = ref("");
const mounted = computed(() => props.database.Status?.startsWith("Mounted"));

const load = async () => {
  error.value = "";
  info.value = null;
  try {
    const started = await invoke("databaseDir.info", { dir: props.database.Directory }, true);
    let task = { State: "Running" };
    // ponytail: 5 polls 200ms apart
    for (let i = 0; i < 5 && task.State !== "Finished"; i++) {
      await new Promise((r) => setTimeout(r, i && 200));
      task = (await invoke("async.get", { id: started.meta.asyncId }, true)).data;
    }
    if (task.State !== "Finished") throw new Error(`the instance is still running the request (${task.State})`);
    if (task.FailureReason) throw new Error(task.FailureReason);
    info.value = task.Result;
  } catch (e) {
    error.value = e.message;
  }
};
watch(() => props.database.Directory, load, { immediate: true });

const act = async (tool) => {
  if (await invoke(tool, { dir: props.database.Directory })) {
    emit("changed");
    await load();
  }
};

const facts = computed(() => [
  ["Resource", props.database.Resource],
  ["Status", props.database.Status],
  ["Size, MB", info.value?.Size],
  ["Available, MB", info.value?.AvailableSpace],
  ["Free on volume", info.value?.DiskFree],
  ["Block size", info.value?.BlockSize],
  ["Blocks", info.value?.Blocks?.toLocaleString()],
  ["Max size", props.database.MaxSize],
  ["Expansion size", info.value?.ExpansionSize],
  ["Last expanded", info.value?.LastExpansionTime],
  ["Encrypted", props.database.Encrypted ? "yes" : "no"],
  ["Mirrored", props.database.Mirrored ? "yes" : "no"],
  ["Read-only because", info.value?.ReadOnlyReason],
]);
</script>

<template>
  <DetailPanel title="DATABASE" :subject="database.Directory" @close="emit('close')">
    <div class="border-b border-line px-2.5 py-[9px]">
      <p v-if="error" class="mb-1.5 text-micro text-deny">{{ error }}</p>
      <FieldGrid :rows="facts" />
    </div>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">OPERATIONS</div>
      <button
        class="h-[var(--size-btn)] rounded-control border px-[11px] text-small transition-colors"
        :class="
          mounted ? 'border-deny text-deny hover:bg-deny-soft' : 'border-line-strong text-text hover:bg-surface-raised'
        "
        @click="act(mounted ? 'databaseDir.dismount' : 'databaseDir.mount')"
      >
        {{ mounted ? "Dismount" : "Mount" }}
      </button>
    </div>

    <p class="px-2.5 py-[9px] text-micro text-text-muted">
      Everything below Status arrives as a background task:
      <code class="text-text">POST /v2/database-dir/info</code> answers 202 with a task id, not a result. The portal
      polls it here because it finishes in milliseconds; the Audit screen has the panel for the ones that do not.
    </p>
  </DetailPanel>
</template>
