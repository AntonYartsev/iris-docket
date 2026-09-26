<script setup>
import { computed, inject, onUnmounted, ref, shallowRef } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import { info } from "../composables/useShell";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import FilterField from "../components/FilterField.vue";
import PackageDetail from "../components/PackageDetail.vue";
import RefreshButton from "../components/RefreshButton.vue";

const { invoke } = useToolInvoke();

const installed = shallowRef([]);
const ipm = ref(true);
const unreadable = shallowRef([]);
const blocked = shallowRef({});
const available = shallowRef([]);
const jobs = shallowRef([]);
const filter = ref("");
const selected = ref("");
const state = ref({ installed: "loading", available: "loading" });
const error = ref({});

async function load() {
  state.value = { installed: "loading", available: "loading" };
  const [left, right, ran] = await Promise.allSettled([
    invoke("packages.installed", {}, true),
    invoke("packages.available", {}, true),
    invoke("packages.jobs", {}, true),
  ]);

  jobs.value = ran.status === "fulfilled" ? ran.value.data : [];

  const states = {},
    failures = {};
  if (left.status === "fulfilled") {
    installed.value = left.value.data.modules;
    ipm.value = left.value.data.ipm;
    unreadable.value = left.value.data.unreadable ?? [];
    blocked.value = left.value.data.blocked ?? {};
    states.installed = "ready";
  } else {
    installed.value = [];
    states.installed = left.reason.code === "policy_denied" ? "denied" : "error";
    failures.installed = left.reason.message;
  }

  available.value = right.status === "fulfilled" ? right.value.data : [];
  states.available =
    right.status === "fulfilled" ? "ready" : right.reason.code === "policy_denied" ? "denied" : "error";
  if (right.status === "rejected") failures.available = right.reason.message;

  state.value = states;
  error.value = failures;
}

const running = computed(() => jobs.value.some((j) => j.state === "Queued" || j.state === "Running"));
let timer = null;

function follow() {
  if (timer) return;
  timer = setInterval(async () => {
    jobs.value = (await invoke("packages.jobs", {}, true)).data;
    if (running.value) return;
    clearInterval(timer);
    timer = null;
    load();
  }, 3000);
}
onUnmounted(() => clearInterval(timer));

load().then(() => running.value && follow());

const latest = computed(() => jobs.value[0] ?? null);
const tone = {
  Finished: "text-allow",
  Running: "text-info",
  Queued: "text-text-muted",
  Failed: "text-deny",
  Lost: "text-confirm",
};

const namespaces = computed(() => (info.value?.instance?.namespaces ?? []).map((n) => n.name));

// ponytail: naive semver compare
const parts = (v) => (String(v).split("+")[0].split("-")[0].match(/\d+/g) ?? []).map(Number);
function newer(a, b) {
  const [x, y] = [parts(a), parts(b)];
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) > (y[i] ?? 0);
  }
  return !String(a).includes("-") && String(b).includes("-");
}

const published = computed(() => new Map(available.value.map((p) => [p.name, p])));
const left = computed(() =>
  installed.value.map((mod) => {
    const m = { ...mod, key: `${mod.name}@${mod.namespace}` };
    const latest = published.value.get(m.name)?.version ?? "";
    if (latest && newer(latest, m.version))
      return {
        ...m,
        behind: true,
        mark: latest,
        why: `Installed ${m.version}, the registry publishes ${latest}.`,
      };
    if (latest) return { ...m, mark: "current", why: "The registry publishes the version that is installed here." };
    if (state.value.available === "ready")
      return { ...m, mark: "unlisted", why: "The community registry does not publish a package under this name." };
    return { ...m, mark: "-", why: "The registry did not answer, so nothing is known about newer versions." };
  }),
);

const here = computed(() => {
  const byName = new Map();
  for (const m of left.value) byName.set(m.name, [...(byName.get(m.name) ?? []), m]);
  return byName;
});

const right = computed(() =>
  available.value.map((p) => {
    const mine = here.value.get(p.name) ?? [];
    return { ...p, installed: mine.map((m) => m.version).join(", ") };
  }),
);

const behind = computed(() => left.value.filter((m) => m.behind).length);

const scope = inject("scope", ref(""));
const onlyBehind = ref(false);
const shownInstalled = computed(() =>
  match(left.value).filter(
    (m) => (!scope.value || m.namespace === scope.value) && (!onlyBehind.value || !behind.value || m.behind),
  ),
);
const loading = computed(() => Object.values(state.value).includes("loading"));

const pkg = computed(() => selected.value.split("@")[0]);

const match = (rows) => {
  const q = filter.value.trim().toLowerCase();
  return q
    ? rows.filter((r) => `${r.name} ${r.namespace ?? ""} ${r.description ?? ""}`.toLowerCase().includes(q))
    : rows;
};

const nothing = (what) => ({ title: "No package matches", hint: `Nothing ${what} matches “${filter.value.trim()}”.` });

const emptyInstalled = computed(() => {
  if (filter.value.trim()) return nothing("installed here");
  if (scope.value || onlyBehind.value)
    return {
      title: "No package matches",
      hint: "Nothing installed here fits the namespace in scope or the filter above.",
    };
  if (!ipm.value)
    return {
      title: "No package manager on this instance",
      hint: "No namespace has %IPM.Storage.Module in it, so nothing here was installed by a package manager. That is an ordinary instance, not a broken one; the registry beside it still says what could be installed.",
    };
  return {
    title: "Nothing installed by IPM",
    hint: "IPM is here and its storage is empty: no module has been installed through it in any namespace.",
  };
});

const emptyAvailable = computed(() =>
  filter.value.trim()
    ? nothing("the registry publishes")
    : {
        title: "The registry published nothing",
        hint: "packages.available answered with an empty list. That is a real answer, not a failure.",
      },
);

const installedColumns = [
  { key: "name", label: "Package", class: "max-w-[130px] truncate text-text-bright" },
  { key: "namespace", label: "Namespace", mono: true, class: "text-text-muted" },
  { key: "version", label: "Version", mono: true, class: "max-w-[110px] truncate" },
  { key: "latest", label: "Registry", mono: true },
];

const availableColumns = [
  { key: "name", label: "Package", class: "max-w-[150px] truncate text-text-bright" },
  { key: "version", label: "Latest", mono: true, class: "max-w-[100px] truncate text-text-muted" },
  { key: "description", label: "Description", class: "max-w-[200px] truncate text-text-muted" },
];
</script>

<template>
  <div class="flex shrink-0 items-center gap-2">
    <span v-if="latest" class="inline-flex min-w-0 items-center gap-1.5 text-micro" :class="tone[latest.state]">
      <span class="size-[5px] shrink-0 rounded-badge bg-current" />
      <button class="truncate underline-offset-2 hover:underline" @click="selected = latest.package">
        {{ latest.command }} in {{ latest.namespace }}, {{ latest.state.toLowerCase() }}
      </button>
    </span>
    <FilterField v-model="filter" width="auto" placeholder="Filter packages" />
    <RefreshButton :busy="loading" title="Read what is installed and what the registry publishes again" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      title="INSTALLED"
      :meta="`${shownInstalled.length}${unreadable.length ? ` · ${unreadable.length} ${unreadable.length === 1 ? 'namespace' : 'namespaces'} not readable` : ''}`"
      :meta-title="
        unreadable.length
          ? `This account cannot read the database of ${unreadable.join(', ')}, so packages installed there are not listed.`
          : 'Read from IPM\'s own storage in every namespace on this instance.'
      "
      class="min-w-0 flex-1"
    >
      <template #actions>
        <button
          v-if="behind"
          class="inline-flex h-[22px] items-center gap-1.5 rounded-badge border px-2 text-micro text-confirm transition-colors"
          :class="onlyBehind ? 'border-confirm bg-confirm-soft' : 'border-transparent hover:border-confirm'"
          :title="
            onlyBehind ? 'Show every installed package' : 'Show only the packages the registry has a newer version of'
          "
          @click="onlyBehind = !onlyBehind"
        >
          <span class="size-[5px] rounded-badge bg-current" />{{ behind }} behind the registry
        </button>
      </template>

      <DataTable
        :columns="installedColumns"
        :rows="shownInstalled"
        row-key="key"
        sortable
        selectable
        :selected="selected"
        :state="state.installed"
        :error="error.installed"
        tool="packages.installed"
        :empty="emptyInstalled.title"
        :empty-hint="emptyInstalled.hint"
        @select="selected = $event.key"
        @retry="load"
      >
        <template #version="{ row }">
          <span :class="row.behind ? 'text-confirm' : 'text-text'">{{ row.version }}</span>
        </template>
        <template #latest="{ row }">
          <span :class="row.behind ? 'text-confirm' : 'text-text-muted'" :title="row.why">{{ row.mark }}</span>
        </template>
      </DataTable>
    </Block>

    <Block
      title="COMMUNITY REGISTRY"
      :meta="`${match(right).length}${state.available === 'ready' ? '' : ' · not answering'}`"
      meta-title="GET https://pm.community.intersystems.com/packages/-/all: the only call the portal makes to a machine that is not the operator's."
      class="min-w-0 flex-1"
    >
      <DataTable
        :columns="availableColumns"
        :rows="match(right)"
        row-key="name"
        sortable
        selectable
        :selected="pkg"
        :state="state.available"
        :error="error.available"
        tool="packages.available"
        :empty="emptyAvailable.title"
        :empty-hint="emptyAvailable.hint"
        @select="selected = $event.name"
        @retry="load"
      >
        <template #name="{ row }">
          <span class="inline-flex min-w-0 items-center gap-1.5" :title="row.name">
            <span
              v-if="row.installed"
              class="size-[5px] shrink-0 rounded-badge bg-allow"
              :title="`Installed here: ${row.installed}`"
            />
            <span class="truncate">{{ row.name }}</span>
          </span>
        </template>
        <template #description="{ row }">
          <span :title="row.description">{{ row.description || "-" }}</span>
        </template>
      </DataTable>
    </Block>

    <PackageDetail
      v-if="selected"
      :key="pkg"
      :name="pkg"
      :installed="here.get(pkg) ?? []"
      :registry="published.get(pkg) ?? null"
      :registry-out="state.available !== 'ready'"
      :namespaces="namespaces"
      :blocked="blocked"
      :jobs="jobs"
      @started="follow"
      @close="selected = ''"
    />
  </div>
</template>
