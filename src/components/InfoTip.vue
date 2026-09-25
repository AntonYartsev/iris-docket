<script setup>
import { ref, useId } from "vue";
import Icon from "./Icon.vue";

defineProps({
  title: { type: String, required: true },
});

const id = useId();
const open = ref(false);
const button = ref(null);

const place = (e) => {
  if (e.newState !== "open") return;
  const r = button.value.getBoundingClientRect();
  Object.assign(e.target.style, { top: `${r.bottom + 6}px`, right: `${innerWidth - r.right}px` });
};
</script>

<template>
  <button
    ref="button"
    :popovertarget="id"
    :title="title"
    class="flex size-[var(--size-btn)] shrink-0 items-center justify-center rounded-control border border-line-strong text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
    :class="open && 'bg-surface-raised text-text'"
  >
    <Icon name="info" />
  </button>
  <div
    :id="id"
    popover
    class="inset-auto m-0 w-[340px] space-y-1.5 rounded-card border border-line-strong bg-surface p-2.5 text-micro text-text-muted shadow-overlay"
    @beforetoggle="place"
    @toggle="open = $event.newState === 'open'"
  >
    <slot />
  </div>
</template>
