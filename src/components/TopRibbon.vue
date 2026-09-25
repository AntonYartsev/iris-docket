<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import { info } from "../composables/useShell";
import { t } from "../composables/useI18n";
import Icon from "./Icon.vue";

const emit = defineEmits(["palette", "sign-out"]);
defineProps({ navShut: { type: Boolean, default: false } });
const scope = defineModel("scope", { type: String, default: "" });

const route = useRoute();

const SCOPED = ["/system", "/interop", "/packages"];
const usable = computed(() => SCOPED.includes(route.path));
const namespaces = computed(() => (info.value?.instance?.namespaces ?? []).map((n) => n.name));

const mode = computed(() => info.value?.instance?.systemMode ?? "");
const modeTone = computed(
  () =>
    ({ LIVE: "border-confirm text-confirm", FAILOVER: "border-deny text-deny" })[mode.value] ??
    "border-line-strong text-text",
);
</script>

<template>
  <header class="flex min-w-0 items-center border-b border-line bg-inset pr-3">
    <div
      data-zone="brand"
      :data-shut="navShut ? '1' : '0'"
      class="flex h-full shrink-0 items-center gap-2 border-r border-line bg-surface pl-[15px]"
    >
      <span class="grid shrink-0 grid-cols-2 gap-[2px]">
        <i v-for="i in 4" :key="i" class="block size-[6px] rounded-[1.5px] bg-accent" />
      </span>
      <span data-nav-label class="text-small font-semibold text-text-bright">Docket</span>
    </div>

    <button
      class="ml-[var(--spacing-zone)] flex h-7 w-[440px] min-w-0 shrink items-center gap-2 rounded-control border border-line-strong bg-surface px-[9px] text-left transition-colors hover:border-accent"
      @click="emit('palette')"
    >
      <Icon name="search" :size="14" class="text-text-muted" />
      <span class="min-w-0 flex-1 truncate text-micro text-text-muted">{{ t("ribbon.search") }}</span>
      <kbd
        class="inline-flex h-[17px] shrink-0 items-center rounded-tight border border-line-strong px-[5px] font-sans text-micro leading-none text-text-muted"
        >⌘K</kbd
      >
    </button>

    <div v-if="usable" class="relative ml-2 flex shrink-0 items-center">
      <select
        v-model="scope"
        :title="t('ribbon.scope.usable')"
        class="h-6 cursor-pointer appearance-none rounded-tight border border-line-strong bg-transparent py-0 pr-[22px] pl-[7px] font-mono text-micro text-text-bright transition-colors hover:bg-surface"
      >
        <option value="">{{ t("ribbon.allNs") }}</option>
        <option v-for="n in namespaces" :key="n" :value="n">{{ n }}</option>
      </select>
      <Icon name="chevron" :size="10" class="pointer-events-none absolute right-[6px] text-text-bright opacity-60" />
    </div>

    <div class="ml-auto flex shrink-0 items-center gap-2.5 pl-3">
      <span
        v-if="mode"
        class="inline-flex h-5 items-center rounded-badge border px-[7px] font-mono text-micro"
        :class="modeTone"
      >
        {{ mode }}
      </span>
      <span class="font-mono text-micro whitespace-nowrap text-text-bright">{{ info?.user ?? "" }}</span>
      <button
        class="flex size-[26px] items-center justify-center rounded-control border border-line-strong text-text-muted transition-colors hover:bg-surface hover:text-text-bright"
        :title="t('ribbon.signOut')"
        @click="emit('sign-out')"
      >
        <Icon name="signout" :size="15" />
      </button>
    </div>
  </header>
</template>
