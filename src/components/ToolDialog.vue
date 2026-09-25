<script setup>
import { ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import SchemaForm from "./SchemaForm.vue";

const props = defineProps({
  tool: { type: Object, default: null },
  preset: { type: Object, default: () => ({}) },
});
const emit = defineEmits(["close", "done"]);

const { invoke } = useToolInvoke();
const args = ref({});
const busy = ref(false);
const failed = ref("");

watch(
  () => props.tool,
  () => {
    args.value = { ...props.preset };
    failed.value = "";
  },
  { immediate: true },
);

const run = async () => {
  busy.value = true;
  failed.value = "";
  try {
    const res = await invoke(props.tool.name, args.value);
    if (res) emit("done", res);
    emit("close");
  } catch (e) {
    failed.value = e.detail?.schema?.map((s) => `${s.path} ${s.message}`).join("; ") ?? e.message;
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <div
    v-if="tool"
    role="dialog"
    aria-modal="true"
    class="fixed inset-0 z-40 flex items-start justify-center overflow-y-auto bg-base/70 p-3"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-xl rounded-card border border-line-strong bg-surface p-3 shadow-overlay">
      <h2 class="font-mono text-title text-text-bright">{{ tool.name }}</h2>
      <p class="mt-1 mb-3 text-small text-text-muted">{{ tool.title }}</p>

      <SchemaForm v-model="args" :schema="tool.schema" />

      <p v-if="failed" class="mt-2 text-small text-deny">{{ failed }}</p>

      <div class="mt-3 flex justify-end gap-2">
        <button
          class="rounded-control border border-line-strong h-[var(--size-btn)] px-3 text-small font-medium text-text transition-colors hover:bg-surface-raised"
          @click="emit('close')"
        >
          Cancel
        </button>
        <button
          :disabled="busy"
          class="rounded-control bg-accent h-[var(--size-btn)] px-3 text-small font-medium text-white shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-50"
          @click="run"
        >
          {{ busy ? "Running…" : "Run" }}
        </button>
      </div>
    </div>
  </div>
</template>
