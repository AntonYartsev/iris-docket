<script setup>
import { computed, ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";
import PackageRuns from "./PackageRuns.vue";

const props = defineProps({
  name: { type: String, required: true },
  installed: { type: Array, default: () => [] },
  registry: { type: Object, default: null },
  registryOut: { type: Boolean, default: false },
  namespaces: { type: Array, default: () => [] },
  jobs: { type: Array, default: () => [] },
});
const emit = defineEmits(["close", "started"]);

const { invoke } = useToolInvoke();

const published = computed(() =>
  props.registry
    ? [
        ["Latest", props.registry.version],
        ["Repository", props.registry.repository || "-", props.registry.repository],
      ]
    : [],
);

const about = computed(() =>
  (props.registry?.description || props.installed[0]?.description || "").replace(/\s+/g, " ").trim(),
);

const ns = ref("");
watch(
  () => props.name,
  () => (ns.value = props.installed[0]?.namespace ?? props.namespaces[0] ?? "USER"),
  { immediate: true },
);

const version = ref("");
const mine = computed(() => props.installed.find((m) => m.namespace === ns.value));

async function act(tool, args = {}) {
  if (await invoke(tool, { name: props.name, namespace: ns.value, ...args })) emit("started");
}

const runs = computed(() => props.jobs.filter((j) => j.package === props.name));
const btn =
  "h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised disabled:cursor-not-allowed disabled:opacity-40";
const primary =
  "h-[var(--size-btn)] rounded-control bg-accent px-[11px] text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover";
</script>

<template>
  <DetailPanel title="PACKAGE" :subject="name" @close="$emit('close')">
    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">REGISTRY</div>
      <FieldGrid v-if="registry" :rows="published" label-width="92px" />
      <p v-else-if="registryOut" class="text-micro text-text-muted">
        The community registry did not answer, so nothing is known here about newer versions. What is below was read on
        this instance and is unaffected.
      </p>
      <p v-else class="text-micro text-text-muted">
        The community registry does not publish a package under this name.
      </p>
      <p v-if="about" class="mt-1.5 text-micro text-text-muted">{{ about }}</p>
    </div>

    <div v-for="m in installed" :key="m.namespace + m.root" class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 flex items-center gap-2">
        <span class="text-micro tracking-[0.04em] text-text-muted">INSTALLED IN</span>
        <span class="font-mono text-micro text-text-bright">{{ m.namespace }}</span>
      </div>
      <FieldGrid
        :rows="[
          ['Version', m.version],
          ['Installed', m.installedAt || 'not recorded'],
          ['Loaded from', m.root || '-', m.root],
        ]"
        label-width="92px"
      />

      <div v-if="m.dependencies.length" class="mt-2">
        <div class="mb-1 text-micro text-text-muted">{{ m.dependencies.length }} dependencies</div>
        <div class="flex flex-wrap gap-1">
          <span
            v-for="d in m.dependencies"
            :key="d.name"
            class="rounded-badge border border-line px-1.5 py-px font-mono text-micro text-text-muted"
          >
            {{ d.name }} <span class="text-text">{{ d.version }}</span>
          </span>
        </div>
      </div>
      <div v-else class="mt-1.5 text-micro text-text-muted">No dependencies declared.</div>
    </div>

    <p v-if="!installed.length" class="border-b border-line px-2.5 py-[9px] text-micro text-text-muted">
      Not installed on this instance. The registry above is what could be installed under this name.
    </p>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">OPERATIONS</div>
      <label class="mb-1.5 block">
        <span class="mb-1 block text-micro text-text-muted">Namespace</span>
        <select
          v-model="ns"
          class="h-[var(--size-field)] w-full rounded-control border border-line-strong bg-base px-2 font-mono text-small text-text"
        >
          <option v-for="n in namespaces" :key="n" :value="n">{{ n }}</option>
        </select>
      </label>
      <label class="mb-2 block">
        <span class="mb-1 flex items-baseline gap-2 text-micro text-text-muted">
          Version <span class="truncate">empty = the latest the registry has</span>
        </span>
        <input
          v-model="version"
          placeholder="1.0.3"
          class="h-[var(--size-field)] w-full rounded-control border border-line-strong bg-base px-2 font-mono text-small text-text"
        />
      </label>

      <div class="flex flex-wrap gap-1.5">
        <button
          v-if="!mine"
          :class="primary"
          title="Runs the package manager's install in the chosen namespace. The policy asks first, and the journal keeps the name and the version."
          @click="act('packages.install', version ? { version } : {})"
        >
          Install
        </button>
        <button
          v-if="mine"
          :class="mine.behind ? primary : btn"
          :title="
            mine.behind
              ? `Installed ${mine.version}, the registry publishes ${registry?.version}.`
              : 'Runs the module’s own update steps. Nothing newer is published, so this will most likely find nothing to do.'
          "
          @click="act('packages.upgrade', version ? { version } : {})"
        >
          Upgrade
        </button>
        <button
          v-if="mine"
          :class="btn"
          title="Removes it from this namespace. IPM refuses by itself if another installed module depends on it."
          @click="act('packages.uninstall')"
        >
          Uninstall
        </button>
      </div>
      <p class="mt-2 text-micro text-text-muted">
        All three go through the same gate as everything else here: schema, policy, a human click, one journal row. The
        agent console is refused all three outright.
      </p>
    </div>

    <PackageRuns :runs="runs" />
  </DetailPanel>
</template>
