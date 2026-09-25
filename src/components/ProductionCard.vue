<script setup>
import { computed } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "./Block.vue";
import FieldGrid from "./FieldGrid.vue";

const props = defineProps({
  namespace: { type: String, required: true },
  running: { type: String, default: "" },
  state: { type: String, default: "" },
  productions: { type: Array, default: () => [] },
});
const emit = defineEmits(["changed"]);

const { invoke } = useToolInvoke();

const current = computed(() => props.productions.find((p) => p.name === props.running) ?? props.productions[0] ?? null);
const live = computed(() => props.state === "Running");

const tone = {
  Running: "text-allow",
  Stopped: "text-text-muted",
  Suspended: "text-confirm",
  Troubled: "text-deny",
};

async function power(tool) {
  const res = await invoke(tool, {
    namespace: props.namespace,
    production: current.value?.name ?? "",
  });
  if (res) emit("changed");
}
</script>

<template>
  <Block
    title="PRODUCTION"
    :meta="namespace"
    meta-title="Ens.Director.GetProductionStatus in the production's own namespace. Starting and stopping are ordinary writes: same confirmation, same journal row as granting a role."
    class="w-[320px] shrink-0"
    :scroll="false"
  >
    <template #actions>
      <span class="inline-flex items-center gap-1.5 text-micro" :class="tone[state] ?? 'text-text-muted'">
        <span class="size-[5px] rounded-badge bg-current" />{{ state || "unknown" }}
      </span>
    </template>

    <div class="px-2.5 py-[9px]">
      <div class="truncate font-mono text-small text-text-bright" :title="current?.name">
        {{ current?.name ?? "no production" }}
      </div>

      <div class="mt-1.5">
        <FieldGrid
          :rows="[
            ['Last started', current?.startedAt],
            ['Last stopped', current?.stoppedAt],
            [
              'Also deployed',
              productions
                .filter((p) => p.name !== current?.name)
                .map((p) => p.name)
                .join(', '),
            ],
          ]"
          label-width="98px"
        />
      </div>

      <p v-if="!current" class="mt-1.5 text-micro text-text-muted">Nothing has ever run in {{ namespace }}.</p>

      <button
        v-else
        class="mt-2 h-[var(--size-btn)] rounded-control border px-[11px] text-small transition-colors"
        :class="
          live ? 'border-deny text-deny hover:bg-deny-soft' : 'border-line-strong text-text hover:bg-surface-raised'
        "
        @click="power(live ? 'ens.production.stop' : 'ens.production.start')"
      >
        {{ live ? "Stop" : "Start" }}
      </button>
    </div>
  </Block>
</template>
