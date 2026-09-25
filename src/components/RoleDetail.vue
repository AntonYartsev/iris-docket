<script setup>
// Resources replaces all, D-20
import { computed, ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import DetailPanel from "./DetailPanel.vue";
import FieldGrid from "./FieldGrid.vue";
import ToolDialog from "./ToolDialog.vue";

const props = defineProps({
  name: { type: String, required: true },
  tool: { type: Object, default: null },
});
const emit = defineEmits(["changed", "close"]);

const { invoke } = useToolInvoke();

const role = ref(null);
const owners = ref([]);
const error = ref("");
const editing = ref(false);

const load = async () => {
  error.value = "";
  try {
    const [r, o] = await Promise.all([
      invoke("security.role.get", { name: props.name }, true),
      invoke("security.role.owners", { name: props.name, maxRows: 1000 }, true),
    ]);
    role.value = r.data;
    owners.value = o.data;
  } catch (e) {
    error.value = e.message;
  }
};
watch(() => props.name, load, { immediate: true });

const facts = computed(() => [
  ["Description", role.value?.Description],
  ["Escalation only", role.value && (role.value.EscalationOnly ? "yes" : "no")],
]);

const preset = computed(() => ({
  name: props.name,
  Description: role.value?.Description,
  EscalationOnly: role.value?.EscalationOnly,
  GrantedRoles: role.value?.GrantedRoles,
  Resources: role.value?.Resources,
}));

const saved = async () => {
  emit("changed");
  await load();
};

const heading = "mb-1.5 flex text-micro tracking-[0.04em] text-text-muted";
</script>

<template>
  <DetailPanel title="ROLE" :subject="name" class="!w-[420px]" @close="emit('close')">
    <div class="border-b border-line px-2.5 py-[9px]">
      <p v-if="error" class="text-micro text-deny">{{ error }}</p>
      <FieldGrid v-else :rows="facts" label-width="110px" />
      <button
        :disabled="!role || !tool"
        class="mt-2 h-[var(--size-btn)] rounded-control border border-line-strong px-[11px] text-small text-text transition-colors hover:bg-surface-raised disabled:cursor-not-allowed disabled:opacity-40"
        @click="editing = true"
      >
        Edit
      </button>
    </div>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div :class="heading">
        RESOURCES<span class="ml-auto tracking-normal">{{ role?.Resources?.length ?? 0 }}</span>
      </div>
      <div v-for="r in role?.Resources ?? []" :key="r.Name" class="flex gap-2 py-px font-mono text-micro">
        <span class="min-w-0 flex-1 truncate text-text">{{ r.Name }}</span>
        <span class="text-text-muted">{{ r.Permissions }}</span>
      </div>
      <p v-if="role && !role.Resources?.length" class="text-micro text-text-muted">Grants no resources.</p>
    </div>

    <div class="border-b border-line px-2.5 py-[9px]">
      <div :class="heading">
        GRANTED ROLES<span class="ml-auto tracking-normal">{{ role?.GrantedRoles?.length ?? 0 }}</span>
      </div>
      <div v-for="g in role?.GrantedRoles ?? []" :key="g" class="py-px font-mono text-micro text-text">{{ g }}</div>
      <p v-if="role && !role.GrantedRoles?.length" class="text-micro text-text-muted">Carries no other roles.</p>
    </div>

    <div class="px-2.5 py-[9px]">
      <div :class="heading">
        HELD BY<span class="ml-auto tracking-normal">{{ owners.length }}</span>
      </div>
      <div v-for="o in owners" :key="`${o.Type}:${o.Name}`" class="flex gap-2 py-px text-micro">
        <span class="min-w-0 flex-1 truncate font-mono text-text">{{ o.Name }}</span>
        <span class="text-text-muted">{{ o.Type === "Role" ? "role" : "user" }}</span>
      </div>
      <p v-if="role && !owners.length" class="text-micro text-text-muted">No user or role holds it directly.</p>
    </div>
  </DetailPanel>

  <ToolDialog :tool="editing ? tool : null" :preset="preset" @close="editing = false" @done="saved" />
</template>
