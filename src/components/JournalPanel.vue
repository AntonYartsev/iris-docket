<script setup>
import { computed, ref, shallowRef } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "./Block.vue";
import FieldGrid from "./FieldGrid.vue";

const { invoke } = useToolInvoke();

const files = shallowRef([]);
const settings = shallowRef([]);
const error = ref("");

async function load() {
  try {
    const [list, cfg] = await Promise.all([invoke("journal.files", {}, true), invoke("journal.settings", {}, true)]);
    files.value = list.data;
    settings.value = Object.entries(cfg.data).map(([k, v]) => [k, v === "" ? null : String(v)]);
  } catch (e) {
    error.value = e.message;
  }
}
load();

const mb = (bytes) => (bytes / 1024 / 1024).toFixed(1);
const total = computed(() => files.value.reduce((n, f) => n + f.Size, 0));
</script>

<template>
  <Block
    title="JOURNAL"
    :meta="`${files.length} files · ${mb(total)} MB`"
    meta-title="GET /api/admin/v2/journal/files and /v2/journal/settings: the transaction journal, not the portal's own."
    class="w-[300px] shrink-0"
    :scroll="false"
  >
    <template #actions>
      <button
        class="h-[22px] rounded-control border border-line-strong px-2 text-micro text-text transition-colors hover:bg-surface-raised"
        title="Closes the running file and starts a new one. It does not delete anything, but it is a write, so it is confirmed and journalled."
        @click="invoke('journal.switchFile', {}).then((r) => r && load())"
      >
        Switch file
      </button>
    </template>

    <p v-if="error" class="px-2.5 py-[9px] text-micro text-deny">{{ error }}</p>

    <template v-else>
      <div class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">FILES</div>
        <div v-for="f in files" :key="f.Name" class="flex min-w-0 items-baseline gap-2 py-px text-micro">
          <span class="min-w-0 flex-1 truncate font-mono text-text" :title="f.Name">{{ f.Name }}</span>
          <span class="shrink-0 font-mono text-text-muted">{{ mb(f.Size) }} MB</span>
        </div>
        <p v-if="!files.length" class="text-micro text-text-muted">This instance reports no journal files.</p>
      </div>

      <div class="px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">SETTINGS</div>
        <FieldGrid :rows="settings" label-width="150px" />
      </div>
    </template>
  </Block>
</template>
