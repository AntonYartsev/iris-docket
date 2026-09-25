<script setup>
defineProps({
  decision: { type: String, required: true },
  rule: { type: String, default: "" },
  filled: { type: Boolean, default: false },
});

const line = {
  allow: "border-allow text-allow",
  confirm: "border-confirm text-confirm",
  deny: "border-deny text-deny",
};
const fill = {
  allow: "bg-allow-soft",
  confirm: "bg-confirm-soft",
  deny: "bg-deny-soft",
};
</script>

<template>
  <span class="inline-flex items-center gap-1.5">
    <span
      class="inline-flex h-5 items-center gap-1.5 rounded-badge border px-[7px] text-micro font-medium"
      :class="[line[decision] ?? 'border-line-strong text-text-muted', filled && fill[decision]]"
    >
      <span class="size-[5px] rounded-badge bg-current" />{{ decision }}
    </span>
    <span v-if="rule" class="font-mono text-micro text-text-muted">{{ rule }}</span>
  </span>
</template>
