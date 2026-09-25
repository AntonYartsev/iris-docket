<script setup>
import { computed, ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import DataTable from "./DataTable.vue";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";

const props = defineProps({
  username: { type: String, required: true },
  roles: { type: Array, default: () => [] },
});
const emit = defineEmits(["changed", "close"]);

const { invoke } = useToolInvoke();

const user = ref(null);
const effective = ref(null);
const error = ref("");
const toGrant = ref("");

const load = async () => {
  error.value = "";
  user.value = null;
  effective.value = null;
  try {
    const [u, e] = await Promise.all([
      invoke("security.user.get", { name: props.username }, true),
      invoke("security.user.effective", { username: props.username }, true),
    ]);
    user.value = u.data;
    effective.value = e.data;
  } catch (e) {
    error.value = e.message;
  }
};
watch(() => props.username, load, { immediate: true });

const held = computed(() => new Set(user.value?.Roles ?? []));
const grantable = computed(() => props.roles.map((r) => r.Name).filter((n) => !held.value.has(n)));

const change = async (tool, role) => {
  if (!role) return;
  if (await invoke(tool, { username: props.username, role })) {
    emit("changed");
    await load();
  }
};

const facts = computed(() => [
  ["Full name", user.value?.FullName],
  ["Enabled", user.value && (user.value.Enabled ? "yes" : "no")],
  ["Namespace", user.value?.NameSpace],
  ["Routine", user.value?.Routine],
  ["Comment", user.value?.Comment],
  ["Expires", user.value?.AccountNeverExpires ? "never" : user.value?.ExpirationDate],
  ["Password expires", user.value?.PasswordNeverExpires ? "never" : user.value?.PasswordChangeDate],
  ["Change on next login", user.value && (user.value.ChangePassword ? "yes" : "no")],
]);

const tree = computed(() =>
  [...(effective.value?.roles ?? [])].sort((a, b) => (a.direct === b.direct ? 0 : a.direct ? -1 : 1)),
);

const columns = [
  { key: "resource", label: "Resource", mono: true, class: "text-text-bright" },
  { key: "permissions", label: "Permissions", mono: true },
  { key: "via", label: "Through", class: "text-text-muted" },
];
</script>

<template>
  <DetailPanel title="ACCOUNT" :subject="username" class="!w-[420px]" @close="emit('close')">
    <div class="border-b border-line px-2.5 py-[9px]">
      <p v-if="error" class="text-micro text-deny">{{ error }}</p>
      <FieldGrid v-else :rows="facts" label-width="130px" />
    </div>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 flex text-micro tracking-[0.04em] text-text-muted">
        ROLES<span class="ml-auto tracking-normal">{{ tree.length }} · direct and nested</span>
      </div>
      <p
        v-if="effective?.superuser"
        class="mb-2 rounded-control border border-confirm bg-confirm-soft px-2 py-1 text-micro text-confirm"
      >
        This account holds %All: every resource, every permission. Nothing below narrows that.
      </p>

      <div v-for="r in tree" :key="r.name" class="flex min-w-0 items-center gap-1.5 py-[3px] text-micro">
        <span v-if="!r.direct" class="font-mono text-text-muted">└</span>
        <span class="min-w-0 flex-1 truncate font-mono text-text" :title="r.description || r.name">{{ r.name }}</span>
        <span class="shrink-0 text-text-muted">{{ r.direct ? "direct" : `nested, depth ${r.depth ?? 1}` }}</span>
        <button
          v-if="r.direct"
          class="shrink-0 text-text-muted transition-colors hover:text-deny"
          :title="`Revoke ${r.name}`"
          @click="change('security.user.revokeRole', r.name)"
        >
          ✕
        </button>
      </div>
      <p v-if="!tree.length && !error" class="text-micro text-text-muted">This account holds no roles.</p>

      <div class="mt-1.5 flex gap-1.5">
        <select
          v-model="toGrant"
          class="h-[var(--size-field)] min-w-0 flex-1 rounded-control border border-line-strong bg-base px-2 font-mono text-micro text-text"
        >
          <option value="">Grant a role…</option>
          <option v-for="role in grantable" :key="role" :value="role">
            {{ role }}
          </option>
        </select>
        <button
          :disabled="!toGrant"
          title="No endpoint on this API grants a role, so this is a read-modify-write: the portal reads the account and writes the whole role list back."
          class="h-[var(--size-field)] shrink-0 rounded-control bg-accent px-2.5 text-micro font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-40"
          @click="(change('security.user.grantRole', toGrant), (toGrant = ''))"
        >
          Grant
        </button>
      </div>
    </div>

    <div class="py-[9px]">
      <div
        class="mb-1.5 flex px-2.5 text-micro tracking-[0.04em] text-text-muted"
        title="GetUserRecursedRoleSet, then one privilege lookup per role. The SysAdmin API has no endpoint that answers this."
      >
        EFFECTIVE PRIVILEGES<span class="ml-auto tracking-normal"
          >{{ (effective?.privileges ?? []).length }} resources</span
        >
      </div>
      <DataTable
        :columns="columns"
        :rows="effective?.privileges ?? []"
        row-key="resource"
        :state="error ? 'error' : effective ? 'ready' : 'loading'"
        :error="error"
        tool="security.user.effective"
        empty="Nothing granted"
        empty-hint="The roles this account holds grant no resource privileges at all."
      >
        <template #via="{ row }">
          <span :title="row.via.join(' → ')">
            {{ row.via.join(", ") }}
            <span class="text-text-dim">· {{ row.via.length > 1 ? `${row.via.length} hops` : "1 hop" }}</span>
          </span>
        </template>
      </DataTable>
    </div>
  </DetailPanel>
</template>
