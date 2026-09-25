<script setup>
import AgentCall from "./AgentCall.vue";
import AgentConfirm from "./AgentConfirm.vue";
import Icon from "./Icon.vue";
import Markdown from "./Markdown.vue";

defineProps({
  entry: { type: Object, required: true },
  pending: { type: Object, default: null },
  busy: Boolean,
});
defineEmits(["confirm", "decline"]);
</script>

<template>
  <div class="flex gap-2.5">
    <span class="flex w-6 shrink-0 justify-center">
      <span
        v-if="entry.first"
        class="flex size-6 items-center justify-center rounded-badge border border-line-strong bg-surface text-text-muted"
      >
        <Icon name="bot" :size="14" />
      </span>
    </span>
    <div class="min-w-0 flex-1">
      <Markdown v-if="entry.role === 'assistant'" :text="entry.content" class="pt-0.5 text-small text-text" />
      <AgentCall v-else-if="entry.role === 'tool'" :message="entry" />
      <AgentConfirm
        v-else-if="entry.role === 'confirm'"
        :pending="pending"
        :busy="busy"
        @confirm="$emit('confirm')"
        @decline="$emit('decline')"
      />
      <p v-else-if="entry.role === 'working'" class="flex h-6 items-center gap-1.5 text-micro text-text-muted">
        Working
        <span
          v-for="d in 3"
          :key="d"
          class="size-1 rounded-badge bg-current motion-safe:animate-pulse"
          :style="{ animationDelay: `${d * 200}ms` }"
        />
      </p>
      <p v-else class="pt-1 text-micro text-text-muted italic">{{ entry.content }}</p>
    </div>
  </div>
</template>
