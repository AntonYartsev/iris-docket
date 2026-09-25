<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { useRouter } from "vue-router";
import { api } from "../composables/useApi";
import { tools } from "../composables/useShell";
import { t } from "../composables/useI18n";
import { SCREENS } from "../screens";
import Icon from "./Icon.vue";
import VersionBadge from "./VersionBadge.vue";

const open = defineModel("open", { type: Boolean, default: false });
const router = useRouter();

const q = ref("");
const field = ref(null);
const decisions = shallowRef({});

watch(open, async (isOpen) => {
  if (!isOpen) return;
  q.value = "";
  await Promise.resolve();
  field.value?.focus();
});

const match = (hay) => hay.toLowerCase().includes(q.value.trim().toLowerCase());

const screens = computed(() =>
  q.value ? SCREENS.filter((s) => match(`${t(s.label)} ${t(s.hint)}`)) : SCREENS.slice(0, 5),
);
const ops = computed(() => {
  const all = tools.value ?? [];
  return (q.value ? all.filter((op) => match(`${op.name} ${op.title}`)) : all).slice(0, 40);
});

watch(ops, async (rows) => {
  const wanted = rows.filter((r) => !(r.name in decisions.value)).slice(0, 12);
  if (!wanted.length) return;
  const answers = await Promise.allSettled(wanted.map((r) => api("/policy/simulate", { tool: r.name, args: {} })));
  const next = { ...decisions.value };
  answers.forEach((a, i) => {
    next[wanted[i].name] = a.status === "fulfilled" ? a.value.data.decision : "";
  });
  decisions.value = next;
});

const tone = {
  allow: "border-allow text-allow",
  confirm: "border-confirm text-confirm",
  deny: "border-deny text-deny",
};

function go(to) {
  open.value = false;
  router.push(to);
}

const journal = computed(() => q.value.trim());
</script>

<template>
  <div
    v-if="open"
    role="dialog"
    aria-modal="true"
    class="fixed inset-0 z-60 flex items-start justify-center bg-base/70 px-6 pt-20 pb-6"
    @click="open = false"
    @keydown.esc="open = false"
  >
    <div
      class="w-full max-w-[620px] overflow-hidden rounded-card border border-line-strong bg-surface shadow-overlay"
      @click.stop
    >
      <div class="flex h-11 items-center gap-[9px] border-b border-line px-3">
        <Icon name="search" class="text-text-muted" />
        <input
          ref="field"
          v-model="q"
          :placeholder="t('palette.placeholder')"
          class="min-w-0 flex-1 bg-transparent font-mono text-body outline-none"
          @keydown.esc="open = false"
          @keydown.enter="journal && go(`/audit?q=${encodeURIComponent(journal)}`)"
        />
        <kbd class="rounded-tight border border-line-strong px-[5px] py-px text-micro text-text-muted">esc</kbd>
      </div>

      <div class="max-h-[320px] overflow-y-auto">
        <template v-if="screens.length">
          <div class="flex h-6 items-center bg-inset px-3 text-micro tracking-[0.04em] text-text-muted">
            {{ t("palette.screens") }}
          </div>
          <button
            v-for="s in screens"
            :key="s.to"
            class="flex h-8 w-full min-w-0 items-center gap-[9px] border-b border-line px-3 text-left transition-colors hover:bg-surface-raised"
            @click="go(s.to)"
          >
            <Icon :name="s.icon" class="text-text-muted" />
            <span class="shrink-0 text-small text-text-bright">{{ t(s.label) }}</span>
            <span class="min-w-0 flex-1 truncate text-micro text-text-muted">{{ t(s.hint) }}</span>
          </button>
        </template>

        <template v-if="ops.length">
          <div class="flex h-6 items-center bg-inset px-3 text-micro tracking-[0.04em] text-text-muted">
            {{ t("palette.operations") }}
          </div>
          <button
            v-for="op in ops"
            :key="op.name"
            :title="`${op.method} ${op.path} · requires at least ${op.privilege || 'nothing declared'}`"
            class="flex h-8 w-full min-w-0 items-center gap-[9px] border-b border-line px-3 text-left transition-colors hover:bg-surface-raised"
            @click="go(`/tools?run=${encodeURIComponent(op.name)}`)"
          >
            <span
              class="shrink-0 font-mono text-small"
              :class="op.available === false ? 'text-text-muted' : 'text-text-bright'"
              >{{ op.name }}</span
            >
            <span class="min-w-0 flex-1 truncate text-micro text-text-muted">{{ op.title }}</span>
            <VersionBadge :tool="op" />
            <span
              v-if="decisions[op.name] && op.available !== false"
              class="inline-flex h-5 shrink-0 items-center gap-1.5 rounded-badge border px-[7px] text-micro font-medium"
              :class="tone[decisions[op.name]]"
            >
              <span class="size-[5px] rounded-badge bg-current" />{{ decisions[op.name] }}
            </span>
          </button>
        </template>

        <template v-if="journal">
          <div class="flex h-6 items-center bg-inset px-3 text-micro tracking-[0.04em] text-text-muted">
            {{ t("palette.journal") }}
          </div>
          <button
            class="flex h-8 w-full min-w-0 items-center gap-[9px] px-3 text-left transition-colors hover:bg-surface-raised"
            @click="go(`/audit?q=${encodeURIComponent(journal)}`)"
          >
            <span class="shrink-0 text-small text-text-bright">{{ t("palette.searchJournal") }}</span>
            <span class="min-w-0 flex-1 truncate font-mono text-micro text-text-muted">{{ journal }}</span>
            <span class="shrink-0 font-mono text-micro text-text-muted">/audit?q=</span>
          </button>
        </template>

        <p v-if="!screens.length && !ops.length && !journal" class="px-3 py-4 text-small text-text-muted">
          {{ t("palette.empty") }}
        </p>
      </div>

      <div class="flex items-center gap-2.5 border-t border-line bg-inset px-3 py-[7px] text-micro text-text-muted">
        <span>
          {{ t("palette.footer", { n: tools.length }) }}
          <a href="/portal/api/openapi.json" target="_blank" rel="noreferrer" class="font-mono text-text-muted">
            openapi.json
          </a>
        </span>
        <span class="ml-auto">{{ t("palette.footerRight") }}</span>
      </div>
    </div>
  </div>
</template>
