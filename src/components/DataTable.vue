<script setup>
import { computed, ref } from "vue";
import Icon from "./Icon.vue";

const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, default: () => [] },
  rowKey: { type: String, default: "Name" },
  selected: { type: [String, Number], default: null },
  selectable: { type: Boolean, default: false },
  sortable: { type: Boolean, default: false },
  state: { type: String, default: "ready" },
  error: { type: String, default: "" },
  tool: { type: String, default: "" },
  truncated: { type: Boolean, default: false },
  empty: { type: String, default: "The instance reports none." },
  emptyHint: { type: String, default: "" },
});

defineEmits(["select", "retry"]);

const view = computed(() => (props.state === "ready" && !props.rows.length ? "empty" : props.state));
const skeleton = Array.from({ length: 14 }, (_, i) => i);

const sort = ref({ key: "", dir: 1 });

function by(column) {
  if (sort.value.key !== column.key) sort.value = { key: column.key, dir: 1 };
  else if (sort.value.dir === 1) sort.value = { key: column.key, dir: -1 };
  else sort.value = { key: "", dir: 1 };
}

const ordered = computed(() => {
  const c = props.columns.find((x) => x.key === sort.value.key);
  if (!c) return props.rows;
  const value = c.sort ?? ((r) => r[c.key]);
  return [...props.rows].sort((a, b) => {
    const [x, y] = [value(a), value(b)];
    if (x === y) return 0;
    if (x === undefined || x === null || x === "") return 1; // blanks goes last
    if (y === undefined || y === null || y === "") return -1;
    return (
      (typeof x === "number" && typeof y === "number" ? x - y : String(x).localeCompare(String(y))) * sort.value.dir
    );
  });
});
</script>

<template>
  <div
    v-if="truncated && view === 'ready'"
    class="flex shrink-0 items-start gap-2 border-b border-confirm bg-confirm-soft px-2.5 py-2"
  >
    <Icon name="findings" :size="15" class="mt-px text-confirm" />
    <div class="min-w-0">
      <div class="text-small font-medium text-confirm">Cut at the API's row cap</div>
      <div class="text-micro text-text">
        The list came back at exactly <span class="font-mono">maxRows</span>, and the SysAdmin API has no way of saying
        whether more exist. What is below is the rows it returned, in its order, not the busiest and not the newest.
        Narrow the filter to see the rest.
      </div>
    </div>
  </div>

  <div v-if="view === 'ready'" class="min-h-0 flex-1 overflow-auto">
    <table class="w-full border-collapse tabular-nums">
      <thead>
        <tr>
          <th
            v-for="c in columns"
            :key="c.key"
            class="sticky top-0 z-1 border-b border-line bg-inset px-cell-x py-[5px] text-left text-micro font-normal whitespace-nowrap text-text-muted"
            :class="[c.right && 'text-right', sortable && 'cursor-pointer select-none hover:text-text']"
            :style="c.width && { width: c.width }"
            @click="sortable && by(c)"
          >
            {{ c.label }}
            <span v-if="sortable && sort.key === c.key" class="text-text">{{ sort.dir === 1 ? "↑" : "↓" }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in ordered"
          :key="row[rowKey]"
          class="border-b border-line transition-colors hover:bg-surface-raised"
          :class="[
            selectable && 'cursor-pointer',
            row[rowKey] === selected &&
              'bg-surface-raised [&>td:first-child]:shadow-[inset_2px_0_0_0_var(--color-accent)]',
          ]"
          @click="selectable && $emit('select', row)"
        >
          <td
            v-for="c in columns"
            :key="c.key"
            class="h-[var(--size-row)] px-cell-x py-cell-y text-micro whitespace-nowrap"
            :class="[c.mono && 'font-mono', c.right && 'text-right', c.class]"
          >
            <slot :name="c.key" :row="row">{{ row[c.key] }}</slot>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <div v-else-if="view === 'loading'" class="min-h-0 flex-1 overflow-hidden px-cell-x">
    <div v-for="i in skeleton" :key="i" class="flex h-[var(--size-row)] items-center gap-cell-x border-b border-line">
      <span
        v-for="c in columns"
        :key="c.key"
        class="h-2 flex-1 animate-skeleton rounded-tight bg-surface-raised"
        :style="{ animationDelay: `${i * 100}ms` }"
      />
    </div>
  </div>

  <div
    v-else-if="view === 'empty'"
    class="flex min-h-0 flex-1 flex-col items-center justify-center gap-2 p-6 text-center"
  >
    <Icon name="tools" :size="34" class="text-text-muted" />
    <div class="text-display text-text-bright">{{ empty }}</div>
    <p class="max-w-[420px] text-small text-text-muted">
      {{ emptyHint || `${tool || "The call"} answered with an empty list. That is a real answer, not a failure.` }}
    </p>
  </div>

  <div v-else class="flex min-h-0 flex-1 flex-col gap-[9px] overflow-y-auto p-3.5">
    <div class="flex items-center gap-2">
      <span
        class="inline-flex h-[22px] items-center gap-1.5 rounded-badge border border-deny bg-deny-soft px-2 text-micro font-medium text-deny"
      >
        <span class="size-[5px] rounded-badge bg-current" />{{ view === "denied" ? "deny" : "failed" }}
      </span>
      <span class="font-mono text-small text-text-bright">{{ tool || "the call" }}</span>
    </div>
    <p class="max-w-[560px] text-small text-text">{{ error }}</p>
    <p v-if="view === 'denied'" class="text-micro text-text-muted">
      Refused before the call left the portal, and written to the journal anyway: refusals are records.
    </p>
    <div>
      <button
        class="h-[var(--size-btn)] rounded-control border border-line-strong px-3 text-small font-medium text-text transition-colors hover:bg-surface-raised"
        @click="$emit('retry')"
      >
        Retry
      </button>
    </div>
  </div>
</template>
