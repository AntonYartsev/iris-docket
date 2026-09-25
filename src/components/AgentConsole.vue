<script setup>
import { computed, nextTick, onMounted, ref } from "vue";
import { api } from "../composables/useApi";
import { useToolInvoke } from "../composables/useToolInvoke";
import { agentBusy as busy } from "../composables/useShell";
import Block from "./Block.vue";
import AgentEntry from "./AgentEntry.vue";
import AgentIntro from "./AgentIntro.vue";

const emit = defineEmits(["turn"]);

const KEY = "portal.agent.session";

const { invoke } = useToolInvoke();

const state = ref(null);
const draft = ref("");
const error = ref(null);
const feed = ref(null);
const sent = ref("");
const turning = ref(false);

const scroll = async () => {
  await nextTick();
  feed.value?.scrollTo({ top: feed.value.scrollHeight, behavior: "smooth" });
};

async function run(load, message = "", isTurn = false) {
  busy.value = true;
  turning.value = isTurn;
  error.value = null;
  sent.value = message;
  scroll();
  try {
    state.value = (await load()).data;
    sessionStorage.setItem(KEY, state.value.sessionId);
  } catch (e) {
    error.value = e;
    if (message) draft.value = message;
  } finally {
    busy.value = false;
    turning.value = false;
    sent.value = "";
    emit("turn");
    scroll();
  }
}

const turn = (body) =>
  run(() => api("/agent/turn", { sessionId: state.value?.sessionId, ...body }), body.message, true);
const load = (id) => run(() => api(id ? `/agent/session/${encodeURIComponent(id)}` : "/agent/session"));

function start() {
  sessionStorage.removeItem(KEY);
  load(null);
}

async function remove(id) {
  if (!(await invoke("agent.session.delete", { sessionId: id }))) return;
  if (id === state.value?.sessionId) start();
  else emit("turn");
}

function send() {
  const message = draft.value.trim();
  if (!message || busy.value) return;
  draft.value = "";
  turn({ message });
}

onMounted(() => load(sessionStorage.getItem(KEY)));

defineExpose({
  open: (id) => id !== state.value?.sessionId && load(id),
  start,
  remove,
  state,
});

const stoppedFor = {
  steps: "the model went round too many times",
  calls: "too many tool calls in one turn",
  time: "the turn ran out of time",
  provider: "the model provider did not answer",
};

const items = computed(() => {
  const list = (state.value?.messages ?? []).filter((m) => m.role !== "assistant" || m.content);
  if (sent.value) list.push({ role: "user", content: sent.value });
  if (state.value?.pending) list.push({ role: "confirm" });
  if (turning.value) list.push({ role: "working" });
  else if (!busy.value && stoppedFor[state.value?.stopped])
    list.push({ role: "note", content: `Stopped: ${stoppedFor[state.value.stopped]}.` });
  return list.map((m, i) => ({ ...m, first: m.role !== "user" && (i === 0 || list[i - 1].role === "user") }));
});
</script>

<template>
  <Block
    title="AGENT"
    :meta="state ? `${state.mode} · ${state.model}` : 'starting…'"
    meta-title="LLM_MODE decides this. In mock the scenario is recorded and no key exists anywhere; in live the key comes from the environment and never reaches the browser."
    class="min-w-0 flex-1"
  >
    <template #actions>
      <button
        class="h-[22px] rounded-control border border-line-strong px-2 text-micro text-text-muted transition-colors hover:bg-surface-raised hover:text-text"
        title="Start a fresh conversation; this one stays in the list"
        @click="start"
      >
        New conversation
      </button>
    </template>

    <p v-if="error" class="shrink-0 border-b border-line bg-deny-soft px-2.5 py-1 text-micro text-deny">
      {{ error.message }}
    </p>

    <div ref="feed" class="min-h-0 flex-1 space-y-2.5 overflow-y-auto p-3">
      <AgentIntro v-if="!items.length" :mock="state?.mode === 'mock'" />

      <template v-for="(m, i) in items" :key="i">
        <div v-if="m.role === 'user'" class="flex justify-end pt-1">
          <p
            class="max-w-[80%] rounded-card rounded-br-tight bg-accent-soft px-3 py-2 text-small whitespace-pre-wrap text-text-bright"
          >
            {{ m.content }}
          </p>
        </div>

        <AgentEntry
          v-else
          :entry="m"
          :pending="state?.pending"
          :busy="busy"
          @confirm="turn({ confirmToken: state.pending.confirmToken })"
          @decline="turn({ decline: true })"
        />
      </template>
    </div>

    <div class="shrink-0 border-t border-line bg-inset p-1.5">
      <div v-if="state?.prompts?.length" class="mb-1.5 flex flex-wrap gap-1.5">
        <button
          v-for="p in state.prompts"
          :key="p"
          :disabled="busy"
          class="h-[22px] rounded-badge border border-line-strong px-2 text-micro text-text-muted transition-colors hover:bg-surface-raised hover:text-text disabled:opacity-50"
          @click="((draft = p), send())"
        >
          {{ p }}
        </button>
      </div>

      <form class="flex gap-1.5" @submit.prevent="send">
        <input
          v-model="draft"
          :disabled="busy || !!state?.pending"
          :placeholder="state?.pending ? 'Answer the confirmation above first' : 'Ask about this instance…'"
          class="h-[var(--size-field)] min-w-0 flex-1 rounded-control border border-line-strong bg-base px-2 text-small text-text placeholder:text-text-muted disabled:opacity-50"
        />
        <button
          type="submit"
          :disabled="busy || !draft.trim()"
          class="h-[var(--size-field)] shrink-0 rounded-control bg-accent px-3 text-small font-semibold text-text-bright shadow-edge transition-colors hover:bg-accent-hover disabled:opacity-50"
        >
          Send
        </button>
      </form>
    </div>
  </Block>
</template>
