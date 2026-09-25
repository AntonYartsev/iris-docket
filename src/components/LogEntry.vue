<script>
export const DOT = {
  info: "bg-text-dim",
  warn: "bg-confirm",
  severe: "bg-deny",
  fatal: "bg-deny shadow-[0_0_0_2px_var(--color-deny-soft)]",
};
</script>

<script setup>
defineProps({
  row: { type: Object, required: true },
  open: Boolean,
});
defineEmits(["toggle"]);

const TEXT = {
  info: "text-text",
  warn: "text-confirm",
  severe: "text-deny",
  fatal: "text-deny",
};
</script>

<template>
  <div
    :class="[row.fresh && 'animate-arrive', open && 'bg-surface-raised']"
    class="flex min-w-0 cursor-pointer items-start gap-2 border-b border-line px-2.5 py-cell-y hover:bg-surface-raised"
    @click="$emit('toggle')"
  >
    <span class="mt-1.5 size-[6px] shrink-0 rounded-badge" :class="DOT[row.level]" />
    <span class="w-[86px] shrink-0 text-text-muted">{{ row.ts?.slice(11, 19) }}</span>
    <span class="w-[74px] shrink-0 text-text-muted">{{ row.source }}</span>
    <span class="w-[46px] shrink-0 text-right text-text-muted">{{ row.process || "-" }}</span>
    <span class="w-[118px] shrink-0 truncate text-text-muted" :title="row.category">{{ row.category || "-" }}</span>
    <span class="min-w-0 flex-1" :class="[TEXT[row.level], open ? 'whitespace-pre-wrap' : 'truncate']">
      {{ row.text }}
      <template v-if="open">
        <span v-if="row.user" class="mt-1 block text-text-muted">
          user {{ row.user }} · namespace {{ row.namespace }} · roles {{ row.roles || "-" }}
        </span>
        <span
          v-if="row.detail"
          class="mt-1 block max-h-64 overflow-auto rounded-control border border-line bg-base p-2 text-text-muted"
          >{{ row.detail }}</span
        >
      </template>
    </span>
  </div>
</template>
