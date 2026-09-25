<script setup>
// ponytail: paging only read window
import { computed, onUnmounted, ref, shallowRef, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import { stored } from "../composables/useStored";
import Block from "../components/Block.vue";
import JournalPanel from "../components/JournalPanel.vue";
import FilterField from "../components/FilterField.vue";
import LogEntry, { DOT } from "../components/LogEntry.vue";
import Pager from "../components/Pager.vue";
import RefreshButton from "../components/RefreshButton.vue";

const { invoke } = useToolInvoke();

const RANK = { info: 0, warn: 1, severe: 2, fatal: 3 };
const SOURCES = [
  {
    key: "messages",
    label: "messages.log",
    tool: "logs.messages",
    args: { lines: 300 },
  },
  {
    key: "alerts",
    label: "alerts.log",
    tool: "logs.alerts",
    args: { lines: 300 },
  },
  {
    key: "audit",
    label: "system audit",
    tool: "logs.audit",
    args: { maxRows: 300 },
  },
];
const LEVELS = ["info", "warn", "severe", "fatal"];
const PAGE = 100;

const feed = shallowRef([]);
let buffered = null;
const broken = shallowRef([]);
const on = stored("logs.sources", {
  messages: true,
  alerts: true,
  audit: true,
});
const minLevel = stored("logs.level", "info", LEVELS);
const filter = ref("");
const expanded = ref(null);
const loadedAt = ref("");
const state = ref("loading");
const held = ref(0);
const tail = stored("logs.tail", true);
const hover = ref(false);
const page = ref(0);
const busy = ref(false);
const holding = computed(() => hover.value || page.value > 0);

async function load(force = false) {
  busy.value = true;
  const settled = await Promise.allSettled(SOURCES.map((s) => invoke(s.tool, s.args, true)));
  busy.value = false;
  // allSettled, sources fail seperately
  broken.value = settled.flatMap((r, i) =>
    r.status === "rejected" ? [`${SOURCES[i].label}: ${r.reason.message}`] : [],
  );
  const rows = settled.flatMap((r) => (r.status === "fulfilled" ? r.value.data : []));
  const seen = new Map();
  const next = rows
    .map((r) => {
      const key = `${r.source}|${r.ts}|${r.text}`;
      seen.set(key, (seen.get(key) ?? 0) + 1);
      return { ...r, id: `${key}|${seen.get(key)}` };
    })
    .sort((a, b) => (a.ts < b.ts ? 1 : -1));

  state.value = broken.value.length === SOURCES.length ? "error" : "ready";

  if (!force && holding.value && feed.value.length) {
    const known = new Set(feed.value.map((r) => r.id));
    buffered = next;
    held.value = next.filter((r) => !known.has(r.id)).length;
    return;
  }
  show(next);
}

function show(next) {
  const known = new Set(feed.value.map((r) => r.id));
  feed.value = next.map((r) => ({
    ...r,
    fresh: feed.value.length > 0 && !known.has(r.id),
  }));
  buffered = null;
  held.value = 0;
  loadedAt.value = new Date().toLocaleTimeString();
}
load();

const timer = setInterval(() => tail.value && load(), 10_000);
onUnmounted(() => clearInterval(timer));

const release = () => {
  page.value = 0;
  if (buffered) show(buffered);
};
const refresh = () => ((page.value = 0), load(true));
const leave = () => ((hover.value = false), page.value === 0 && buffered && show(buffered));
watch(page, (p) => p === 0 && !hover.value && buffered && show(buffered));

const counts = computed(() =>
  Object.fromEntries(SOURCES.map((s) => [s.key, feed.value.filter((r) => r.source === s.key).length])),
);
const levelCounts = computed(() =>
  Object.fromEntries(LEVELS.map((l) => [l, feed.value.filter((r) => r.level === l).length])),
);

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const floor = RANK[minLevel.value];
  return feed.value.filter(
    (r) =>
      on.value[r.source] &&
      RANK[r.level] >= floor &&
      (!q || `${r.text} ${r.category} ${r.user ?? ""} ${r.process}`.toLowerCase().includes(q)),
  );
});

watch([filter, minLevel, on], () => (page.value = 0), { deep: true });
watch(shown, (rows) => (page.value = Math.min(page.value, Math.max(0, Math.ceil(rows.length / PAGE) - 1))));
const onPage = computed(() => shown.value.slice(page.value * PAGE, (page.value + 1) * PAGE));
const range = computed(() =>
  shown.value.length
    ? `${page.value * PAGE + 1}–${page.value * PAGE + onPage.value.length} of ${shown.value.length}`
    : "",
);
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" placeholder="Search messages" />
    <button
      class="inline-flex h-[var(--size-btn)] w-[92px] shrink-0 items-center justify-center gap-1.5 rounded-control border px-3 text-small transition-colors"
      :class="
        tail
          ? 'border-line-strong bg-surface-raised text-text'
          : 'border-line-strong text-text-muted hover:bg-surface-raised'
      "
      :title="
        tail
          ? 'Reading the logs every 10 seconds. Click to stop.'
          : 'Not reading on its own. Click to read every 10 seconds.'
      "
      @click="tail = !tail"
    >
      <span class="size-1.5 rounded-badge" :class="tail ? 'bg-allow' : 'bg-text-dim'" />
      {{ tail ? "live" : "paused" }}
    </button>
    <RefreshButton :busy="busy" title="Read the logs again now" @click="refresh" />
  </div>

  <div class="flex shrink-0 flex-wrap items-center gap-1.5">
    <button
      v-for="s in SOURCES"
      :key="s.key"
      class="inline-flex h-[26px] items-center gap-1.5 rounded-badge border px-2.5 text-micro transition-colors"
      :class="on[s.key] ? 'border-line-strong bg-surface-raised text-text' : 'border-line text-text-muted'"
      :title="broken.find((b) => b.startsWith(s.label)) || `${s.tool}: ${counts[s.key]} rows in the feed`"
      @click="on[s.key] = !on[s.key]"
    >
      <span
        class="size-[5px] rounded-badge"
        :class="broken.some((b) => b.startsWith(s.label)) ? 'bg-deny' : 'bg-allow'"
      />
      {{ s.label }}
      <span class="text-text-muted">{{ counts[s.key] ?? 0 }}</span>
    </button>

    <span class="mx-1 h-[14px] w-px bg-line" />

    <button
      v-for="l in LEVELS"
      :key="l"
      class="inline-flex h-[26px] items-center gap-1.5 rounded-badge border px-2.5 text-micro transition-colors"
      :class="minLevel === l ? 'border-line-strong bg-surface-raised text-text' : 'border-line text-text-muted'"
      :title="`Show ${l} and worse`"
      @click="minLevel = l"
    >
      <span class="size-[5px] rounded-badge" :class="DOT[l]" />
      {{ l === "info" ? "every" : l }}
      <span class="text-text-muted">{{ levelCounts[l] ?? 0 }}</span>
    </button>
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      title="FEED"
      :meta="`${shown.length} of ${feed.length}${loadedAt ? ` · read at ${loadedAt}` : ''}`"
      meta-title="Two of the three are read from disk by the portal's own server: the SysAdmin API has no endpoint for messages.log or alerts.log."
      class="flex-1"
    >
      <template #actions>
        <button
          v-if="held"
          class="inline-flex h-[22px] items-center gap-1.5 rounded-control border border-confirm px-2 text-micro text-confirm transition-colors hover:bg-confirm-soft"
          title="New entries arrived while you were reading. Click to go to the newest."
          @click="release"
        >
          <span class="size-[5px] rounded-badge bg-current" />{{ held }} new · show
        </button>
        <Pager
          class="text-micro text-text-muted"
          :range="range"
          :newer="page > 0"
          :older="(page + 1) * PAGE < shown.length"
          @newest="release"
          @newer="page--"
          @older="page++"
        />
      </template>

      <p
        v-for="b in broken"
        :key="b"
        class="shrink-0 border-b border-line bg-deny-soft px-2.5 py-1 text-micro text-deny"
      >
        {{ b }}
      </p>

      <div class="min-h-0 flex-1 overflow-auto font-mono text-micro" @pointerenter="hover = true" @pointerleave="leave">
        <LogEntry
          v-for="r in onPage"
          :key="r.id"
          :row="r"
          :open="expanded === r.id"
          @toggle="expanded = expanded === r.id ? null : r.id"
        />

        <p v-if="state === 'loading'" class="px-2.5 py-3 text-text-muted">Reading the logs…</p>
        <p v-else-if="!shown.length" class="px-2.5 py-3 text-text-muted">
          Nothing in the selected sources at this level.
        </p>
      </div>
    </Block>

    <JournalPanel />
  </div>
</template>
