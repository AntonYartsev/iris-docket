<script setup>
import { computed, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { api, useResource } from "../composables/useApi";
import { t } from "../composables/useI18n";
import { useToolInvoke } from "../composables/useToolInvoke";
import { useCopy } from "../composables/useCopy";
import Block from "../components/Block.vue";
import DataTable from "../components/DataTable.vue";
import DecisionBadge from "../components/DecisionBadge.vue";
import DetailPanel from "../components/DetailPanel.vue";
import FieldGrid from "../components/FieldGrid.vue";
import FilterField from "../components/FilterField.vue";
import Icon from "../components/Icon.vue";
import AsyncPanel from "../components/AsyncPanel.vue";
import Pager from "../components/Pager.vue";

const PAGE = 100;
const FIELDS =
  "seq ts actor channel correlationId tool args decision ruleId outcome errorText durationMs asyncId hash prevHash".split(
    " ",
  );

const route = useRoute();
const tab = ref(route.query.tab === "async" ? "async" : "journal");
const q = ref(route.query.q ?? "");
const decision = ref(route.query.decision ?? "");
const actor = ref(route.query.actor ?? "");
const correlation = ref(route.query.correlationId ?? "");
const selected = ref(null);
const { copied, copy } = useCopy();
const pages = ref([]);

watch(
  () => route.query,
  (next) => {
    q.value = next.q ?? "";
    decision.value = next.decision ?? "";
    actor.value = next.actor ?? "";
    correlation.value = next.correlationId ?? "";
    tab.value = next.tab === "async" ? "async" : "journal";
  },
);

const url = computed(() => {
  // +1 to see older page
  const p = new URLSearchParams({ limit: PAGE + 1 });
  if (pages.value.length) p.set("before", pages.value.at(-1));
  if (q.value.trim()) p.set("q", q.value.trim());
  if (decision.value) p.set("decision", decision.value);
  if (actor.value) p.set("actor", actor.value);
  if (correlation.value) p.set("correlationId", correlation.value);
  return `/audit?${p}`;
});

const { data: entries, error, pending, reload } = useResource(() => api(url.value));
const rows = computed(() => (entries.value ?? []).slice(0, PAGE));
const hasOlder = computed(() => (entries.value?.length ?? 0) > PAGE);
const turn = (next) => ((pages.value = next), reload());

let timer;
watch([q, decision, actor, correlation], () => {
  pages.value = [];
  clearTimeout(timer);
  timer = setTimeout(reload, 250);
});

watch(entries, (list) => {
  if (selected.value) selected.value = (list ?? []).find((e) => e.seq === selected.value.seq) ?? null;
});

const chain = ref(null);
const verifying = ref(false);
const verify = async () => {
  verifying.value = true;
  chain.value = null;
  chain.value = await api("/audit/verify").then((r) => r.data);
  verifying.value = false;
};
verify();

const { toast } = useToolInvoke();

async function save(kind) {
  const cell = (v) => `"${String(typeof v === "object" ? JSON.stringify(v) : (v ?? "")).replaceAll('"', '""')}"`;
  let text;
  try {
    text =
      kind === "csv"
        ? [FIELDS.join(","), ...rows.value.map((e) => FIELDS.map((f) => cell(e[f])).join(","))].join("\n")
        : JSON.stringify((await api("/audit/export")).data, null, 2);
  } catch (e) {
    toast.value = { tone: "deny", text: e.message };
    return;
  }
  const href = URL.createObjectURL(
    new Blob([text], {
      type: kind === "csv" ? "text/csv" : "application/json",
    }),
  );
  Object.assign(document.createElement("a"), {
    href,
    download: kind === "csv" ? "portal-audit.csv" : "portal-audit-chain.json",
  }).click();
  URL.revokeObjectURL(href);
}

const counts = computed(() => {
  const all = rows.value;
  return {
    allow: all.filter((e) => e.decision === "allow").length,
    confirm: all.filter((e) => e.decision === "confirm").length,
    deny: all.filter((e) => e.decision === "deny").length,
  };
});

const columns = computed(() => [
  {
    key: "seq",
    label: t("audit.col.seq"),
    mono: true,
    class: "text-text-muted",
    width: "58px",
  },
  {
    key: "ts",
    label: t("audit.col.when"),
    mono: true,
    class: "text-text-muted",
  },
  { key: "actor", label: t("audit.col.actor") },
  {
    key: "tool",
    label: t("audit.col.tool"),
    mono: true,
    class: "text-text-bright",
  },
  {
    key: "args",
    label: t("audit.col.args"),
    mono: true,
    class: "max-w-[220px] truncate text-text-muted",
  },
  { key: "decision", label: t("audit.col.decision") },
  { key: "outcome", label: t("audit.col.outcome") },
  {
    key: "durationMs",
    label: t("audit.col.ms"),
    mono: true,
    right: true,
    class: "text-text-muted",
  },
  {
    key: "chain",
    label: t("audit.col.digest"),
    mono: true,
    class: "text-text-muted",
    sort: (e) => e.hash,
  },
]);

const facts = (e) => [
  [t("audit.col.when"), e.ts],
  [t("audit.col.actor"), e.actor],
  ["channel", e.channel],
  [t("audit.col.tool"), e.tool],
  [t("audit.col.decision"), `${e.decision} · ${e.ruleId ?? "-"}`],
  [t("audit.col.outcome"), e.outcome],
  [t("audit.col.ms"), e.durationMs],
  ["asyncId", e.asyncId],
];
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <FilterField v-model="q" width="auto" :placeholder="t('audit.search')" />
    <select
      v-model="decision"
      class="h-[var(--size-field)] shrink-0 rounded-control border border-line-strong bg-surface px-2 text-small text-text"
    >
      <option value="">{{ t("audit.anyDecision") }}</option>
      <option value="allow">allow</option>
      <option value="confirm">confirm</option>
      <option value="deny">deny</option>
    </select>
    <select
      v-model="actor"
      class="h-[var(--size-field)] shrink-0 rounded-control border border-line-strong bg-surface px-2 text-small text-text"
    >
      <option value="">{{ t("audit.anyActor") }}</option>
      <option value="user">{{ t("audit.people") }}</option>
      <option value="agent">{{ t("audit.theAgent") }}</option>
    </select>
    <button
      v-if="correlation"
      class="inline-flex h-[26px] shrink-0 items-center gap-1.5 rounded-badge border border-line-strong px-2.5 font-mono text-micro text-text-muted"
      :title="t('audit.turnTitle')"
      @click="correlation = ''"
    >
      {{ t("audit.turn", { id: correlation.slice(0, 8) }) }} ✕
    </button>

    <div class="flex shrink-0 gap-1.5">
      <button
        v-for="b in [
          { label: t('audit.exportChain'), title: t('audit.exportChainTitle'), run: () => save('json') },
          { label: 'CSV', title: t('audit.exportCsvTitle'), run: () => save('csv') },
        ]"
        :key="b.label"
        :title="b.title"
        class="h-[var(--size-btn)] rounded-control border border-line-strong px-3 text-small text-text transition-colors hover:bg-surface-raised"
        @click="b.run()"
      >
        {{ b.label }}
      </button>
      <button
        class="h-[var(--size-btn)] rounded-control border border-line-strong px-3 text-small text-text transition-colors hover:bg-surface-raised"
        :class="tab === 'async' && 'bg-surface-raised text-text-bright'"
        @click="tab = tab === 'async' ? 'journal' : 'async'"
      >
        {{ t("audit.async") }}
      </button>
    </div>
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <div class="flex min-h-0 min-w-0 flex-1 flex-col gap-panel">
      <div
        :title="t('audit.chain.explain')"
        class="flex shrink-0 items-center gap-2 rounded-card border px-2.5 py-1.5 text-micro"
        :class="chain?.ok === false ? 'border-deny bg-deny-soft' : 'border-allow bg-allow-soft'"
      >
        <Icon
          :name="chain?.ok === false ? 'findings' : 'policy'"
          :size="15"
          :class="chain?.ok === false ? 'text-deny' : 'text-allow'"
        />
        <span :class="chain?.ok === false ? 'text-deny' : 'text-allow'">
          <template v-if="verifying">{{ t("audit.chain.walking") }}</template>
          <template v-else-if="chain?.ok">{{ t("audit.chain.ok", { n: chain.entries }) }}</template>
          <template v-else-if="chain">{{
            t("audit.chain.broken", { n: chain.brokenAt, reason: chain.reason })
          }}</template>
          <template v-else>{{ t("audit.chain.unverified") }}</template>
        </span>
        <a
          class="ml-auto shrink-0 text-micro text-text-muted underline decoration-dotted underline-offset-2 hover:text-text"
          href="/portal/verify.html"
          target="_blank"
          rel="noopener"
          :title="t('audit.chain.offlineTitle')"
        >
          {{ t("audit.chain.offline") }}
        </a>
        <button
          class="h-[22px] shrink-0 rounded-control border px-2 text-micro transition-colors"
          :class="
            chain?.ok === false
              ? 'border-deny text-deny hover:bg-deny-soft'
              : 'border-allow text-allow hover:bg-allow-soft'
          "
          @click="verify"
        >
          {{ t("audit.chain.verify") }}
        </button>
      </div>

      <AsyncPanel
        v-if="tab === 'async'"
        @find="((tab = 'journal'), (correlation = ''), (decision = ''), (actor = ''), (q = $event))"
      />

      <Block
        v-else
        :title="t('audit.journal')"
        :meta="t('audit.journal.meta', { n: rows.length })"
        :meta-title="t('audit.journal.metaTitle')"
        class="flex-1"
      >
        <template #actions>
          <span class="inline-flex items-center gap-1 text-micro text-allow">
            <span class="size-[5px] rounded-badge bg-current" />{{ counts.allow }}
          </span>
          <span class="inline-flex items-center gap-1 text-micro text-confirm">
            <span class="size-[5px] rounded-badge bg-current" />{{ counts.confirm }}
          </span>
          <span class="inline-flex items-center gap-1 text-micro text-deny">
            <span class="size-[5px] rounded-badge bg-current" />{{ counts.deny }}
          </span>
          <Pager
            class="text-micro text-text-muted"
            :range="rows.length ? `#${rows[0].seq}–#${rows.at(-1).seq}` : ''"
            :newer="pages.length > 0"
            :older="hasOlder"
            @newest="turn([])"
            @newer="turn(pages.slice(0, -1))"
            @older="turn([...pages, rows.at(-1).seq])"
          />
        </template>

        <DataTable
          :columns="columns"
          :rows="rows"
          row-key="seq"
          sortable
          selectable
          :selected="selected?.seq"
          :state="pending ? 'loading' : error ? 'error' : 'ready'"
          :error="error?.message"
          tool="/portal/api/audit"
          :empty="t('audit.empty')"
          :empty-hint="t('audit.emptyHint')"
          @select="selected = $event"
          @retry="reload"
        >
          <template #actor="{ row }">
            <span class="inline-flex items-center gap-1.5">
              <span
                class="inline-flex text-text-muted"
                :title="t(row.actor?.startsWith('agent') ? 'audit.agentMark' : 'audit.userMark')"
              >
                <Icon :name="row.actor?.startsWith('agent') ? 'bot' : 'human'" :size="13" />
              </span>
              <span class="max-w-[110px] truncate" :title="row.actor">{{
                row.actor?.replace(/^(user|agent):/, "")
              }}</span>
            </span>
          </template>
          <template #args="{ row }">
            <span :title="JSON.stringify(row.args)">{{ JSON.stringify(row.args) }}</span>
          </template>
          <template #decision="{ row }">
            <DecisionBadge :decision="row.decision" :rule="row.ruleId" />
          </template>
          <template #outcome="{ row }">
            <span
              :class="
                row.outcome === 'ok' ? 'text-text-muted' : row.outcome === 'pending' ? 'text-confirm' : 'text-deny'
              "
            >
              {{ row.outcome }}
            </span>
            <button
              v-if="row.correlationId"
              class="ml-1.5 font-mono text-text-muted underline"
              :title="t('audit.seeTurn')"
              @click.stop="((correlation = row.correlationId), (q = ''), (decision = ''), (actor = ''))"
            >
              {{ t("audit.turnLink") }}
            </button>
          </template>
          <template #chain="{ row }">
            <span :title="row.hash">{{ row.hash?.slice(0, 8) ?? "-" }}</span>
          </template>
        </DataTable>
      </Block>
    </div>

    <DetailPanel v-if="selected" :title="t('audit.entry')" :subject="`#${selected.seq}`" @close="selected = null">
      <div class="border-b border-line px-2.5 py-[9px]">
        <DecisionBadge :decision="selected.decision" :rule="selected.ruleId" filled />
        <div class="mt-2">
          <FieldGrid :rows="facts(selected)" label-width="72px" />
        </div>
      </div>

      <div class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">
          {{ t("audit.arguments") }}
        </div>
        <pre
          class="overflow-x-auto rounded-control border border-line bg-base p-2 text-micro whitespace-pre-wrap text-text-muted"
          >{{ JSON.stringify(selected.args ?? {}, null, 2) }}</pre>
      </div>

      <div v-if="selected.errorText" class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-deny">
          {{ t("audit.error") }}
        </div>
        <p class="text-micro break-words text-text">{{ selected.errorText }}</p>
      </div>

      <div class="border-b border-line px-2.5 py-[9px]">
        <div class="mb-1.5 text-micro tracking-[0.04em] text-text-muted">
          {{ t("audit.chainSection") }}
        </div>
        <FieldGrid
          :rows="[
            [t('audit.col.digest'), selected.hash],
            [t('audit.prev'), selected.prevHash],
          ]"
          label-width="72px"
        >
          <template v-for="k in [t('audit.col.digest'), t('audit.prev')]" #[k]="{ value }" :key="k">
            <button
              v-if="value"
              class="w-full truncate text-left transition-colors hover:text-text-bright"
              :class="copied === value && 'text-allow'"
              :title="t('audit.copyDigest', { digest: value })"
              @click="copy(value, $event.currentTarget)"
            >
              {{ copied === value ? t("audit.copied") : value }}
            </button>
          </template>
        </FieldGrid>
        <p class="mt-1.5 text-micro text-text-muted">
          {{ t("audit.chain.explain") }}
        </p>
      </div>
    </DetailPanel>
  </div>
</template>
