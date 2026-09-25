<script setup>
import { computed, ref, watch } from "vue";
import FieldGrid from "./FieldGrid.vue";

const props = defineProps({
  runs: { type: Array, default: () => [] },
});

const latest = computed(() => props.runs[0] ?? null);

const tone = {
  Finished: "text-allow",
  Running: "text-info",
  Queued: "text-text-muted",
  Failed: "text-deny",
  Lost: "text-confirm",
};

const pre = ref(null);
watch(
  () => latest.value?.log,
  () => pre.value && (pre.value.scrollTop = pre.value.scrollHeight),
  { flush: "post" },
);
</script>

<template>
  <div v-if="latest" class="px-2.5 py-[9px]">
    <div class="mb-1.5 flex items-center gap-2">
      <span class="text-micro tracking-[0.04em] text-text-muted">LAST RUN</span>
      <span class="inline-flex items-center gap-1.5 text-micro" :class="tone[latest.state] ?? 'text-text'">
        <span class="size-[5px] rounded-badge bg-current" />{{ latest.state }}
      </span>
    </div>
    <FieldGrid
      :rows="[
        ['Command', latest.command],
        ['Namespace', latest.namespace],
        ['Ran as', latest.runAs || 'not started yet'],
        ['Took', latest.durationMs === '' ? '-' : `${latest.durationMs} ms`],
      ]"
      label-width="92px"
    />
    <p v-if="latest.error" class="mt-1.5 text-micro text-deny">{{ latest.error }}</p>
    <pre
      v-if="latest.log"
      ref="pre"
      class="mt-2 max-h-56 overflow-auto rounded-control border border-line bg-base p-2 text-micro whitespace-pre-wrap text-text-muted"
      >{{ latest.log.trim() }}</pre>

    <div v-if="runs.length > 1" class="mt-2">
      <div class="mb-1 text-micro text-text-muted">Earlier</div>
      <div
        v-for="j in runs.slice(1, 6)"
        :key="j.id"
        class="flex items-baseline gap-2 font-mono text-micro text-text-muted"
      >
        <span :class="tone[j.state] ?? 'text-text'">{{ j.state }}</span>
        <span class="truncate">{{ j.command }}</span>
        <span class="ml-auto shrink-0">{{ j.namespace }}</span>
      </div>
    </div>
  </div>
</template>
