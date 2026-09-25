<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { age, events, poll, stampAgo } from "../composables/useShell";
import { t } from "../composables/useI18n";
import Block from "./Block.vue";

const tasks = shallowRef([]);
const history = shallowRef([]);
const suspended = shallowRef(new Set());
const missing = ref("");
const DAY = 86_400_000;

watch(
  events,
  async () => {
    const [l, h, s] = await Promise.allSettled([
      poll("task.list", { maxRows: 500 }),
      poll("task.history", { maxRows: 1000 }),
      poll("task.states"),
    ]);
    if (l.status === "fulfilled") tasks.value = l.value.data;
    missing.value = l.status === "rejected" ? l.reason?.message : "";
    if (h.status === "fulfilled") history.value = h.value.data;
    if (s.status === "fulfilled") suspended.value = new Set(s.value.data.filter((x) => x.suspended).map((x) => x.id));
  },
  { immediate: true },
);

const failedRun = (r) => !(String(r.Status) === "1" && !+r.ErrNumber);

const runs = computed(() => {
  const out = {};
  for (const r of history.value) {
    const one = (out[r.TaskId] ??= { failed: failedRun(r), day: 0 });
    if (age(r.LastStart) < DAY) one.day++;
  }
  return out;
});

const state = (task) => (suspended.value.has(+task.Id) ? "suspended" : runs.value[task.Id]?.failed ? "failed" : "ok");
const DOT = { ok: "bg-allow", failed: "bg-deny", suspended: "bg-confirm" };

const upcoming = computed(() => {
  const soon = tasks.value
    .map((task) => ({ task, in: -age(task.NextScheduled || "x") }))
    .filter((x) => x.in > -60_000 && x.in < DAY)
    .sort((a, b) => a.in - b.in);
  const rows = [];
  for (const x of soon) {
    const at = x.task.NextScheduled.slice(11, 16);
    const last = rows.at(-1);
    if (last?.at === at) last.tasks.push(x.task);
    else rows.push({ at, in: x.in, tasks: [x.task] });
  }
  return rows;
});

const dots = computed(() =>
  upcoming.value.flatMap((r) =>
    r.tasks.map((task) => ({ x: (Math.max(0, r.in) / DAY) * 100, s: state(task), name: task.Name })),
  ),
);
const ticks = computed(
  () =>
    upcoming.value &&
    [0, 6, 12, 18].map((h) => ({
      x: (h / 24) * 100,
      label: h ? stampAgo(-h * 3_600_000).slice(11, 16) : `${t("scheduler.now")} ${stampAgo(0).slice(11, 16)}`,
    })),
);

const failing = computed(() => tasks.value.filter((x) => state(x) === "failed").length);
const note = (row) => {
  const s = row.tasks.map(state);
  if (s.includes("suspended")) return ["text-confirm", t("scheduler.suspended")];
  if (s.includes("failed")) return ["text-deny", t("scheduler.failedLast")];
  const n = runs.value[row.tasks[0].Id]?.day ?? 0;
  return ["text-text-muted", n > 1 ? t("scheduler.runsToday", { n }) : t("scheduler.okLast")];
};
</script>

<template>
  <Block :title="t('scheduler.block')" :scroll="false">
    <template #actions>
      <RouterLink v-if="failing" to="/tasks?state=failed" class="text-micro text-deny no-underline hover:underline">
        {{ t("scheduler.failing", { n: failing }) }}
      </RouterLink>
      <RouterLink
        v-if="suspended.size"
        to="/tasks?state=suspended"
        class="text-micro text-confirm no-underline hover:underline"
      >
        {{ t("scheduler.suspendedN", { n: suspended.size }) }}
      </RouterLink>
    </template>

    <div class="flex min-h-0 flex-1 flex-col px-3 py-2">
      <div class="relative h-[30px] shrink-0">
        <div class="absolute inset-x-0 top-[11px] h-px bg-line-strong" />
        <span
          v-for="(d, i) in dots"
          :key="i"
          class="absolute top-2 size-[7px] -translate-x-1/2 rounded-badge ring-2 ring-surface"
          :class="DOT[d.s]"
          :style="{ left: `${d.x}%` }"
          :title="d.name"
        />
        <span
          v-for="k in ticks"
          :key="k.label"
          class="absolute top-[18px] font-mono text-[10.5px] text-text-dim"
          :class="k.x ? '-translate-x-1/2' : ''"
          :style="{ left: `${k.x}%` }"
        >
          {{ k.label }}
        </span>
      </div>

      <div class="mt-1.5 min-h-0 flex-1 overflow-y-auto">
        <RouterLink
          v-for="r in upcoming"
          :key="r.at"
          to="/tasks"
          class="grid h-[26px] grid-cols-[42px_5px_minmax(0,1fr)_auto] items-center gap-2 border-b border-line text-small no-underline"
        >
          <span class="font-mono text-micro text-text-muted">{{ r.at }}</span>
          <span class="size-[5px] rounded-badge" :class="DOT[state(r.tasks[0])]" />
          <span class="truncate text-text" :title="r.tasks.map((x) => x.Name).join('\n')">
            {{ r.tasks[0].Name }}{{ r.tasks.length > 1 ? t("scheduler.andMore", { n: r.tasks.length - 1 }) : "" }}
          </span>
          <span class="text-micro" :class="note(r)[0]">{{ note(r)[1] }}</span>
        </RouterLink>
        <p v-if="!upcoming.length" class="py-2 text-micro text-text-muted">{{ missing || t("scheduler.nothing") }}</p>
      </div>
    </div>
  </Block>
</template>
