<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { events, poll } from "../composables/useShell";
import { t } from "../composables/useI18n";
import Block from "./Block.vue";

const metrics = shallowRef([]);
const journal = shallowRef([]);
const noJournal = ref("");
const SHOWN = 5;

watch(
  events,
  async () => {
    const [m, j] = await Promise.allSettled([
      poll("monitor.metrics", { names: "iris_db_size_mb,iris_db_free_space,iris_jrn_free_space" }),
      poll("journal.files"),
    ]);
    if (m.status === "fulfilled") metrics.value = m.value.data;
    if (j.status === "fulfilled") journal.value = j.value.data;
    noJournal.value = j.status === "rejected" ? j.reason?.message : "";
  },
  { immediate: true },
);

const by = (name) =>
  Object.fromEntries((metrics.value.find((m) => m.name === name)?.samples ?? []).map((s) => [s.labels.id, s.value]));

const dbs = computed(() => {
  const free = by("iris_db_free_space");
  return Object.entries(by("iris_db_size_mb"))
    .map(([name, size]) => ({ name, size, free: Math.min(free[name] ?? 0, size) }))
    .sort((a, b) => b.size - a.size);
});
const biggest = computed(() => dbs.value[0]?.size || 1);
const rest = computed(() => dbs.value.slice(SHOWN));
const mb = (n) => (n >= 1024 ? `${(n / 1024).toFixed(1)} GB` : `${Math.round(n).toLocaleString()} MB`);
const sum = (list) => list.reduce((a, d) => a + d.size, 0);

const days = computed(() => {
  const per = {};
  for (const f of journal.value) {
    const d = (f.Name.match(/(\d{8})\.\d+$/) ?? [])[1];
    if (d) per[d] = (per[d] ?? 0) + (f.Size ?? 0);
  }
  const list = Object.entries(per)
    .sort()
    .slice(-5)
    .map(([d, bytes]) => ({ label: `${d.slice(6, 8)}.${d.slice(4, 6)}`, mb: bytes / 1048576 }));
  const top = Math.max(1, ...list.map((d) => d.mb));
  return list.map((d, i) => ({ ...d, h: (d.mb / top) * 100, today: i === list.length - 1 }));
});
const jrnFree = computed(() => by("iris_jrn_free_space").primary);
</script>

<template>
  <Block :title="t('storage.block')" :meta="t('storage.meta', { n: dbs.length, total: mb(sum(dbs)) })" :scroll="false">
    <div class="flex min-h-0 flex-1 flex-col overflow-y-auto px-3 py-2">
      <div
        v-for="d in dbs.slice(0, SHOWN)"
        :key="d.name"
        class="grid h-[22px] grid-cols-[92px_minmax(0,1fr)_66px] items-center gap-2 text-micro"
        :title="t('storage.dbTitle', { name: d.name, size: mb(d.size), free: mb(d.free) })"
      >
        <span class="truncate font-mono text-text">{{ d.name }}</span>
        <div
          class="flex h-2 overflow-hidden rounded-[3px]"
          :style="{ width: `${Math.max(3, Math.sqrt(d.size / biggest) * 100)}%` }"
        >
          <i class="bg-accent" :style="{ flex: d.size - d.free }" />
          <i class="bg-accent/25" :style="{ flex: d.free }" />
        </div>
        <span class="text-right font-mono text-text-muted">{{ mb(d.size) }}</span>
      </div>
      <div class="mt-1 flex items-center gap-2 text-micro text-text-muted">
        <span v-if="rest.length">{{ t("storage.rest", { n: rest.length, size: mb(sum(rest)) }) }}</span>
        <span class="ml-auto inline-flex items-center gap-1"
          ><i class="size-[5px] rounded-badge bg-accent" />{{ t("storage.used") }}</span
        >
        <span class="inline-flex items-center gap-1"
          ><i class="size-[5px] rounded-badge bg-accent/25" />{{ t("storage.freeInside") }}</span
        >
      </div>

      <p v-if="noJournal" class="mt-3 text-micro text-text-muted">{{ noJournal }}</p>
      <div
        v-else
        class="mt-3 flex h-[46px] items-end gap-1.5"
        :title="t('storage.journal', { free: jrnFree === undefined ? '-' : mb(jrnFree) })"
      >
        <div
          v-for="d in days"
          :key="d.label"
          class="flex h-full flex-1 flex-col items-center justify-end"
          :title="mb(d.mb)"
        >
          <span class="font-mono text-[10.5px] leading-tight text-text-muted">{{
            d.mb < 1 ? "<1" : Math.round(d.mb)
          }}</span>
          <i
            class="block w-full rounded-t-[3px] bg-accent"
            :class="d.today && 'opacity-50'"
            :style="{ height: `${Math.max(2, (d.h / 100) * 30)}px` }"
          />
        </div>
      </div>
      <div v-if="!noJournal" class="flex gap-1.5 font-mono text-[10.5px] text-text-dim">
        <span v-for="d in days" :key="d.label" class="flex-1 text-center">{{
          d.today ? t("storage.today") : d.label
        }}</span>
      </div>
    </div>
  </Block>
</template>
