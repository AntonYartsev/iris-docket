<script setup>
import { computed, ref } from "vue";
import { info, reprobe, tools } from "../composables/useShell";
import { t } from "../composables/useI18n";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import FieldGrid from "../components/FieldGrid.vue";
import FilterField from "../components/FilterField.vue";
import InfoTip from "../components/InfoTip.vue";
import RefreshButton from "../components/RefreshButton.vue";
import VersionBadge from "../components/VersionBadge.vue";

const filter = ref("");
const onlyMissing = ref(false);
const busy = ref(false);
const caps = computed(() => info.value?.portal?.capabilities ?? {});
const instance = computed(() => info.value?.instance ?? {});

const rows = computed(() => {
  const q = filter.value.trim().toLowerCase();
  return (tools.value ?? [])
    .filter((x) => !onlyMissing.value || x.available === false)
    .filter((x) => !q || `${x.name} ${x.title} ${x.requires} ${x.category}`.toLowerCase().includes(q));
});

const missing = computed(() => (tools.value ?? []).filter((x) => x.available === false).length);

const facts = computed(() => [
  ["Product", instance.value.product],
  ["Build", caps.value.version, instance.value.serverVersion],
  ["SysAdmin API", caps.value.apiVersion ? `version ${caps.value.apiVersion}` : ""],
  ["Instance", info.value?.portal?.instanceName],
  ["Host", info.value?.portal?.host],
  ["System mode", instance.value.systemMode || "none set"],
  ["Checked", caps.value.ts, caps.value.why ? `${caps.value.ts} - ${caps.value.why}` : caps.value.ts],
  ["Paths served", caps.value.ts ? `${caps.value.paths} (v1 ${caps.value.v1}, v2 ${caps.value.v2})` : ""],
  ["Source", caps.value.source],
]);

const columns = [
  { key: "name", label: "Tool", mono: true, class: "text-text-bright", sort: (r) => r.name },
  { key: "available", label: "On this build", sort: (r) => (r.available === false ? 0 : 1) },
  { key: "requires", label: "Needs upstream", mono: true, class: "max-w-[520px] truncate text-text-muted" },
];

const again = async () => {
  busy.value = true;
  try {
    await reprobe();
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" placeholder="Filter operations" />
    <label class="flex shrink-0 items-center gap-1.5 px-1.5 text-small whitespace-nowrap text-text-muted">
      <input v-model="onlyMissing" type="checkbox" class="size-[14px] accent-accent" />
      only missing
    </label>
    <InfoTip title="What is checked here, and why">
      <p>
        Not every IRIS version has every operation in this portal. The portal asks this instance which ones it has; the
        rest are greyed out and cannot be run, from here or by the agent.
      </p>
      <p>
        This is checked again by itself after an upgrade, or if the last check failed. Press ↻ after changing the
        /api/admin or /api/mgmnt web applications.
      </p>
    </InfoTip>
    <RefreshButton :busy="busy" title="Check the instance again now" @click="again" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 flex-col gap-panel">
    <Block title="THIS INSTANCE" :meta="caps.error ? 'probe failed' : ''" :scroll="false" class="shrink-0">
      <div v-if="caps.error" class="border-b border-confirm bg-confirm-soft px-2.5 py-2">
        <div class="text-small font-medium text-confirm">The instance would not say</div>
        <div class="mt-0.5 text-micro text-text">{{ caps.error }}</div>
        <div class="mt-1 text-micro text-text-muted">
          Nothing is switched off by this: an unprobed instance keeps every operation, and the live answer from
          /api/admin goes back to being the verdict.
        </div>
      </div>

      <div class="px-2.5 py-[9px]">
        <FieldGrid :rows="facts" :columns="3" label-width="84px" />
      </div>
    </Block>

    <Block
      title="OPERATIONS ON THIS BUILD"
      :meta="`${(tools ?? []).length - missing} of ${(tools ?? []).length}`"
      meta-title="One declaration, measured against what this instance publishes. The same answer greys the operation out in the registry and keeps it out of the agent's tool list."
      class="min-h-0 flex-1"
    >
      <DataTable
        :columns="columns"
        :rows="rows"
        row-key="name"
        sortable
        :state="(tools ?? []).length ? 'ready' : 'loading'"
        tool="/portal/api/tools"
        empty="Nothing matches"
      >
        <template #name="{ row }">
          <span :title="row.title">{{ row.name }}</span>
        </template>
        <template #requires="{ row }">
          <span :title="row.requires">{{ row.requires || "nothing outside this instance" }}</span>
        </template>
        <template #available="{ row }">
          <VersionBadge :tool="row" />
          <span v-if="row.available !== false" class="text-text-muted">available</span>
        </template>
      </DataTable>
    </Block>
  </div>
</template>
