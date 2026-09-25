<script setup>
import { computed, ref, shallowRef } from "vue";
import { api } from "../composables/useApi";
import { stored } from "../composables/useStored";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import FilterField from "../components/FilterField.vue";
import RefreshButton from "../components/RefreshButton.vue";
import RoleDetail from "../components/RoleDetail.vue";
import TabBar from "../components/TabBar.vue";
import ToolDialog from "../components/ToolDialog.vue";
import UserDetail from "../components/UserDetail.vue";

const { invoke } = useToolInvoke();

const FILL = "w-full max-w-0 truncate text-text-muted";

const TABS = [
  {
    key: "users",
    label: "Users",
    title: "ACCOUNTS",
    tool: "security.users.list",
    args: { names: "*", maxRows: 1000 },
    rowKey: "Name",
    columns: [
      { key: "Name", label: "Account", mono: true, class: "text-text-bright" },
      { key: "FullName", label: "Full name", class: FILL },
      { key: "Type", label: "Type", class: "text-text-muted" },
      { key: "Enabled", label: "State" },
    ],
  },
  {
    key: "roles",
    label: "Roles",
    title: "ROLES",
    tool: "security.roles.list",
    args: { maxRows: 1000 },
    rowKey: "Name",
    columns: [
      { key: "Name", label: "Role", mono: true, class: "text-text-bright" },
      { key: "Description", label: "Description", class: FILL },
      { key: "EscalationOnly", label: "Escalation only" },
    ],
  },
  {
    key: "resources",
    label: "Resources",
    title: "RESOURCES",
    tool: "security.resources.list",
    args: { maxRows: 1000 },
    rowKey: "Name",
    columns: [
      { key: "Name", label: "Resource", mono: true, class: "text-text-bright" },
      { key: "Description", label: "Description", class: FILL },
      { key: "ResourceType", label: "Type" },
      { key: "PublicPermission", label: "Public", mono: true, class: "text-text-muted" },
    ],
  },
];

const tab = stored(
  "security.tab",
  "users",
  TABS.map((t) => t.key),
);
const current = computed(() => TABS.find((t) => t.key === tab.value));

const filter = ref("");
const selected = ref("");
const selectedRole = ref("");
const rows = shallowRef({ users: [], roles: [], resources: [] });
const truncated = ref([]);
const state = shallowRef({ users: "loading", roles: "loading", resources: "loading" });
const error = shallowRef({});
const busy = ref(false);
const tools = shallowRef([]);
const dialogTool = ref(null);

async function load() {
  busy.value = true;
  const answers = await Promise.allSettled(TABS.map((s) => invoke(s.tool, s.args, true)));
  const next = {},
    states = {},
    failures = {},
    cut = [];
  answers.forEach((a, i) => {
    const { key } = TABS[i];
    next[key] = a.status === "fulfilled" ? a.value.data : [];
    states[key] = a.status === "fulfilled" ? "ready" : a.reason.code === "policy_denied" ? "denied" : "error";
    if (a.status === "rejected") failures[key] = a.reason.message;
    else if (a.value.meta.truncated) cut.push(key);
  });
  rows.value = next;
  state.value = states;
  error.value = failures;
  truncated.value = cut;
  busy.value = false;
  tools.value = await api("/tools?category=security").then((r) => r.data);
}
load();

const tabs = computed(() => TABS.map((t) => ({ key: t.key, label: t.label, count: rows.value[t.key].length })));

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  const list = rows.value[tab.value];
  return q ? list.filter((r) => JSON.stringify(r).toLowerCase().includes(q)) : list;
});

const tool = (name) => tools.value.find((t) => t.name === name) ?? null;
const openCreate = () =>
  (dialogTool.value = tool(tab.value === "users" ? "security.user.create" : "security.role.save"));
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" />
    <TabBar v-model="tab" :tabs="tabs" />
    <RefreshButton :busy="busy" title="Read the accounts, roles and resources again" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block :title="current.title" :meta="`${shown.length} of ${rows[tab].length}`" class="flex-1">
      <template v-if="tab !== 'resources'" #actions>
        <button
          class="h-[22px] rounded-control bg-accent px-2 text-micro font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover"
          @click="openCreate"
        >
          New
        </button>
      </template>

      <DataTable
        :columns="current.columns"
        :rows="shown"
        :row-key="current.rowKey"
        :selectable="tab !== 'resources'"
        :selected="tab === 'users' ? selected : tab === 'roles' ? selectedRole : null"
        :state="state[tab]"
        :error="error[tab]"
        :tool="current.tool"
        :truncated="truncated.includes(tab)"
        :empty="filter ? 'Nothing matches the filter' : 'The instance reports none'"
        @select="tab === 'users' ? (selected = $event.Name) : (selectedRole = $event.Name)"
        @retry="load"
      >
        <template #Name="{ row }">
          <span v-if="tab === 'users'" class="inline-flex items-center gap-1.5">
            <span class="size-[5px] rounded-badge" :class="row.Enabled ? 'bg-allow' : 'bg-deny'" />
            {{ row.Name }}
          </span>
          <template v-else>{{ row.Name }}</template>
        </template>
        <template #FullName="{ row }">
          <span :title="row.FullName">{{ row.FullName || "-" }}</span>
        </template>
        <template #Description="{ row }">
          <span :title="row.Description">{{ row.Description || "-" }}</span>
        </template>
        <template #Enabled="{ row }">
          <span :class="row.Enabled ? 'text-text-muted' : 'text-deny'">{{ row.Enabled ? "enabled" : "disabled" }}</span>
        </template>
        <template #EscalationOnly="{ row }">
          <span class="text-text-muted">{{ row.EscalationOnly ? "yes" : "no" }}</span>
        </template>
        <template #PublicPermission="{ row }">{{ row.PublicPermission || "-" }}</template>
      </DataTable>
    </Block>

    <UserDetail
      v-if="tab === 'users' && selected"
      :key="selected"
      :username="selected"
      :roles="rows.roles"
      @changed="load"
      @close="selected = ''"
    />
    <RoleDetail
      v-else-if="tab === 'roles' && selectedRole"
      :key="selectedRole"
      :name="selectedRole"
      :tool="tool('security.role.save')"
      @changed="load"
      @close="selectedRole = ''"
    />
  </div>

  <ToolDialog :tool="dialogTool" @close="dialogTool = null" @done="load" />
</template>
