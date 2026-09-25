<script setup>
import Icon from "./Icon.vue";

defineProps({ mock: Boolean });
</script>

<template>
  <div class="flex h-full flex-col items-center justify-center gap-2 px-6 text-center">
    <Icon name="bot" :size="28" class="text-text-muted" />
    <p class="max-w-[440px] text-small text-text-muted">
      Ask about this instance. The agent can only call the operations on the Tools screen, the policy decides each of
      them, and every one lands in the journal beside yours.
    </p>
    <p v-if="mock" class="max-w-[440px] text-micro text-text-muted">
      No model behind it: <code>LLM_MODE</code> is not <code>live</code>, or there is no
      <code>OPENROUTER_API_KEY</code>. The prompts below walk a recorded scenario, and every call in it goes through the
      same policy and into the same journal as one from a button. Set both and the console asks a real model instead;
      nothing else about it changes.
    </p>
  </div>
</template>
