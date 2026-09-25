<script setup>
import { ref, computed, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";

const props = defineProps({ name: { type: String, required: true } });

const { invoke } = useToolInvoke();

const spec = ref(null);
const error = ref("");
const filter = ref("");
const probe = ref(null);

watch(
  () => props.name,
  async () => {
    spec.value = null;
    error.value = "";
    probe.value = null;
    try {
      spec.value = (await invoke("rest.spec", { name: props.name }, true)).data;
    } catch (e) {
      error.value = e.message;
    }
  },
  { immediate: true },
);

const operations = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const all = spec.value?.operations ?? [];
  return q ? all.filter((o) => (o.path + " " + o.method + " " + (o.summary ?? "")).toLowerCase().includes(q)) : all;
});

const verb = {
  GET: "text-allow bg-allow-soft",
  HEAD: "text-allow bg-allow-soft",
  OPTIONS: "text-allow bg-allow-soft",
  POST: "text-confirm bg-confirm-soft",
  PUT: "text-confirm bg-confirm-soft",
  PATCH: "text-confirm bg-confirm-soft",
  DELETE: "text-deny bg-deny-soft",
};

// safe methods only, see Probe
const canProbe = (op) => ["GET", "HEAD", "OPTIONS"].includes(op.method) && !op.path.includes("{");

const run = async (op) => {
  const key = op.method + " " + op.path;
  probe.value = { key, pending: true };
  try {
    const res = await invoke("rest.probe", { name: props.name, path: op.path, method: op.method }, true);
    probe.value = { key, ...res.data };
  } catch (e) {
    probe.value = { key, failed: e.message };
  }
};
</script>

<template>
  <p v-if="error" class="text-small text-text-muted">{{ error }}</p>
  <p v-else-if="!spec" class="text-small text-text-muted">Reading the specification…</p>

  <template v-else>
    <div class="flex flex-wrap items-baseline gap-2">
      <h3 class="text-small font-semibold text-text-bright">
        {{ spec.title || "(the document carries no title)" }}
      </h3>
      <span class="font-mono text-micro text-text-muted">{{ spec.dialect }}</span>
      <span
        v-if="spec.specKind === 'synthesized'"
        class="rounded-badge bg-confirm-soft px-2 py-0.5 text-micro font-medium text-confirm"
        title="No RESTSpec behind this application: the document is generated from its XData UrlMap, so descriptions and response codes are placeholders."
      >
        synthesized from UrlMap
      </span>
      <span v-else class="rounded-badge bg-allow-soft px-2 py-0.5 text-micro font-medium text-allow">spec-first</span>
    </div>
    <p v-if="spec.description" class="mt-1 text-small text-text-muted">
      {{ spec.description }}
    </p>

    <input
      v-model="filter"
      class="mt-2 w-full rounded-control border border-line-strong bg-base h-[var(--size-field)] px-2 text-small text-text placeholder:text-text-muted"
      :placeholder="`Filter ${spec.operations.length} operations`"
    />

    <ul class="mt-2 grid gap-1">
      <li
        v-for="op in operations"
        :key="op.method + op.path"
        class="rounded-control border border-line px-cell-x py-cell-y"
      >
        <div class="flex items-baseline gap-2">
          <span class="rounded-badge px-2 py-0.5 font-mono text-micro font-medium" :class="verb[op.method]">{{
            op.method
          }}</span>
          <span class="min-w-0 flex-1 break-all font-mono text-small text-text">{{ op.path }}</span>
          <button
            v-if="canProbe(op)"
            class="shrink-0 rounded-control border border-line-strong h-6 px-2.5 text-micro text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
            @click="run(op)"
          >
            Try it
          </button>
        </div>
        <p v-if="op.summary || op.description" class="mt-1 text-micro text-text-muted">
          {{ op.summary || op.description }}
        </p>
        <p v-if="op.parameters.length" class="mt-1 font-mono text-micro text-text-muted">
          <span v-for="p in op.parameters" :key="p.name" class="mr-3">
            {{ p.name }}<span class="text-text-muted">:{{ p.in }}{{ p.required ? "!" : "" }}</span>
          </span>
        </p>
        <p class="mt-1 font-mono text-micro text-text-muted">
          <span v-for="r in op.responses" :key="r.code" class="mr-2" :title="r.description">{{ r.code }}</span>
        </p>

        <div
          v-if="probe && probe.key === op.method + ' ' + op.path"
          class="mt-cell-y rounded-control border border-line bg-base px-cell-x py-cell-y"
        >
          <p v-if="probe.pending" class="text-micro text-text-muted">Calling…</p>
          <p v-else-if="probe.failed" class="text-micro text-deny">
            {{ probe.failed }}
          </p>
          <template v-else>
            <p class="font-mono text-micro" :class="probe.status < 400 ? 'text-allow' : 'text-deny'">
              {{ probe.status }} · {{ probe.durationMs }} ms ·
              {{ probe.contentType }}
            </p>
            <pre class="mt-1 max-h-48 overflow-auto text-micro whitespace-pre-wrap text-text-muted">{{
              probe.body
            }}</pre>
            <p v-if="probe.truncated" class="text-micro text-text-muted">…response cut at 4000 characters.</p>
          </template>
        </div>
      </li>
    </ul>
  </template>
</template>
