<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { t } from "../composables/useI18n";
import { RANK, reachLayout } from "../composables/useReachLayout";

const props = defineProps({
  graph: { type: Object, default: null },
  removed: { type: Array, default: () => [] },
  selected: { type: String, default: "" },
  pinned: { type: String, default: "" },
});
defineEmits(["select", "pin"]);

const box = ref(null);
const avail = ref(900);
let observer = null;
onMounted(() => {
  observer = new ResizeObserver(([e]) => (avail.value = e.contentRect.width));
  observer.observe(box.value);
});
onBeforeUnmount(() => observer?.disconnect());

const layout = computed(() => reachLayout(props.graph, avail.value));

const gone = computed(() => new Set(props.removed));

const TONE = ["stroke-line-strong", "stroke-confirm", "stroke-deny"];
const EDGE = ["stroke-line-strong", "stroke-confirm/50", "stroke-deny/50"];

const overLink = ref("");
const overNode = ref("");
const node = computed(() => overNode.value || props.pinned);

const shown = computed(() => {
  const ribbons = layout.value?.ribbons ?? [];
  const ids = new Set([props.selected, overLink.value].filter(Boolean));

  // 3 passes for 3 columns
  if (node.value) {
    const down = new Set([node.value]);
    const up = new Set([node.value]);
    for (let pass = 0; pass < 3; pass++) {
      for (const l of ribbons) {
        if (down.has(l.from)) {
          down.add(l.to);
          ids.add(l.id);
        }
        if (up.has(l.to)) {
          up.add(l.from);
          ids.add(l.id);
        }
      }
    }
  }

  const tails = new Set(ribbons.filter((l) => ids.has(l.id)).map((l) => l.from));
  for (const l of ribbons) if (tails.has(l.to)) ids.add(l.id);
  return ids;
});
const litNode = (n) => {
  if (n.id === node.value) return true;
  return (layout.value?.ribbons ?? []).some((l) => shown.value.has(l.id) && (l.from === n.id || l.to === n.id));
};

const gen = ref(0);
watch(
  () => props.graph,
  () => gen.value++,
);

const dim = (l) => {
  const on = shown.value.has(l.id);
  if (gone.value.has(l.id)) return on ? 0.5 : 0.18;
  if (!shown.value.size) return 0.6;
  if (!on) return 0.12;
  return l.id === props.selected || l.id === overLink.value ? 1 : 0.62;
};
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <div class="flex shrink-0 items-center gap-3 px-2.5 pt-2 text-micro text-text-muted">
      <span
        v-for="(tone, i) in ['bg-line-strong', 'bg-confirm', 'bg-deny']"
        :key="tone"
        class="flex items-center gap-1.5"
      >
        <span class="h-[3px] w-4 rounded-badge" :class="tone" />{{ t(`reach.legend.${i}`) }}
      </span>
    </div>

    <div ref="box" class="flex min-h-0 flex-1 overflow-auto px-2.5 py-2">
      <svg
        v-if="layout"
        class="m-auto"
        :viewBox="`0 0 ${layout.width} ${layout.height}`"
        :width="layout.width"
        :height="layout.height"
        @click.self="$emit('pin', '')"
      >
        <path
          v-for="l in layout.ribbons"
          :key="`${gen}:${l.id}`"
          :d="l.d"
          fill="none"
          :stroke-width="l.w"
          :stroke-dasharray="gone.has(l.id) ? '5 4' : undefined"
          :class="[
            TONE[RANK[l.severity] ?? 0],
            l.path && 'cursor-pointer',
            'animate-reach-draw transition-opacity duration-150',
          ]"
          :style="{ opacity: dim(l) }"
          :pointer-events="l.path ? 'stroke' : 'none'"
          @click="l.path && $emit('select', l.id)"
          @mouseenter="overLink = l.id"
          @mouseleave="overLink = ''"
        >
          <title v-if="l.path">{{ l.path }}</title>
        </path>

        <g
          v-for="n in layout.nodes"
          :key="n.id"
          class="cursor-pointer"
          @mouseenter="overNode = n.id"
          @mouseleave="overNode = ''"
          @click="$emit('pin', pinned === n.id ? '' : n.id)"
        >
          <rect
            :x="n.x"
            :y="n.y"
            :width="layout.nodeW"
            :height="n.h"
            rx="4"
            class="fill-surface-raised transition-opacity duration-150"
            :class="[EDGE[n.rank], litNode(n) && 'stroke-accent']"
            :style="{ opacity: shown.size && !litNode(n) ? 0.45 : 1 }"
            :stroke-width="pinned === n.id ? 2 : 1"
          />
          <foreignObject :x="n.x" :y="n.y" :width="layout.nodeW" :height="n.h">
            <div class="flex h-full flex-col justify-center overflow-hidden px-2 leading-[1.35]">
              <div
                class="truncate text-[11px] text-text-bright"
                :class="n.kind === 'principal' ? '' : 'font-mono'"
                :title="n.label"
              >
                {{ n.label }}
              </div>
              <div v-if="n.sub || n.perm" class="truncate text-[10px] text-text-muted" :title="n.sub || n.perm">
                {{ n.sub || n.perm }}
              </div>
            </div>
          </foreignObject>
        </g>
      </svg>
    </div>
  </div>
</template>
