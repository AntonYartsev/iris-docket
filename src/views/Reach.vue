<script setup>
import { computed, ref, shallowRef, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { api } from "../composables/useApi";
import { t } from "../composables/useI18n";
import { useToolInvoke } from "../composables/useToolInvoke";
import { refreshShell } from "../composables/useShell";
import Block from "../components/Block.vue";
import DetailPanel from "../components/DetailPanel.vue";
import InfoTip from "../components/InfoTip.vue";
import ReachCounts from "../components/ReachCounts.vue";
import RefreshButton from "../components/RefreshButton.vue";
import ReachDetail from "../components/ReachDetail.vue";
import ReachMap from "../components/ReachMap.vue";

const { invoke } = useToolInvoke();
const route = useRoute();
const router = useRouter();

const map = shallowRef(null);
const error = ref("");
const pending = ref(true);
const busy = ref(false);
const auditId = ref(0);
const focus = ref(route.query.focus ?? "");
const pinned = ref(route.query.node ?? "");
const warnings = ref([]);
const preview = shallowRef(null);

async function load() {
  pending.value = true;
  error.value = "";
  try {
    const res = await invoke("insight.reachability", {}, true);
    map.value = res.data;
    warnings.value = res.meta.warnings ?? [];
  } catch (e) {
    error.value = e.message;
  } finally {
    pending.value = false;
  }
}
load().then(() => route.query.preview === "1" && askPreview());

const paths = computed(() => (map.value?.links ?? []).filter((l) => l.path));
const selected = computed(
  () => paths.value.find((l) => l.id === focus.value) ?? paths.value.find((l) => l.keys?.includes(focus.value)) ?? null,
);

watch([selected, preview, pinned], ([l, p, n]) =>
  router.replace({
    query: { ...(l ? { focus: l.id } : {}), ...(l && p ? { preview: "1" } : {}), ...(n ? { node: n } : {}) },
  }),
);
watch(
  () => route.query,
  (q) => ((focus.value = q.focus ?? ""), (pinned.value = q.node ?? "")),
);

function select(id) {
  preview.value = null;
  focus.value = focus.value === id ? "" : id;
}

async function askPreview() {
  const link = selected.value;
  if (!link?.fix || preview.value) return (preview.value = null);
  busy.value = true;
  try {
    const [after, verdict] = await Promise.all([
      invoke("insight.reachability", { assume: [link.fix] }, true),
      api("/policy/simulate", { tool: link.fix.tool, args: link.fix.args }),
    ]);
    preview.value = { ...after.data, decision: verdict.data };
  } catch (e) {
    error.value = e.message;
  } finally {
    busy.value = false;
  }
}

async function apply() {
  const link = selected.value;
  busy.value = true;
  try {
    const res = await invoke(link.fix.tool, link.fix.args);
    if (!res) return;
    auditId.value = res.meta.auditId;
    preview.value = null;
    await load();
    refreshShell();
  } catch {
  } finally {
    busy.value = false;
  }
}

const decision = computed(() => preview.value?.decision ?? null);

const pinnedLabel = computed(() => (map.value?.nodes ?? []).find((n) => n.id === pinned.value)?.label ?? "");

const counts = computed(() => {
  const now = map.value?.counts;
  if (!now) return [];
  return ["anonymousPaths", "principals", "targets"].map((k) => {
    const next = preview.value?.counts?.[k];
    const changed = next !== undefined && next !== now[k];
    return { key: `reach.${k}`, text: changed ? `${now[k]} → ${next}` : String(now[k]), changed };
  });
});
</script>

<template>
  <div class="flex shrink-0 items-center gap-1.5">
    <ReachCounts :counts="counts" :pinned="pinnedLabel" :previewing="!!preview" @unpin="pinned = ''" />
    <InfoTip :title="t('reach.infoTitle')">
      <p>{{ t("reach.info.what") }}</p>
      <p>{{ t("reach.info.fix") }}</p>
      <p>{{ t("reach.info.when") }}</p>
    </InfoTip>
    <RefreshButton :busy="pending" :title="t('reach.reloadTitle')" @click="load" />
  </div>

  <div class="flex min-h-0 min-w-0 flex-1 gap-panel">
    <Block
      :title="t('reach.block')"
      :meta="t('reach.meta', { hidden: map?.hidden?.resources ?? 0 })"
      :meta-title="t('reach.metaTitle')"
      class="flex-1"
    >
      <p v-if="error" class="px-2.5 py-3 text-small text-deny">{{ error }}</p>
      <p v-else-if="pending && !map" class="px-2.5 py-3 text-small text-text-muted">{{ t("reach.loading") }}</p>
      <ReachMap
        v-else
        :graph="map"
        :removed="preview?.removed ?? []"
        :selected="selected?.id ?? ''"
        :pinned="pinned"
        @select="select"
        @pin="pinned = $event"
      />

      <div v-if="warnings.length" class="shrink-0 border-t border-line px-2.5 py-[7px]">
        <p v-for="w in warnings" :key="w" class="text-micro text-text-muted">{{ w }}</p>
      </div>
    </Block>

    <DetailPanel v-if="selected" :title="t('reach.detail')" :subject="selected.id" @close="select(selected.id)">
      <ReachDetail
        :link="selected"
        :decision="decision"
        :previewing="!!preview"
        :busy="busy"
        :audit-id="auditId"
        @preview="askPreview"
        @apply="apply"
      />
    </DetailPanel>
  </div>
</template>
