<script setup>
import { onMounted, onUnmounted, provide, ref, watch } from "vue";
import { info, startShell } from "./composables/useShell";
import { stored } from "./composables/useStored";
import { useToolInvoke } from "./composables/useToolInvoke";
import { useResource, api } from "./composables/useApi";
import LoginCard from "./components/LoginCard.vue";
import ConfirmDialog from "./components/ConfirmDialog.vue";
import TopRibbon from "./components/TopRibbon.vue";
import NavRail from "./components/NavRail.vue";
import CommandPalette from "./components/CommandPalette.vue";

const { data: whoami, error, reload } = useResource(() => api("/info"));
watch(whoami, (v) => v && startShell());

const navShut = stored("navShut", false);
const palette = ref(false);

const scope = stored("scope", "");
provide("scope", scope);
watch(info, (v) => {
  if (v && scope.value && !v.instance?.namespaces?.some((n) => n.name === scope.value)) scope.value = "";
});

const keys = (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
    e.preventDefault();
    palette.value = !palette.value;
  }
};
onMounted(() => window.addEventListener("keydown", keys));
onUnmounted(() => window.removeEventListener("keydown", keys));

const { toast, dismiss } = useToolInvoke();
watch(toast, (t) => t && setTimeout(() => toast.value === t && dismiss(), 6000));

const tone = {
  allow: "border-allow text-allow",
  confirm: "border-confirm text-confirm",
  deny: "border-deny text-deny",
};

const signOut = async () => {
  await api("/logout", {}).catch(() => {});
  location.reload();
};
</script>

<template>
  <LoginCard v-if="error?.code === 'unauthorized'" @signed-in="reload" />

  <div
    v-else
    class="grid h-screen overflow-hidden bg-base"
    style="grid-template-rows: var(--size-ribbon) minmax(0, 1fr)"
  >
    <TopRibbon v-model:scope="scope" :nav-shut="navShut" @palette="palette = true" @sign-out="signOut" />

    <div class="flex min-h-0 min-w-0">
      <NavRail v-model:shut="navShut" />

      <main class="flex min-h-0 min-w-0 flex-1 flex-col gap-panel overflow-hidden p-zone">
        <RouterView />
      </main>
    </div>

    <ConfirmDialog />
    <CommandPalette v-model:open="palette" />

    <div
      v-if="toast"
      class="fixed right-4 bottom-4 z-50 max-w-sm rounded-card border bg-surface px-3 py-2 text-small shadow-overlay"
      :class="tone[toast.tone]"
      @click="dismiss"
    >
      {{ toast.text }}
      <RouterLink v-if="toast.auditId" to="/audit" class="ml-2 font-mono text-micro text-text-muted underline">
        audit #{{ toast.auditId }}
      </RouterLink>
    </div>
  </div>
</template>
