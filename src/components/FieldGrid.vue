<script setup>
defineProps({
  rows: { type: Array, required: true },
  labelWidth: { type: String, default: "116px" },
  columns: { type: Number, default: 1 },
});
</script>

<template>
  <div class="grid gap-x-3" :style="{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }">
    <div v-for="[label, value, full] in rows" :key="label" class="flex min-w-0 gap-2 py-0.5">
      <span class="shrink-0 text-micro text-text-muted" :style="{ width: labelWidth }">{{ label }}</span>
      <span :title="full ?? String(value ?? '')" class="min-w-0 flex-1 truncate font-mono text-micro text-text">
        <slot :name="label" :value="value">{{
          value === "" || value === null || value === undefined ? "-" : value
        }}</slot>
      </span>
    </div>
  </div>
</template>
