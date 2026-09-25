<script setup>
import { ref, computed } from "vue";
import { t } from "../composables/useI18n";
import { useToolInvoke } from "../composables/useToolInvoke";
import Block from "./Block.vue";
import DataTable from "./DataTable.vue";
import DecisionBadge from "./DecisionBadge.vue";

const props = defineProps({
  config: { type: Object, required: true },
  versions: { type: Array, default: () => [] },
  pending: Boolean,
  error: { type: String, default: "" },
});
const emit = defineEmits(["saved"]);

const { invoke } = useToolInvoke();

const editing = ref(false);
const draft = ref("");
const problems = ref([]);
const busy = ref(false);

const columns = computed(() => [
  {
    key: "order",
    label: t("policy.col.order"),
    mono: true,
    right: true,
    class: "text-text-muted",
    width: "42px",
  },
  {
    key: "id",
    label: t("policy.col.rule"),
    mono: true,
    class: "text-text-bright",
  },
  {
    key: "match",
    label: t("policy.col.match"),
    mono: true,
    class: "text-text-muted",
  },
  { key: "decision", label: t("policy.col.decision") },
]);

const rows = computed(() => (props.config.rules ?? []).map((r, i) => ({ ...r, order: i + 1 })));

const earlier = computed(() =>
  props.versions
    .filter((v) => String(v.version) !== String(props.config.version))
    .slice(-3)
    .reverse(),
);

const defaultTone = {
  allow: "text-allow",
  confirm: "text-confirm",
  deny: "text-deny",
};

const pair = (match) =>
  Object.entries(match ?? {}).map(([k, v]) => `${k} = ${typeof v === "string" ? v : JSON.stringify(v)}`);

function open(config) {
  draft.value = JSON.stringify(config, null, 2);
  problems.value = [];
  editing.value = true;
}

async function save() {
  let config;
  try {
    config = JSON.parse(draft.value);
  } catch (e) {
    problems.value = [t("policy.badJson", { message: e.message })];
    return;
  }
  busy.value = true;
  try {
    const check = await invoke("policy.validate", { config }, true);
    problems.value = check.data.problems;
    if (!check.data.ok) return;
    if (await invoke("policy.update", { config })) {
      editing.value = false;
      emit("saved");
    }
  } catch (e) {
    problems.value = [e.message];
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <Block
    :title="t('policy.rules')"
    :meta="t('policy.rules.meta', { version: config.version, n: rows.length })"
    :meta-title="t('policy.rules.metaTitle')"
    class="flex-1"
  >
    <template #actions>
      <span class="text-micro text-text-muted">
        {{ t("policy.unmatched") }}
        <span class="font-mono" :class="defaultTone[config.default]">{{ config.default }}</span>
      </span>
      <button
        v-if="!editing"
        class="h-[22px] rounded-control border border-line-strong px-2 text-micro text-text transition-colors hover:bg-surface-raised"
        @click="open(config)"
      >
        {{ t("policy.edit") }}
      </button>
    </template>

    <template v-if="editing">
      <div class="min-h-0 flex-1 overflow-hidden p-2.5">
        <textarea
          v-model="draft"
          spellcheck="false"
          class="h-full w-full resize-none rounded-control border border-line-strong bg-base p-2 font-mono text-micro text-text"
        />
      </div>
      <div class="shrink-0 border-t border-line bg-inset p-1.5">
        <ul v-if="problems.length" class="mb-1.5 grid gap-0.5 text-micro text-deny">
          <li v-for="p in problems" :key="p">{{ p }}</li>
        </ul>
        <div class="flex justify-end gap-1.5">
          <button
            class="h-[var(--size-btn)] rounded-control border border-line-strong px-3 text-small text-text transition-colors hover:bg-surface-raised"
            @click="editing = false"
          >
            {{ t("policy.cancel") }}
          </button>
          <button
            :disabled="busy"
            class="h-[var(--size-btn)] rounded-control bg-accent px-3 text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-50"
            @click="save"
          >
            {{ busy ? t("policy.saving") : t("policy.save") }}
          </button>
        </div>
      </div>
    </template>

    <DataTable
      v-else
      :columns="columns"
      :rows="rows"
      row-key="id"
      :state="pending ? 'loading' : error ? 'error' : 'ready'"
      :error="error"
      tool="/portal/api/policy"
      :empty="t('policy.noRules')"
      :empty-hint="t('policy.noRulesHint')"
    >
      <template #match="{ row }">
        <span v-for="(m, i) in pair(row.match)" :key="m">
          <span v-if="i" class="mx-1.5 text-text-dim">·</span>{{ m }}
        </span>
        <span v-if="!pair(row.match).length" class="text-text-muted">{{ t("policy.anything") }}</span>
      </template>
      <template #decision="{ row }">
        <DecisionBadge :decision="row.decision" />
      </template>
    </DataTable>

    <template v-if="earlier.length" #footer>
      <span class="shrink-0">{{ t("policy.versions") }}</span>
      <button
        v-for="v in earlier"
        :key="v.version"
        class="shrink-0 font-mono underline transition-colors hover:text-text"
        :title="t('policy.versionTitle', { at: v.savedAt, by: v.savedBy })"
        @click="open(v.config)"
      >
        v{{ v.version }}
      </button>
    </template>
  </Block>
</template>
