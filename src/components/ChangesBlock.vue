<script setup>
import { computed } from "vue";
import { age, events } from "../composables/useShell";
import { t } from "../composables/useI18n";
import Block from "./Block.vue";
import DecisionBadge from "./DecisionBadge.vue";
import Icon from "./Icon.vue";

const TTL = 120_000; // token live 2 min
const TARGET = ["name", "username", "role", "id", "sessionId", "dir", "namespace", "production", "taskId"];

const target = (args = {}) => {
  const k =
    TARGET.find((k) => args[k] !== undefined && args[k] !== "") ??
    Object.keys(args).find((k) => typeof args[k] === "string");
  const v = k ? String(args[k]) : "";
  return v.length > 32 ? `${v.slice(0, 31)}…` : v;
};

const items = computed(() => {
  const done = {};
  const out = [];
  for (const e of events.value) {
    if (!e.entry) continue;
    const r = e.entry;
    const key = `${r.tool} ${JSON.stringify(r.args)}`;
    if (r.outcome === "pending" && done[key]) {
      done[key]--;
      continue;
    }
    if (r.decision === "confirm" && r.outcome !== "pending") done[key] = (done[key] ?? 0) + 1;
    const lapsed = r.outcome === "pending" && age(r.ts, "utc") > TTL;
    out.push({
      key: r.seq,
      tool: r.tool,
      target: target(r.args),
      bot: r.actor.startsWith("agent"),
      actor: r.actor.replace(/^[a-z]+:/, ""),
      badge: lapsed ? "" : r.decision,
      state:
        r.decision === "deny"
          ? t("changes.refused", { rule: r.ruleId })
          : r.outcome === "error"
            ? t("changes.failed", { why: r.errorText })
            : r.outcome === "pending"
              ? t(lapsed ? "changes.lapsed" : "changes.waiting")
              : `${t(r.decision === "confirm" ? "changes.confirmed" : "changes.ok")}${r.durationMs ? ` · ${r.durationMs} ms` : ""}`,
      bad: r.outcome === "error",
      ago: ago(age(r.ts, "utc")),
      ts: r.ts,
    });
  }
  return out;
});

function ago(ms) {
  const m = Math.round(ms / 60_000);
  return m < 1
    ? t("changes.now")
    : m < 60
      ? `${m} min`
      : m < 2880
        ? `${Math.round(m / 60)} h`
        : `${Math.round(m / 1440)} d`;
}
</script>

<template>
  <Block :title="t('changes.block')">
    <template #actions>
      <RouterLink to="/audit" class="text-micro text-text-muted no-underline hover:text-text"
        >{{ t("changes.all") }} →</RouterLink
      >
    </template>
    <div class="min-h-0 flex-1 overflow-y-auto px-3">
      <RouterLink
        v-for="c in items"
        :key="c.key"
        :to="`/audit?q=${encodeURIComponent(c.tool)}`"
        class="grid min-h-[40px] grid-cols-[16px_minmax(0,1fr)_auto] items-center gap-2.5 border-b border-line py-1 no-underline last:border-b-0"
        :title="`#${c.key} · ${c.ts} UTC`"
      >
        <Icon :name="c.bot ? 'bot' : 'human'" :size="15" :class="c.bot ? 'text-accent' : 'text-text-muted'" />
        <div class="min-w-0">
          <div class="truncate text-small">
            <span class="font-mono text-text-bright">{{ c.tool }}</span>
            <span v-if="c.target" class="ml-1.5 font-mono text-text-muted">{{ c.target }}</span>
          </div>
          <div class="truncate text-micro" :class="c.bad ? 'text-deny' : 'text-text-muted'">
            {{ c.actor }} · {{ c.state }}
          </div>
        </div>
        <div class="flex flex-col items-end gap-0.5">
          <DecisionBadge v-if="c.badge" :decision="c.badge" />
          <span
            v-else
            class="inline-flex h-5 items-center rounded-badge border border-line-strong px-[7px] text-micro text-text-muted"
          >
            {{ t("changes.lapsedBadge") }}
          </span>
          <span class="font-mono text-[10.5px] text-text-dim">{{ c.ago }}</span>
        </div>
      </RouterLink>
      <p v-if="!items.length" class="py-3 text-micro text-text-muted">{{ t("changes.empty") }}</p>
    </div>
  </Block>
</template>
