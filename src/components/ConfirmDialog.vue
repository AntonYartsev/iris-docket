<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { useToolInvoke } from "../composables/useToolInvoke";
import { tools } from "../composables/useShell";
import FoldedCode from "./FoldedCode.vue";
import Icon from "./Icon.vue";

const { pending, confirm, cancel } = useToolInvoke();

const left = ref(0);
let timer;
watch(pending, (p) => {
  clearInterval(timer);
  if (!p) return;
  left.value = p.expiresInSeconds ?? 0;
  timer = setInterval(() => left.value > 0 && left.value--, 1000);
});

const meta = computed(() => tools.value.find((t) => t.name === pending.value?.tool));

const args = computed(() =>
  Object.entries(pending.value?.args ?? {}).map(([k, v]) => [
    k,
    v !== null && typeof v === "object" ? JSON.stringify(v, null, 2) : JSON.stringify(v),
  ]),
);

const curl = computed(() => {
  const m = meta.value;
  if (!m) return "";
  const body = JSON.stringify(pending.value.args);
  return [
    `curl -u USER:PASSWORD -X POST \\`,
    `  ${location.origin}/portal/api/tools/${pending.value.tool}/invoke \\`,
    `  -H 'Content-Type: application/json' \\`,
    `  -d '{"args":${body},"confirmToken":"<the token this dialog holds>"}'`,
  ].join("\n");
});

const onKey = (e) => pending.value && e.key === "Escape" && cancel();
onMounted(() => window.addEventListener("keydown", onKey));
onUnmounted(() => (clearInterval(timer), window.removeEventListener("keydown", onKey)));
</script>

<template>
  <div
    v-if="pending"
    role="dialog"
    aria-modal="true"
    class="fixed inset-0 z-50 flex items-center justify-center bg-base/70 p-6"
    @click.self="cancel"
  >
    <div class="w-full max-w-[560px] overflow-hidden rounded-card border border-line-strong bg-surface shadow-overlay">
      <div class="flex items-center gap-2 border-b border-line bg-confirm-soft px-3 py-[9px]">
        <span
          class="inline-flex h-[22px] items-center gap-1.5 rounded-badge border border-confirm px-2 text-micro font-semibold text-confirm"
        >
          <span class="size-[5px] rounded-badge bg-current" />confirm
        </span>
        <span class="font-mono text-micro text-text">rule {{ pending.ruleId }}</span>
        <span class="ml-auto text-micro text-text-muted">decided by the policy before anything ran</span>
      </div>

      <div class="max-h-[70vh] overflow-y-auto p-3">
        <div class="font-mono text-title text-text-bright">
          {{ pending.tool }}
        </div>
        <p class="mt-1 text-small text-text">The policy asks you to confirm this. Nothing has run yet.</p>

        <div class="mt-2.5 overflow-hidden rounded-control border border-line bg-base">
          <div class="flex h-6 items-center gap-2 border-b border-line px-[9px]">
            <span class="shrink-0 text-micro tracking-[0.04em] whitespace-nowrap text-text-muted">
              CANONICAL ARGUMENTS
            </span>
            <span class="ml-auto text-micro text-text-muted">as the server will run them</span>
          </div>
          <div class="px-[9px] py-[7px]">
            <div v-for="[k, v] in args" :key="k" class="flex min-w-0 gap-[9px] py-px">
              <span class="w-[132px] shrink-0 text-micro text-text-muted">{{ k }}</span>
              <span class="min-w-0 flex-1 font-mono text-micro break-all whitespace-pre-wrap text-text">{{ v }}</span>
            </div>
            <p v-if="!args.length" class="text-micro text-text-muted">no arguments</p>
          </div>
        </div>

        <div class="mt-[9px] flex items-center gap-2 text-micro text-text-muted">
          <Icon name="lock" :size="14" />
          <span>This confirms exactly these arguments, once. The agent cannot confirm for you.</span>
        </div>

        <FoldedCode v-if="curl" label="Same call from a script" :text="curl" class="mt-2.5" />
      </div>

      <div class="flex items-center gap-2 border-t border-line bg-inset px-3 py-2.5">
        <span class="text-micro" :class="left <= 15 ? 'text-confirm' : 'text-text-muted'">
          {{ left > 0 ? `Expires in ${left} s` : "Expired, ask again" }}
        </span>
        <div class="ml-auto flex gap-2">
          <button
            class="h-[var(--size-btn-lg)] rounded-control border border-line-strong px-3.5 text-small font-medium text-text transition-colors hover:bg-surface-raised"
            @click="cancel"
          >
            Cancel
          </button>
          <button
            autofocus
            :disabled="left <= 0"
            class="h-[var(--size-btn-lg)] rounded-control bg-accent px-3.5 text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-50"
            @click="confirm"
          >
            Run it
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
