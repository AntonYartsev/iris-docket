<script setup>
import { agentBusy, badges, info } from "../composables/useShell";
import { t } from "../composables/useI18n";
import { GROUPS } from "../screens";
import Icon from "./Icon.vue";

const shut = defineModel("shut", { type: Boolean, default: false });

const title = (it) =>
  it.to === "/agent"
    ? `${t(it.hint)} · ${t(info?.value?.portal?.agentMode === "live" ? "nav.agent.live" : "nav.agent.mock")}`
    : t(it.hint);

const toneClass = {
  confirm: "bg-confirm-soft text-confirm",
  deny: "bg-deny-soft text-deny",
};
</script>

<template>
  <nav
    data-zone="nav"
    :data-shut="shut ? '1' : '0'"
    class="flex min-h-0 shrink-0 flex-col border-r border-line bg-surface"
  >
    <div data-nav-scroll class="min-h-0 flex-1 overflow-y-auto px-1.5 pt-1.5 pb-2.5">
      <div
        v-for="g in GROUPS"
        :key="g.label"
        class="mt-2 border-t border-line pt-2 first:mt-0 first:border-t-0 first:pt-0"
      >
        <RouterLink
          v-for="it in g.items"
          :key="it.to"
          :to="it.to"
          data-nav-item
          :title="title(it)"
          class="flex h-7 w-full items-center gap-[9px] rounded-control px-2 text-small text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
          active-class="!bg-surface-raised !text-text-bright"
        >
          <Icon :name="it.icon" :class="it.to === '/agent' && agentBusy ? 'text-allow' : ''" />
          <span data-nav-label class="min-w-0 flex-1 truncate">{{ t(it.label) }}</span>
          <span
            v-if="it.badge && badges[it.badge]"
            data-nav-label
            :title="`${badges[it.badge]} ${t(it.window)}`"
            class="min-w-[17px] shrink-0 rounded-badge px-1 text-center text-micro font-medium"
            :class="toneClass[it.tone]"
          >
            {{ badges[it.badge] }}
          </span>
        </RouterLink>
      </div>
    </div>

    <div data-nav-foot class="flex h-[30px] shrink-0 items-center gap-1.5 border-t border-line px-1.5">
      <button
        data-collapse
        class="flex size-[22px] shrink-0 items-center justify-center rounded-tight text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
        :title="shut ? t('nav.expand') : t('nav.collapse')"
        @click="shut = !shut"
      >
        <Icon name="left" :size="14" />
      </button>
    </div>
  </nav>
</template>
