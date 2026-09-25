const NODE_W = 168;
const NODE_MIN = 112;
const UNIT = 13;
const MIN_H = 24;
const MIN_H_SUB = 34;
const GAP_Y = 10;
export const RANK = { high: 2, medium: 1 };
const PAD = 8;

function columns(available) {
  const width = Math.max(420, available);
  const nodeW = Math.max(NODE_MIN, Math.min(NODE_W, (width - 2 * PAD - 96) / 3));
  return { width, nodeW, gapX: (width - 2 * PAD - 3 * nodeW) / 2 };
}

export function reachLayout(graph, available) {
  if (!graph?.nodes?.length) return null;

  const nodes = new Map(graph.nodes.map((n) => [n.id, { ...n, in: 0, out: 0, links: 0, rank: 0 }]));
  const links = graph.links.filter((l) => nodes.has(l.from) && nodes.has(l.to));
  for (const l of links) {
    const a = nodes.get(l.from);
    const b = nodes.get(l.to);
    a.out += l.weight;
    b.in += l.weight;
    a.links++;
    b.links++;
    const rank = RANK[l.severity] ?? 0;
    a.rank = Math.max(a.rank, rank);
    b.rank = Math.max(b.rank, rank);
  }

  const { width, nodeW, gapX } = columns(available);
  const stacks = [0, 1, 2].map((col) => {
    const list = [...nodes.values()]
      .filter((n) => n.col === col)
      .sort((a, b) => b.rank - a.rank || b.links - a.links || a.label.localeCompare(b.label));
    let y = PAD;
    for (const n of list) {
      n.h = Math.max(n.sub || n.perm ? MIN_H_SUB : MIN_H, UNIT * Math.max(n.in, n.out));
      n.x = PAD + col * (nodeW + gapX);
      n.y = y;
      n.oy = 0;
      n.iy = 0;
      y += n.h + GAP_Y;
    }
    return { list, used: y - GAP_Y };
  });

  const height = Math.max(...stacks.map((s) => s.used));
  for (const s of stacks) {
    const dy = (height - s.used) / 2;
    if (dy) for (const n of s.list) n.y += dy;
  }

  const ribbons = links.map((l) => {
    const a = nodes.get(l.from);
    const b = nodes.get(l.to);
    const w = Math.max(1.5, Math.min(UNIT * l.weight, a.h, b.h));
    const y0 = a.y + a.oy + w / 2;
    const y1 = b.y + b.iy + w / 2;
    a.oy += w;
    b.iy += w;
    const x0 = a.x + nodeW;
    const mid = (x0 + b.x) / 2;
    return { ...l, w, d: `M${x0},${y0} C${mid},${y0} ${mid},${y1} ${b.x},${y1}` };
  });

  return { nodes: [...nodes.values()], ribbons, nodeW, width, height: height + PAD };
}
