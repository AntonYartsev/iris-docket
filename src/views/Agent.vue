<script setup>
import { ref, shallowRef } from "vue";
import { api } from "../composables/useApi";
import AgentConsole from "../components/AgentConsole.vue";
import AgentSessions from "../components/AgentSessions.vue";

const console_ = ref(null);
const sessions = shallowRef([]);

async function listSessions() {
  try {
    sessions.value = (await api("/agent/sessions")).data.sort((a, b) =>
      (b.updatedAt ?? "").localeCompare(a.updatedAt ?? ""),
    );
  } catch {
    sessions.value = [];
  }
}
listSessions();
</script>

<template>
  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <AgentSessions
      :sessions="sessions"
      :current="console_?.state?.sessionId ?? ''"
      @open="console_.open($event)"
      @remove="console_.remove($event)"
    />

    <AgentConsole ref="console_" @turn="listSessions" />
  </div>
</template>
