<script setup>
import { computed, inject, ref, shallowRef, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import { stored } from "../composables/useStored";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import FilterField from "../components/FilterField.vue";
import ProductionCard from "../components/ProductionCard.vue";
import RefreshButton from "../components/RefreshButton.vue";
import TabBar from "../components/TabBar.vue";

const { invoke } = useToolInvoke();
const scope = inject("scope", ref(""));

const spaces = shallowRef([]);
const ns = stored("interop.ns", "");
const items = shallowRef([]);
const messages = shallowRef([]);
const events = shallowRef([]);
const tab = stored("interop.tab", "messages", ["messages", "events"]);
const session = ref(null);
const problemsOnly = stored("interop.problemsOnly", false);
const filter = ref("");
const busy = ref(false);
const itemsV = ref(["loading", ""]);
const messagesV = ref(["loading", ""]);
const eventsV = ref(["loading", ""]);
const verdict = (r) => (r ? [r.code === "policy_denied" ? "denied" : "error", r.message] : ["ready", ""]);
const logV = computed(() => (tab.value === "messages" ? messagesV.value : eventsV.value));

const readable = computed(() => spaces.value.filter((s) => !s.error));
const here = computed(() => readable.value.find((s) => s.namespace === ns.value) ?? null);

async function load() {
  busy.value = true;
  try {
    spaces.value = (await invoke("ens.productions", {}, true)).data;
    if (!here.value) {
      ns.value =
        (readable.value.find((s) => s.running) ?? readable.value.find((s) => s.productions.length) ?? readable.value[0])
          ?.namespace ?? "";
    }
    await feed();
  } catch (e) {
    itemsV.value = messagesV.value = eventsV.value = verdict(e);
  } finally {
    busy.value = false;
  }
}

async function feed() {
  if (!ns.value) return;
  const args = {
    namespace: ns.value,
    ...(session.value ? { sessionId: session.value } : {}),
  };
  itemsV.value = messagesV.value = eventsV.value = ["loading", ""];
  const [i, m, e] = await Promise.allSettled([
    invoke("ens.production.items", { namespace: ns.value }, true),
    invoke("ens.messages", { ...args, maxRows: 500 }, true),
    invoke("ens.events", { ...args, maxRows: 500, problemsOnly: problemsOnly.value }, true),
  ]);
  items.value = i.value?.data ?? [];
  messages.value = m.value?.data ?? [];
  events.value = e.value?.data ?? [];
  itemsV.value = verdict(i.reason);
  messagesV.value = verdict(m.reason);
  eventsV.value = verdict(e.reason);
}

load();
watch([ns, session, problemsOnly], feed);

watch(scope, (v) => v && readable.value.some((s) => s.namespace === v) && ((ns.value = v), (session.value = null)));

const failed = (row) => row.error || row.status === "Error";
const errorItems = computed(() => items.value.filter((i) => i.errors > 0));

const rows = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const all = tab.value === "messages" ? messages.value : events.value;
  return q ? all.filter((r) => JSON.stringify(r).toLowerCase().includes(q)) : all;
});

const tabs = computed(() => [
  { key: "messages", label: "Messages", count: messages.value.length },
  { key: "events", label: "Events", count: events.value.length },
]);

const itemColumns = [
  { key: "name", label: "Item", class: "max-w-[220px] truncate" },
  { key: "type", label: "Kind", class: "text-text-muted" },
  {
    key: "class",
    label: "Class",
    mono: true,
    class: "max-w-[220px] truncate text-text-muted",
  },
  {
    key: "sent",
    label: "Sent",
    right: true,
    mono: true,
    class: "text-text-muted",
  },
  {
    key: "received",
    label: "Received",
    right: true,
    mono: true,
    class: "text-text-muted",
  },
  { key: "errors", label: "Errors", right: true, mono: true },
];

const messageColumns = [
  { key: "ts", label: "Time", mono: true, class: "text-text-muted" },
  { key: "session", label: "Session", mono: true, class: "text-text-muted" },
  { key: "source", label: "From", class: "max-w-[160px] truncate" },
  { key: "target", label: "To", class: "max-w-[160px] truncate" },
  {
    key: "body",
    label: "Body",
    mono: true,
    class: "max-w-[220px] truncate text-text-muted",
  },
  { key: "status", label: "Status" },
];

const eventColumns = [
  { key: "ts", label: "Time", mono: true, class: "text-text-muted" },
  { key: "level", label: "Level" },
  { key: "item", label: "Item", class: "max-w-[160px] truncate" },
  { key: "session", label: "Session", mono: true, class: "text-text-muted" },
  { key: "text", label: "Message", class: "max-w-[520px] truncate" },
];

const levelTone = (level) =>
  level === "Info" || level === "Trace" ? "text-text-muted" : level === "Warning" ? "text-confirm" : "text-deny";
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" placeholder="Filter rows" />
    <button
      v-for="s in spaces"
      :key="s.namespace"
      class="flex h-[var(--size-btn)] shrink-0 items-center gap-1.5 rounded-control border border-line px-[11px] font-mono text-small transition-colors disabled:cursor-not-allowed disabled:opacity-40"
      :class="
        s.namespace === ns
          ? 'bg-surface-raised text-text-bright'
          : 'bg-surface text-text-muted hover:bg-surface-raised hover:text-text'
      "
      :disabled="!!s.error"
      :title="
        s.error || (s.running ? `${s.running} is running` : `${s.productions.length} production(s), none running`)
      "
      @click="((ns = s.namespace), (session = null))"
    >
      <span class="size-[5px] rounded-badge" :class="s.running ? 'bg-allow' : 'bg-text-dim'" />
      {{ s.namespace }}
    </button>

    <RefreshButton :busy="busy" title="Read the productions, messages and events again" @click="load" />
  </div>

  <div v-if="here" class="flex min-h-0 shrink-0 gap-panel">
    <ProductionCard v-bind="here" @changed="load" />

    <Block
      title="ITEMS"
      :meta="`${items.length} · errors over the last 24 hours`"
      meta-title="Read straight from Ens.Config.Production in the production's own namespace. The SysAdmin API has no endpoint for any of this."
      class="min-w-0 flex-1"
      style="height: 214px"
    >
      <template #actions>
        <span v-if="errorItems.length" class="inline-flex items-center gap-1.5 text-micro text-deny">
          <span class="size-[5px] rounded-badge bg-current" />{{ errorItems.length }}
          with errors
        </span>
      </template>

      <DataTable
        :columns="itemColumns"
        :rows="items"
        row-key="name"
        :state="itemsV[0]"
        :error="itemsV[1]"
        tool="ens.production.items"
        :empty="here.productions.length ? 'No items' : 'No production'"
        :empty-hint="
          here.productions.length
            ? 'This production is defined but has nothing configured in it.'
            : `No production has been deployed in ${here.namespace}.`
        "
        @retry="load"
      >
        <template #name="{ row }">
          <span :class="row.enabled ? 'text-text-bright' : 'text-text-muted line-through'" :title="row.comment">
            {{ row.name }}
          </span>
        </template>
        <template #errors="{ row }">
          <span :class="row.errors ? 'text-deny' : 'text-text-muted'">{{ row.errors }}</span>
        </template>
      </DataTable>
    </Block>
  </div>

  <Block
    :title="tab === 'messages' ? 'MESSAGES' : 'EVENT LOG'"
    :meta="`${rows.length} of ${tab === 'messages' ? messages.length : events.length} · ${ns || 'no namespace'}`"
    meta-title="Ens.MessageHeader and Ens.Util.Log, read in the production's namespace. Selecting a row narrows both tables to that session."
    class="flex-1"
  >
    <template #actions>
      <button
        v-if="session"
        class="inline-flex h-[22px] items-center gap-1.5 rounded-badge border border-line-strong px-2 font-mono text-micro text-text-muted"
        title="One session, across messages and events. Click to drop it."
        @click="session = null"
      >
        session {{ session }} ✕
      </button>
      <label
        v-if="tab === 'events'"
        class="flex cursor-pointer items-center gap-1.5 text-micro text-text-muted"
        title="Asserts, errors, warnings and alerts, not the info and trace around them."
      >
        <input v-model="problemsOnly" type="checkbox" class="accent-accent" />
        problems only
      </label>
      <TabBar v-model="tab" :tabs="tabs" size="sm" />
    </template>

    <DataTable
      :columns="tab === 'messages' ? messageColumns : eventColumns"
      :rows="rows"
      row-key="id"
      selectable
      :state="logV[0]"
      :error="logV[1]"
      :tool="tab === 'messages' ? 'ens.messages' : 'ens.events'"
      :empty="filter ? 'Nothing matches' : tab === 'messages' ? 'No messages yet' : 'The event log is empty'"
      @select="session = $event.session || null"
      @retry="load"
    >
      <template #status="{ row }">
        <span class="inline-flex items-center gap-1.5" :class="failed(row) ? 'text-deny' : 'text-text-muted'">
          <span v-if="failed(row)" class="size-[5px] rounded-badge bg-current" />{{ row.status }}
        </span>
        <span v-if="row.errorText" class="ml-1.5 text-deny" :title="row.errorText">·</span>
      </template>
      <template #level="{ row }">
        <span class="inline-flex items-center gap-1.5" :class="levelTone(row.level)">
          <span class="size-[5px] rounded-badge bg-current" />{{ row.level }}
        </span>
      </template>
      <template #text="{ row }">
        <span :title="row.text">{{ row.text }}</span>
      </template>
    </DataTable>
  </Block>
</template>
