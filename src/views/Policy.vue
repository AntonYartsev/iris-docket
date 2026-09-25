<script setup>
import { computed } from "vue";
import { api, useResource } from "../composables/useApi";
import { t } from "../composables/useI18n";
import { info, tools as registry } from "../composables/useShell";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import PolicyRules from "../components/PolicyRules.vue";

const { data: policy, error, pending, reload } = useResource(() => api("/policy"));

const held = (privilege) => {
  // %All is role not resource
  if (privilege === "%All") return (info.value?.portal?.roles ?? "").split(",").includes("%All");
  const key = privilege.replace(/^%Admin_/, "").replace(/:.*$/, "");
  return info.value?.instance?.privileges?.[key]?.use;
};

const privileges = computed(() => {
  const by = new Map();
  for (const tool of registry.value ?? []) {
    const key = tool.privilege || "-";
    if (!by.has(key)) by.set(key, { privilege: key, tools: [], writes: 0 });
    const row = by.get(key);
    row.tools.push(tool.name);
    if (tool.mutating) row.writes += 1;
  }
  return [...by.values()].sort((a, b) => b.tools.length - a.tools.length);
});

const columns = computed(() => [
  {
    key: "privilege",
    label: t("policy.col.privilege"),
    mono: true,
    class: "text-text-bright",
  },
  {
    key: "have",
    label: t("policy.col.account"),
    sort: (r) => held(r.privilege),
  },
  {
    key: "count",
    label: t("policy.col.count"),
    mono: true,
    right: true,
    sort: (r) => r.tools.length,
  },
  {
    key: "writes",
    label: t("policy.col.writes"),
    mono: true,
    right: true,
    class: "text-text-muted",
  },
  {
    key: "tools",
    label: t("policy.col.which"),
    mono: true,
    class: "max-w-[420px] truncate text-text-muted",
  },
]);
</script>

<template>
  <div class="flex min-h-0 min-w-0 flex-1 flex-col gap-panel">
    <PolicyRules
      v-if="policy"
      :config="policy.config"
      :versions="policy.versions"
      :pending="pending"
      :error="error?.message"
      @saved="reload"
    />

    <Block
      :title="t('policy.privileges')"
      :meta="t('policy.privileges.meta', { n: privileges.length })"
      :meta-title="t('policy.privileges.metaTitle')"
      class="h-[260px] shrink-0"
    >
      <DataTable :columns="columns" :rows="privileges" row-key="privilege" sortable :empty="t('policy.registryEmpty')">
        <template #have="{ row }">
          <span v-if="row.privilege === '-'" class="text-text-muted">{{ t("policy.notAnnotated") }}</span>
          <span v-else-if="held(row.privilege) === true" class="inline-flex items-center gap-1.5 text-allow">
            <span class="size-[5px] rounded-badge bg-current" />{{ t("policy.holds") }}
          </span>
          <span v-else-if="held(row.privilege) === undefined" class="text-text-muted">{{
            t("policy.notReported")
          }}</span>
          <span v-else class="inline-flex items-center gap-1.5 text-confirm">
            <span class="size-[5px] rounded-badge bg-current" />{{ t("policy.doesNotHold") }}
          </span>
        </template>
        <template #count="{ row }">{{ row.tools.length }}</template>
        <template #tools="{ row }">
          <span :title="row.tools.join(', ')">{{ row.tools.join(", ") }}</span>
        </template>
      </DataTable>
    </Block>
  </div>
</template>
