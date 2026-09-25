<script setup>
import { computed, ref, shallowRef } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import { refreshShell } from "../composables/useShell";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import DetailPanel from "../components/DetailPanel.vue";
import FieldGrid from "../components/FieldGrid.vue";
import FilterField from "../components/FilterField.vue";
import RefreshButton from "../components/RefreshButton.vue";
import RestSpec from "../components/RestSpec.vue";

const { invoke } = useToolInvoke();

const apps = shallowRef([]);
const services = shallowRef({});
const detail = ref(null);
const selected = ref("");
const filter = ref("");
const ns = ref("");
const only = ref("");
const busy = ref(false);
const state = ref("loading");
const error = ref("");
const restError = ref("");

async function load() {
  busy.value = true;
  try {
    const [list, rest] = await Promise.allSettled([
      invoke("webapp.list", { maxRows: 1000 }, true),
      invoke("rest.services", {}, true),
    ]);
    if (list.status === "rejected") throw list.reason;
    apps.value = list.value.data;
    state.value = "ready";
    restError.value = rest.status === "rejected" ? rest.reason.message : "";
    if (rest.status === "fulfilled") services.value = Object.fromEntries(rest.value.data.map((s) => [s.name, s]));
  } catch (e) {
    error.value = e.message;
    state.value = e.code === "policy_denied" ? "denied" : "error";
  } finally {
    busy.value = false;
  }
}
load();

async function select(name) {
  selected.value = name;
  detail.value = null;
  detail.value = (await invoke("webapp.get", { name }, true)).data;
}

const unauthenticated = (a) => a.AuthenticationMethods.includes("Unauthenticated");
const open = computed(() => apps.value.filter(unauthenticated).length);

const ONLY = { rest: (a) => !!services.value[a.Name], open: unauthenticated, disabled: (a) => !a.Enabled };
const namespaces = computed(() => [...new Set(apps.value.map((a) => a.Namespace).filter(Boolean))].sort());

const shown = computed(() => {
  const q = filter.value.trim().toLowerCase();
  return apps.value.filter(
    (a) =>
      (!ns.value || a.Namespace === ns.value) &&
      (!only.value || ONLY[only.value](a)) &&
      (!q || JSON.stringify(a).toLowerCase().includes(q)),
  );
});

const current = computed(() => apps.value.find((a) => a.Name === selected.value));

const toggle = async () => {
  if (
    !(await invoke("webapp.update", {
      name: selected.value,
      Enabled: !current.value.Enabled,
    }))
  )
    return;
  await load();
  await select(selected.value);
  refreshShell();
};

const columns = [
  {
    key: "Name",
    label: "Application",
    mono: true,
    class: "max-w-[240px] truncate text-text-bright",
  },
  {
    key: "Namespace",
    label: "Namespace",
    mono: true,
    class: "text-text-muted",
  },
  { key: "AuthenticationMethods", label: "Authentication" },
  {
    key: "DispatchClass",
    label: "Dispatch class",
    mono: true,
    class: "max-w-[200px] truncate text-text-muted",
  },
  { key: "rest", label: "REST" },
  { key: "Enabled", label: "State" },
];

const facts = computed(() => [
  ["Namespace", detail.value?.NameSpace ?? current.value?.Namespace],
  ["Dispatch class", detail.value?.DispatchClass],
  ["Files from", detail.value?.Path],
  ["Resource", detail.value?.Resource],
  ["Roles on match", detail.value?.MatchRoles?.join(", ")],
  ["Session timeout", detail.value?.Timeout && `${detail.value.Timeout} s`],
  ["CSRF token", detail.value && (detail.value.CSRFToken ? "on" : "off")],
]);
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="filter" width="auto" placeholder="Filter applications" />
    <select
      v-model="ns"
      class="h-[var(--size-field)] shrink-0 rounded-control border border-line-strong bg-surface px-2 text-small text-text"
    >
      <option value="">any namespace</option>
      <option v-for="n in namespaces" :key="n" :value="n">{{ n }}</option>
    </select>
    <select
      v-model="only"
      class="h-[var(--size-field)] shrink-0 rounded-control border border-line-strong bg-surface px-2 text-small text-text"
    >
      <option value="">all applications</option>
      <option value="rest">REST services</option>
      <option value="open">unauthenticated</option>
      <option value="disabled">disabled</option>
    </select>
    <RefreshButton :busy="busy" title="Read the applications and the REST services again" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      title="WEB APPLICATIONS"
      :meta="`${shown.length} of ${apps.length}`"
      meta-title="The list comes from /api/admin. Which of them is a REST service comes from /api/mgmnt, which the SysAdmin API does not cover at all."
      class="flex-1"
    >
      <template #actions>
        <span
          v-if="open"
          class="inline-flex items-center gap-1.5 text-micro text-deny"
          title="Anyone who can reach the port can reach these applications."
        >
          <span class="size-[5px] rounded-badge bg-current" />{{ open }} unauthenticated
        </span>
      </template>

      <DataTable
        :columns="columns"
        :rows="shown"
        :selected="selected"
        selectable
        :state="state"
        :error="error"
        tool="webapp.list"
        empty="Nothing matches"
        @select="select($event.Name)"
        @retry="load"
      >
        <template #AuthenticationMethods="{ row }">
          <span
            v-for="m in row.AuthenticationMethods"
            :key="m"
            class="mr-1.5 inline-flex items-center gap-1.5"
            :class="m === 'Unauthenticated' ? 'text-deny' : 'text-text-muted'"
          >
            <span v-if="m === 'Unauthenticated'" class="size-[5px] rounded-badge bg-current" />{{ m }}
          </span>
        </template>
        <template #rest="{ row }">
          <span v-if="!services[row.Name]" class="text-text-muted">-</span>
          <span v-else :class="services[row.Name].specKind === 'spec-first' ? 'text-allow' : 'text-confirm'">
            {{ services[row.Name].specKind }}
          </span>
        </template>
        <template #Enabled="{ row }">
          <span :class="row.Enabled ? 'text-text-muted' : 'text-deny'">{{ row.Enabled ? "enabled" : "disabled" }}</span>
        </template>
      </DataTable>

      <template v-if="restError" #footer>
        <span class="truncate text-confirm">The REST column is empty: {{ restError }}</span>
      </template>
    </Block>

    <DetailPanel v-if="selected" title="APPLICATION" :subject="selected" class="!w-[420px]" @close="selected = ''">
      <div class="border-b border-line px-2.5 py-[9px]">
        <p class="mb-1.5 text-micro text-text-muted">
          {{ detail?.Description || "No description." }}
        </p>
        <FieldGrid :rows="facts" label-width="116px" />
      </div>

      <div class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">OPERATIONS</div>
        <button
          class="h-[var(--size-btn)] rounded-control border px-[11px] text-small transition-colors"
          :class="
            current?.Enabled
              ? 'border-deny text-deny hover:bg-deny-soft'
              : 'border-line-strong text-text hover:bg-surface-raised'
          "
          @click="toggle"
        >
          {{ current?.Enabled ? "Disable" : "Enable" }}
        </button>
        <p class="mt-[7px] text-micro text-text-muted">
          The portal's own two applications are refused outright: disabling them is one click from locking everybody
          out, and the rule says so in the journal rather than hiding in this screen's code.
        </p>
      </div>

      <div class="px-2.5 py-[9px]">
        <RestSpec v-if="services[selected]" :name="selected" />
        <p v-else class="text-micro text-text-muted">
          Not a REST service: no dispatch class the instance would describe, so there is no specification to show.
        </p>
      </div>
    </DetailPanel>
  </div>
</template>
