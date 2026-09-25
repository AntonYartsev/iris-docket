<script setup>
import DecisionBadge from "./DecisionBadge.vue";

defineProps({ pending: { type: Object, required: true }, busy: Boolean });
defineEmits(["confirm", "decline"]);
</script>

<template>
  <div class="rounded-card border border-confirm bg-surface px-2.5 py-2">
    <header class="flex flex-wrap items-center gap-x-2 gap-y-1">
      <span class="font-mono text-small text-text-bright">{{ pending.tool }}</span>
      <DecisionBadge decision="confirm" :rule="pending.ruleId" />
    </header>
    <p class="mt-1 text-micro text-text-muted">The agent asked for this and stopped. Nothing has run.</p>

    <div v-if="Object.keys(pending.args ?? {}).length" class="mt-1.5 flex flex-wrap gap-1">
      <span
        v-for="(value, key) in pending.args"
        :key="key"
        class="max-w-full rounded-tight bg-base px-1.5 py-0.5 font-mono text-micro break-all text-text"
      >
        <span class="text-text-muted">{{ key }}</span> {{ JSON.stringify(value) }}
      </span>
    </div>

    <div class="mt-2 flex justify-end gap-1.5">
      <button
        :disabled="busy"
        class="h-[var(--size-field)] rounded-control border border-line-strong px-3 text-small text-text transition-colors hover:bg-surface-raised disabled:opacity-50"
        @click="$emit('decline')"
      >
        No
      </button>
      <button
        :disabled="busy"
        class="h-[var(--size-field)] rounded-control bg-accent px-3 text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-50"
        @click="$emit('confirm')"
      >
        Run it
      </button>
    </div>
  </div>
</template>
