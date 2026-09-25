<script setup>
import { ref, computed, watch } from "vue";
import { api } from "../composables/useApi";
import { t } from "../composables/useI18n";
import Block from "./Block.vue";
import DecisionBadge from "./DecisionBadge.vue";
import FieldGrid from "./FieldGrid.vue";
import SchemaForm from "./SchemaForm.vue";

const props = defineProps({ tools: { type: Array, default: () => [] } });

const name = ref("");
const args = ref({});
const actor = ref("");
const channel = ref("ui");
const result = ref(null);
const error = ref("");

const tool = computed(() => props.tools.find((op) => op.name === name.value));
watch(name, () => ((args.value = {}), (result.value = null)));

const tone = {
  allow: "border-allow text-allow bg-allow-soft",
  confirm: "border-confirm text-confirm bg-confirm-soft",
  deny: "border-deny text-deny bg-deny-soft",
};

async function run() {
  error.value = "";
  result.value = null;
  try {
    const body = { tool: name.value, args: args.value, channel: channel.value };
    if (actor.value) body.actor = actor.value;
    result.value = (await api("/policy/simulate", body)).data;
  } catch (e) {
    error.value = e.message;
  }
}
</script>

<template>
  <Block
    :title="t('sim.block')"
    :meta="t('sim.meta')"
    :meta-title="t('sim.metaTitle')"
    class="w-[340px] shrink-0"
    :scroll="false"
  >
    <div class="border-b border-line px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">
        {{ t("sim.call") }}
      </div>

      <select
        v-model="name"
        class="h-[var(--size-field)] w-full rounded-control border border-line-strong bg-base px-2 font-mono text-micro text-text"
      >
        <option value="">{{ t("sim.pick") }}</option>
        <option v-for="op in tools" :key="op.name" :value="op.name">
          {{ op.name }}{{ op.mutating ? t("sim.writes") : "" }}
        </option>
      </select>

      <div class="mt-1.5 grid grid-cols-2 gap-1.5">
        <select
          v-model="actor"
          :title="t('sim.actorTitle')"
          class="h-[var(--size-field)] min-w-0 rounded-control border border-line-strong bg-base px-2 text-micro text-text"
        >
          <option value="">{{ t("sim.me") }}</option>
          <option value="agent:demo">agent:demo</option>
          <option value="script:ci">script:ci</option>
        </select>
        <select
          v-model="channel"
          :title="t('sim.channelTitle')"
          class="h-[var(--size-field)] min-w-0 rounded-control border border-line-strong bg-base px-2 text-micro text-text"
        >
          <option value="ui">ui</option>
          <option value="agent:demo">agent:demo</option>
          <option value="script">script</option>
        </select>
      </div>

      <div v-if="tool" class="mt-2">
        <p class="mb-1.5 text-micro text-text-muted">{{ t("sim.args") }}</p>
        <div class="max-h-[180px] overflow-y-auto pr-1">
          <SchemaForm v-model="args" :schema="tool.schema" />
        </div>
      </div>

      <button
        :disabled="!name"
        class="mt-2 h-[var(--size-btn)] w-full rounded-control bg-accent text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-40"
        @click="run"
      >
        {{ t("sim.ask") }}
      </button>
    </div>

    <div class="px-2.5 py-[9px]">
      <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">
        {{ t("sim.answer") }}
      </div>

      <p v-if="error" class="text-micro text-deny">{{ error }}</p>
      <p v-else-if="!result" class="text-micro text-text-muted">
        {{ t("sim.idle") }}
      </p>

      <template v-else>
        <div class="rounded-control border p-2" :class="tone[result.decision]">
          <DecisionBadge :decision="result.decision" filled />
          <p class="mt-1.5 text-micro text-text">
            {{ t(`sim.says.${result.decision}`) }}
          </p>
        </div>

        <div class="mt-2">
          <FieldGrid
            :rows="[
              ['rule', result.ruleId === 'default' ? t('sim.default') : result.ruleId],
              ['tool', result.tool],
              ['actor', result.actor],
              ['writes', result.mutating ? 'yes' : 'no'],
            ]"
            label-width="64px"
          />
        </div>
      </template>
    </div>
  </Block>
</template>
