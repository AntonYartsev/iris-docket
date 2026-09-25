<script setup>
import DecisionBadge from "./DecisionBadge.vue";
import FoldedCode from "./FoldedCode.vue";
import Icon from "./Icon.vue";

defineProps({ message: { type: Object, required: true } });
</script>

<template>
  <div class="rounded-card border border-line bg-surface px-2.5 py-2">
    <header class="flex flex-wrap items-center gap-x-2 gap-y-1">
      <Icon name="tools" :size="13" class="text-text-muted" />
      <span class="font-mono text-small text-text-bright">{{ message._tool }}</span>
      <DecisionBadge v-if="message._decision" :decision="message._decision" :rule="message._ruleId" />
      <span v-else class="rounded-badge bg-surface-raised px-2 py-0.5 text-micro text-text-muted">failed</span>
      <span v-if="message._durationMs !== ''" class="text-micro text-text-muted">{{ message._durationMs }} ms</span>
      <RouterLink
        v-if="message._auditId"
        :to="{ path: '/audit', query: { correlationId: message._correlationId } }"
        class="ml-auto font-mono text-micro text-text-muted underline"
        title="this turn in the journal, every call of it"
      >
        audit #{{ message._auditId }}
      </RouterLink>
    </header>

    <div v-if="Object.keys(message._args ?? {}).length" class="mt-1.5 flex flex-wrap gap-1">
      <span
        v-for="(value, key) in message._args"
        :key="key"
        class="max-w-full rounded-tight bg-base px-1.5 py-0.5 font-mono text-micro break-all text-text"
      >
        <span class="text-text-muted">{{ key }}</span> {{ JSON.stringify(value) }}
      </span>
    </div>

    <p v-if="message._error" class="mt-1.5 text-micro text-deny">{{ message._error }}</p>

    <FoldedCode label="What the model was given" :text="message.content" class="mt-1.5" />
  </div>
</template>
