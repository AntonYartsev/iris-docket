<script setup>
import { ref } from "vue";
import { useCopy } from "../composables/useCopy";
import Icon from "./Icon.vue";

const props = defineProps({
  label: { type: String, required: true },
  text: { type: String, required: true },
});

const pre = ref(null);
const { copied, copy } = useCopy();
</script>

<template>
  <details class="group overflow-hidden rounded-control border border-line bg-base">
    <summary
      class="flex h-7 cursor-pointer list-none items-center gap-1.5 px-[9px] text-micro text-text-muted transition-colors hover:text-text [&::-webkit-details-marker]:hidden"
    >
      <Icon name="chevron" :size="12" class="-rotate-90 transition-transform group-open:rotate-0" />
      {{ label }}
    </summary>
    <div class="max-h-80 overflow-y-auto border-t border-line px-[9px] py-[7px]">
      <button
        class="float-right ml-2 h-[22px] rounded-tight border border-line-strong bg-surface px-2 text-micro text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
        @click="copy(props.text, pre)"
      >
        {{ copied === props.text ? "Copied" : "Copy" }}
      </button>
      <pre ref="pre" class="m-0 text-micro break-all whitespace-pre-wrap text-text">{{ text }}</pre>
    </div>
  </details>
</template>
