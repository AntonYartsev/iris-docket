#!/usr/bin/env python3
"""Generate App.Tools.Admin.* tool classes from the curated slice SysAdmin API.

  python3 tools/gen_registry.py --stats     numbers only
  python3 tools/gen_registry.py             (re)generate src/App/Tools/Admin/*.cls
  python3 tools/gen_registry.py --check     regenerate into a temp dir and diff (CI gate)

Spec (spec/overlay.json) is the source of truth about the shape of the API.
Generated classes are never hand-edited: fix spec/curated.json or spec/overlay.json and re-run.
"""
import argparse, collections, filecmp, hashlib, json, pathlib, re, shutil, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "spec/mainspec_v2.json"
SHA = ROOT / "spec/mainspec_v2.sha256"
CURATED = ROOT / "spec/curated.json"
OVERLAY = ROOT / "spec/overlay.json"
OUT = ROOT / "src/App/Tools/Admin"

PRIV = re.compile(r"\((%[A-Za-z_][A-Za-z0-9_]*):([RWU]+)\)")


def load():
    if not SPEC.exists():
        sys.exit(f"missing {SPEC}")
    raw = SPEC.read_bytes()
    want = SHA.read_text().split()[0].strip()
    got = hashlib.sha256(raw).hexdigest()
    if got != want:
        sys.exit(f"spec sha256 mismatch\n  pinned {want}\n  actual {got}\n"
                 f"the spec changed under us - review the diff, then update {SHA.name}")
    return json.loads(raw), json.loads(CURATED.read_text()), json.loads(OVERLAY.read_text())


def param(spec, x):
    return spec["components"]["parameters"][x["$ref"].split("/")[-1]] if "$ref" in x else x


def deref(spec, node, depth=0):
    while isinstance(node, dict) and "$ref" in node and depth < 8:
        cur = spec
        for part in node["$ref"].split("/")[1:]:
            cur = cur[part]
        node, depth = cur, depth + 1
    return node


def arg_schema(spec, path, method):
    node = spec["paths"][path]
    op = node[method.lower()]
    props, required, query = {}, [], []
    for raw in (node.get("parameters") or []) + (op.get("parameters") or []):
        p = param(spec, raw)
        if p.get("in") != "query":
            continue
        s = dict(p.get("schema") or {"type": "string"})
        if p.get("description"):
            s["title"] = p["description"].strip()[:120]
        props[p["name"]] = s
        query.append(p["name"])
        if p.get("required"):
            required.append(p["name"])
    body = op.get("requestBody")
    if body:
        bs = deref(spec, (body.get("content") or {}).get("application/json", {}).get("schema", {}))
        for k, v in (bs.get("properties") or {}).items():
            props[k] = deref(spec, v)
        required += list(bs.get("required") or [])
    out = {"type": "object", "properties": props}
    if required:
        out["required"] = sorted(set(required))
    return out, query


def apply_overlay(schema, key, overlay):
    patch = (overlay.get("operation_patches") or {}).get(key)
    if not patch:
        return schema
    for step in patch.get("patch", []):
        if step["op"] == "rename":
            old = step["path"].rsplit("/", 1)[-1]
            if old in schema["properties"]:
                schema["properties"][step["value"]] = schema["properties"].pop(old)
    return schema


def cls_name(tool):
    return "".join(w[:1].upper() + w[1:] for w in re.split(r"[.\-_]", tool))


def render(tool, meta, key, schema, query):
    method, path = key.split(" ", 1)
    name = cls_name(tool)
    priv = meta.get("privilege") or ""
    body = json.dumps(schema, indent=2, ensure_ascii=False)
    body = "\n".join("  " + ln for ln in body.splitlines())
    return f"""/// generated, dont edit by hand
Class App.Tools.Admin.{name} Extends App.Tools.AdminBase
{{

Parameter ToolName = "{tool}";

Parameter Title = "{meta['title']}";

Parameter Category = "{meta['category']}";

Parameter Mutating = {1 if meta['mutating'] else 0};

Parameter Source = "spec";

Parameter HttpMethod = "{method}";

Parameter HttpPath = "{path}";

Parameter QueryArgs = "{",".join(query)}";

Parameter Privilege = "{priv}";

XData Schema [ MimeType = application/json ]
{{
{body}
}}

}}
"""


def generate(dest, spec, curated, overlay):
    dest.mkdir(parents=True, exist_ok=True)
    n = 0
    for key, meta in curated["operations"].items():
        method, path = key.split(" ", 1)
        schema, query = arg_schema(spec, path, method)
        schema = apply_overlay(schema, key, overlay)
        (dest / f"{cls_name(meta['tool'])}.cls").write_text(render(meta["tool"], meta, key, schema, query))
        n += 1
    return n


def stats(spec, curated):
    paths = spec["paths"]
    meth = collections.Counter(m for v in paths.values() for m in v if m != "parameters")
    total = sum(meth.values())
    mutating = sum(v for k, v in meth.items() if k in ("post", "put", "delete"))
    privs = collections.Counter()
    annotated = 0
    for v in paths.values():
        for m, op in v.items():
            if m == "parameters":
                continue
            found = PRIV.findall(op.get("summary", ""))
            if found:
                annotated += 1
                privs[f"{found[0][0]}:{found[0][1]}"] += 1
    print(f"spec            {SPEC.relative_to(ROOT)}")
    print(f"sha256          {hashlib.sha256(SPEC.read_bytes()).hexdigest()}")
    print(f"paths           {len(paths)}")
    print(f"operations      {total}  ({', '.join(f'{k.upper()} {v}' for k, v in sorted(meth.items()))})")
    print(f"mutating        {mutating}")
    print(f"annotated       {annotated}   unannotated {total - annotated}")
    print("privileges:")
    for k, v in privs.most_common():
        print(f"    {k:38} {v}")
    print(f"curated         {len(curated['operations'])} generated, "
          f"{len(curated['composite']) - 1} composite, {len(curated['manual']) - 1} manual")
    cats = collections.Counter(v["category"] for v in curated["operations"].values())
    print(f"    categories  {dict(cats)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stats", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    spec, curated, overlay = load()
    if a.stats:
        stats(spec, curated)
        return
    if a.check:
        tmp = pathlib.Path(tempfile.mkdtemp())
        generate(tmp, spec, curated, overlay)
        cmp = filecmp.dircmp(str(OUT), str(tmp))
        drift = cmp.left_only + cmp.right_only + cmp.diff_files
        shutil.rmtree(tmp)
        if drift:
            sys.exit("generated classes are out of date:\n  " + "\n  ".join(sorted(drift)))
        print(f"up to date ({len(list(OUT.glob('*.cls')))} classes)")
        return
    n = generate(OUT, spec, curated, overlay)
    print(f"wrote {n} classes to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
