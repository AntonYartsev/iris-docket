<script setup>
// no v-html on purpose
import { computed, h } from "vue";

const props = defineProps({ text: { type: String, default: "" } });

const INLINE = /`([^`]+)`|\*\*([\s\S]+?)\*\*|__([\s\S]+?)__|\*([^*\n]+)\*|_([^_\n]+)_/g;
const BULLET = /^\s*[-*]\s+(.*)$/;
const NUMBER = /^\s*\d+[.)]\s+(.*)$/;
const BREAK = /^\s*([-*]\s|\d+[.)]\s|#{1,6}\s|```)/;

function inline(line) {
  const out = [];
  let at = 0;
  INLINE.lastIndex = 0;
  for (let m; (m = INLINE.exec(line));) {
    if (m.index > at) out.push({ t: "", v: line.slice(at, m.index) });
    if (m[1] !== undefined) out.push({ t: "code", v: m[1] });
    else if (m[2] ?? m[3]) out.push({ t: "b", v: m[2] ?? m[3] });
    else out.push({ t: "i", v: m[4] ?? m[5] });
    at = m.index + m[0].length;
  }
  if (at < line.length) out.push({ t: "", v: line.slice(at) });
  return out;
}

const blocks = computed(() => {
  const lines = String(props.text ?? "").split("\n");
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) {
      i++;
      continue;
    }
    if (line.startsWith("```")) {
      const body = [];
      for (i++; i < lines.length && !lines[i].startsWith("```"); i++) body.push(lines[i]);
      i++;
      out.push({ type: "code", text: body.join("\n") });
      continue;
    }
    const head = line.match(/^#{1,6}\s+(.*)$/);
    if (head) {
      out.push({ type: "head", tokens: inline(head[1]) });
      i++;
      continue;
    }
    const numbered = NUMBER.test(line) && !BULLET.test(line);
    if (numbered || BULLET.test(line)) {
      const items = [];
      for (let m; i < lines.length && (m = lines[i].match(numbered ? NUMBER : BULLET)); i++) {
        items.push(inline(m[1]));
      }
      out.push({ type: numbered ? "ol" : "ul", items });
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !BREAK.test(lines[i])) para.push(lines[i++]);
    out.push({ type: "p", tokens: inline(para.join("\n")) });
  }
  return out;
});

const CODE = "rounded-tight bg-surface-raised px-1 py-0.5 font-mono text-micro text-text-bright";
const Tokens = (p) =>
  p.tokens.map((t) =>
    t.t === "code"
      ? h("code", { class: CODE }, t.v)
      : t.t === "b"
        ? h("strong", { class: "font-semibold text-text-bright" }, t.v)
        : t.t === "i"
          ? h("em", null, t.v)
          : t.v,
  );
</script>

<template>
  <div class="space-y-card-gap">
    <template v-for="(b, i) in blocks" :key="i">
      <h3 v-if="b.type === 'head'" class="text-small font-semibold text-text-bright">
        <Tokens :tokens="b.tokens" />
      </h3>
      <pre
        v-else-if="b.type === 'code'"
        class="overflow-x-auto rounded-control border border-line bg-base px-cell-x py-cell-y font-mono text-micro text-text"
        >{{ b.text }}</pre>
      <ul v-else-if="b.type === 'ul'" class="list-disc space-y-0.5 pl-5 marker:text-text-dim">
        <li v-for="(item, k) in b.items" :key="k"><Tokens :tokens="item" /></li>
      </ul>
      <ol v-else-if="b.type === 'ol'" class="list-decimal space-y-0.5 pl-5 marker:text-text-dim">
        <li v-for="(item, k) in b.items" :key="k"><Tokens :tokens="item" /></li>
      </ol>
      <p v-else class="whitespace-pre-wrap"><Tokens :tokens="b.tokens" /></p>
    </template>
  </div>
</template>
