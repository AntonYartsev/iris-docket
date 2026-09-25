<script setup>
defineProps({
  name: { type: String, required: true },
  size: { type: [Number, String], default: "var(--size-icon)" },
});

const G = {
  dashboard: [
    ["rect", { x: 2.5, y: 2.5, width: 4.5, height: 5.5, rx: 1 }],
    ["rect", { x: 9, y: 2.5, width: 4.5, height: 3, rx: 1 }],
    ["rect", { x: 2.5, y: 10, width: 4.5, height: 3.5, rx: 1 }],
    ["rect", { x: 9, y: 7.5, width: 4.5, height: 6, rx: 1 }],
  ],
  system: [
    ["rect", { x: 4.5, y: 4.5, width: 7, height: 7, rx: 1 }],
    "M7 2v2M9 2v2M7 12v2M9 12v2M2 7h2M2 9h2M12 7h2M12 9h2",
  ],
  security: [["rect", { x: 3, y: 7, width: 10, height: 6.5, rx: 1.5 }], "M5.5 7V5a2.5 2.5 0 0 1 5 0v2"],
  secrets: [["circle", { cx: 6, cy: 6, r: 3 }], "M8.1 8.1 13 13M11 11l1.5-1.5"],
  webapps: [["circle", { cx: 8, cy: 8, r: 5.5 }], "M2.5 8h11M8 2.5c1.6 1.6 1.6 9.4 0 11"],
  tasks: [["circle", { cx: 8, cy: 8, r: 5.5 }], "M8 5v3.2l2.2 1.4"],
  logs: ["M3 3.5h10M3 7h7M3 10.5h9M3 14h5"],
  interop: ["M2.5 5.5h8.5l-2-2M13.5 10.5H5l2 2"],
  packages: [["rect", { x: 2.5, y: 4.5, width: 11, height: 9, rx: 1.5 }], "M2.5 7.5h11M8 7.5v6"],
  tools: [["rect", { x: 2.5, y: 3, width: 11, height: 10, rx: 1.5 }], "M5 6h1M8 6h3M5 9h1M8 9h3"],
  policy: ["M8 2.5l5 2v4c0 2.6-2 4.4-5 5-3-.6-5-2.4-5-5v-4l5-2Z", "M5.8 8.2 7.3 9.7 10.4 6.6"],
  audit: [
    ["rect", { x: 2.5, y: 6.5, width: 5, height: 3.5, rx: 1.75 }],
    ["rect", { x: 8.5, y: 6.5, width: 5, height: 3.5, rx: 1.75 }],
    "M7 8.25h2",
  ],
  agent: ["M2.5 4.5A2 2 0 0 1 4.5 2.5h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H7l-3.5 3v-3a1 1 0 0 1-1-1v-5Z"],
  findings: ["M8 2.5 14.5 13.5h-13L8 2.5Z", "M8 6.4v3.2M8 11.5v.1"],
  reach: [
    ["circle", { cx: 3.5, cy: 8, r: 1.5 }],
    ["circle", { cx: 12.5, cy: 4, r: 1.5 }],
    ["circle", { cx: 12.5, cy: 12, r: 1.5 }],
    "M4.8 7.2 11.2 4.6M4.8 8.8l6.4 2.6",
  ],
  version: [
    ["circle", { cx: 10.6, cy: 5.4, r: 1 }],
    "M8.7 2.5h4.8v4.8l-5.6 5.6a1.4 1.4 0 0 1-2 0L3 10a1.4 1.4 0 0 1 0-2l5.7-5.5Z",
  ],
  human: [["circle", { cx: 8, cy: 5.5, r: 2.5 }], "M3.5 13.5c.6-2.4 2.3-3.6 4.5-3.6s3.9 1.2 4.5 3.6"],
  bot: [["rect", { x: 3, y: 5, width: 10, height: 7, rx: 2 }], "M8 2.5V5M6 8.5v.1M10 8.5v.1"],
  search: [["circle", { cx: 7, cy: 7, r: 4.25 }], "M10.2 10.2 14 14"],
  chevron: ["M4 6.5 8 10.5l4-4"],
  left: ["M9.5 4 5.5 8l4 4"],
  right: ["M6.5 4l4 4-4 4"],
  close: ["M4 4l8 8M12 4l-8 8"],
  info: [["circle", { cx: 8, cy: 8, r: 5.5 }], "M8 7.3v3.7M8 5.2v.1"],
  lock: [["rect", { x: 3, y: 7, width: 10, height: 6.5, rx: 1.5 }], "M5.5 7V5a2.5 2.5 0 0 1 5 0v2"],
  pause: ["M6 3.5v9M10 3.5v9"],
  signout: ["M6 2.5H3.5v11H6M9 5l3 3-3 3M12 8H6"],
  refresh: ["M2.5 8a5.5 5.5 0 0 1 9.71-3.54M13.5 2.5v3h-3", "M13.5 8a5.5 5.5 0 0 1-9.71 3.54M2.5 13.5v-3h3"],
};

const parts = (name) => (G[name] ?? []).map((p) => (typeof p === "string" ? ["path", { d: p }] : p));
</script>

<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    stroke-width="1.5"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
    class="shrink-0"
  >
    <component :is="tag" v-for="([tag, attrs], i) in parts(name)" :key="i" v-bind="attrs" />
  </svg>
</template>
