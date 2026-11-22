#!/usr/bin/env python3
"""Gravity Plumbers project validator (Python standard library only).

Run from the project root:   python3 tools/validate_project.py

Checks:
  1. project.godot parses and has the required settings (Jolt, Compatibility, gravity 0...).
  2. Every res:// path referenced in scripts / scenes / config exists.
  3. Every autoload script exists.
  4. .gd files indent with tabs only (no tab/space mixing).
  5. No class_name is declared twice.
  6. Every input action used in code exists in scripts/core/input_setup.gd.
  7. No Godot 3 syntax (yield, onready, export var, Spatial...).
  8. Calls like  GravityManager.foo  /  GameLog.bar  refer to members that exist
     in that autoload / class_name script (catches typos without running Godot).
  9. Every @rpc function name used with .rpc / .rpc_id exists in that file.
 10. Optional: if the 'gdtoolkit' package is installed, every .gd file is parsed.

Exit code 0 = all good, 1 = problems found (they are printed).
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SKIP_DIRS = {".git", ".godot", "build", "dist", "__pycache__"}
TEXT_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".godot", ".cfg", ".import"}

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def walk_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            yield os.path.join(dirpath, fn)


def res_to_path(res):
    return os.path.join(ROOT, res[len("res://"):])


# ---------------------------------------------------------------------------
# 1. project.godot
# ---------------------------------------------------------------------------
def parse_godot_cfg(text):
    """Very small parser for Godot's ConfigFile text format."""
    sections = {}
    current = None
    pending_key = None
    pending_val = ""
    depth = 0
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if pending_key is not None:
            pending_val += "\n" + raw
            depth += raw.count("{") + raw.count("[") + raw.count("(")
            depth -= raw.count("}") + raw.count("]") + raw.count(")")
            if depth <= 0:
                sections[current][pending_key] = pending_val
                pending_key = None
            continue
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
            continue
        if "=" not in line:
            raise ValueError("line %d: expected key=value: %r" % (lineno, line))
        if current is None:
            current = ""
            sections.setdefault(current, {})
        key, val = line.split("=", 1)
        depth = val.count("{") + val.count("[") + val.count("(")
        depth -= val.count("}") + val.count("]") + val.count(")")
        if depth > 0:
            pending_key, pending_val = key.strip(), val
        else:
            sections[current][key.strip()] = val.strip()
    if pending_key is not None:
        raise ValueError("unterminated value for key %r" % pending_key)
    return sections


def check_project():
    path = os.path.join(ROOT, "project.godot")
    if not os.path.exists(path):
        err("project.godot is missing")
        return {}
    try:
        cfg = parse_godot_cfg(open(path, encoding="utf-8").read())
    except ValueError as e:
        err("project.godot does not parse: %s" % e)
        return {}
    required = {
        ("physics", "3d/physics_engine"): '"Jolt Physics"',
        ("physics", "3d/default_gravity"): "0.0",
        ("physics", "common/physics_ticks_per_second"): "60",
        ("rendering", "renderer/rendering_method"): '"gl_compatibility"',
        ("input_devices", "pointing/emulate_touch_from_mouse"): "true",
    }
    for (sec, key), want in required.items():
        got = cfg.get(sec, {}).get(key)
        if got != want:
            err("project.godot [%s] %s should be %s (got %s)" % (sec, key, want, got))
    if "Forward" in open(path, encoding="utf-8").read():
        err("project.godot mentions Forward+; this project must never use it")
    main_scene = cfg.get("application", {}).get("run/main_scene", "").strip('"')
    if not main_scene or not os.path.exists(res_to_path(main_scene)):
        err("main scene missing: %r" % main_scene)
    return cfg


# ---------------------------------------------------------------------------
# 2/3. res:// references and autoloads
# ---------------------------------------------------------------------------
RES_RE = re.compile(r'res://[A-Za-z0-9_\-./]+')


def check_res_paths():
    for f in walk_files():
        ext = os.path.splitext(f)[1]
        if ext not in TEXT_EXT:
            continue
        try:
            text = open(f, encoding="utf-8").read()
        except UnicodeDecodeError:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for m in RES_RE.finditer(line):
                res = m.group(0).rstrip(".")
                after = line[m.end():m.end() + 2]
                # Dynamic paths ("res://x/" + name, "res://%s.gd" % a) are checked as folders.
                if "%" in after or res.endswith("/"):
                    target = res_to_path(res if res.endswith("/") else os.path.dirname(res))
                    if not os.path.isdir(target):
                        err("%s:%d: folder %s does not exist" % (rel(f), lineno, res))
                    continue
                if after.startswith('" +') or after.startswith("' +"):
                    continue
                if not os.path.exists(res_to_path(res)):
                    err("%s:%d: %s does not exist" % (rel(f), lineno, res))


def autoloads(cfg):
    out = {}
    for name, val in cfg.get("autoload", {}).items():
        p = val.strip('"').lstrip("*")
        out[name] = p
        if not os.path.exists(res_to_path(p)):
            err("autoload %s -> %s does not exist" % (name, p))
    return out


# ---------------------------------------------------------------------------
# 4-9. GDScript checks
# ---------------------------------------------------------------------------
GODOT3 = [
    (re.compile(r'\byield\s*\('), "yield() is Godot 3; use await"),
    (re.compile(r'^\s*onready\s+var'), "bare onready is Godot 3; use @onready"),
    (re.compile(r'^\s*export\s*(\(|var)'), "bare export is Godot 3; use @export"),
    (re.compile(r'\bsetget\b'), "setget is Godot 3"),
    (re.compile(r'\b(Spatial|KinematicBody|RigidBody|StaticBody|Area|PhysicsBody|CollisionShape|MeshInstance|Camera|ConeTwistJoint|HingeJoint|PinJoint|Generic6DOFJoint)\b(?!3D|2D)'),
     "Godot 3 node class name (needs the 3D suffix)"),
    (re.compile(r'\.connect\(\s*"'), "connect(\"signal\", ...) is Godot 3 style; use signal.connect(callable)"),
    (re.compile(r'\bdeg2rad\b|\brad2deg\b|\bstepify\b|\blinear2db\b|\bdb2linear\b'), "renamed in Godot 4"),
]

DECL_RE = re.compile(r'^(?:static\s+)?(?:func|var|const|signal|enum|class)\s+([A-Za-z_]\w*)')
ENUM_RE = re.compile(r'^enum\s+(?:[A-Za-z_]\w*\s*)?\{([^}]*)\}')
CLASS_NAME_RE = re.compile(r'^class_name\s+([A-Za-z_]\w*)')
EXTENDS_RE = re.compile(r'^extends\s+([A-Za-z_]\w*)')
ACTION_RE = re.compile(r'(?:is_action_pressed|is_action_just_pressed|is_action_just_released|is_action_released|get_action_strength|is_action|action_press|action_release)\(\s*"([^"]+)"')
AXIS_RE = re.compile(r'Input\.get_(?:axis|vector)\(([^)]*)\)')

# Members every Object/Node/Resource has (so  Foo.new()  etc. are fine).
COMMON_MEMBERS = {
    "new", "get", "set", "call", "callv", "connect", "emit_signal", "has_method", "get_class",
    "is_class", "free", "queue_free", "get_script", "set_script", "duplicate", "resource_path",
    "add_child", "get_node", "get_tree", "get_parent", "name", "multiplayer", "rpc", "rpc_id",
    "process_mode", "set_process", "set_physics_process", "is_inside_tree", "get_children",
    "get_viewport", "create_tween", "get_path", "has_node", "remove_child", "call_deferred",
    "set_deferred", "is_queued_for_deletion", "add_to_group", "get_instance_id", "tr",
}


def strip_strings_and_comments(line):
    out = []
    i = 0
    quote = None
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
            out.append(" ")
        else:
            if c == "#":
                break
            if c in "\"'":
                quote = c
                out.append(" ")
            else:
                out.append(c)
        i += 1
    return "".join(out)


def scan_gd(path):
    text = open(path, encoding="utf-8").read()
    info = {"members": set(), "class_name": None, "extends": None, "text": text, "lines": text.splitlines()}
    for line in info["lines"]:
        if line.startswith(("\t", " ")):
            continue  # only top-level declarations are members
        m = CLASS_NAME_RE.match(line)
        if m:
            info["class_name"] = m.group(1)
        m = EXTENDS_RE.match(line)
        if m:
            info["extends"] = m.group(1)
        m = DECL_RE.match(line)
        if m:
            info["members"].add(m.group(1))
        m = ENUM_RE.match(line)
        if m:
            for part in m.group(1).split(","):
                nm = part.split("=")[0].strip()
                if nm:
                    info["members"].add(nm)
    return info


def check_gdscript(autoload_map):
    scripts = {}
    for f in walk_files():
        if f.endswith(".gd"):
            scripts[f] = scan_gd(f)

    # 4. indentation
    for f, info in scripts.items():
        for lineno, line in enumerate(info["lines"], 1):
            lead = line[:len(line) - len(line.lstrip(" \t"))]
            if " " in lead and line.strip():
                err("%s:%d: indentation uses spaces (tabs only, please)" % (rel(f), lineno))
                break

    # 5. duplicate class_name
    names = {}
    for f, info in scripts.items():
        cn = info["class_name"]
        if cn:
            if cn in names:
                err("class_name %s declared in both %s and %s" % (cn, rel(names[cn]), rel(f)))
            names[cn] = f
        if info["extends"] is None and not any(l.startswith("extends") for l in info["lines"]):
            err("%s: no 'extends' line" % rel(f))

    # 6. input actions
    actions = set()
    setup = os.path.join(ROOT, "scripts/core/input_setup.gd")
    if os.path.exists(setup):
        in_actions = False
        for line in open(setup, encoding="utf-8"):
            if line.startswith("const ACTIONS"):
                in_actions = True
                continue
            if in_actions:
                if line.startswith("}"):
                    break
                m = re.match(r'\s*"([^"]+)"\s*:', line)
                if m:
                    actions.add(m.group(1))
    for f, info in scripts.items():
        for lineno, line in enumerate(info["lines"], 1):
            for m in ACTION_RE.finditer(line):
                if m.group(1) not in actions:
                    err("%s:%d: input action %r is not registered in input_setup.gd" % (rel(f), lineno, m.group(1)))
            for m in AXIS_RE.finditer(line):
                for a in re.findall(r'"([^"]+)"', m.group(1)):
                    if a not in actions:
                        err("%s:%d: input action %r is not registered" % (rel(f), lineno, a))

    # 7. Godot 3 syntax
    for f, info in scripts.items():
        for lineno, line in enumerate(info["lines"], 1):
            code = strip_strings_and_comments(line)
            for rx, why in GODOT3:
                if rx.search(code if "connect" not in why else line):
                    err("%s:%d: %s" % (rel(f), lineno, why))

    # 8. Member references on autoloads and class_names
    known = {}
    for name, p in autoload_map.items():
        sp = res_to_path(p)
        for f, info in scripts.items():
            if os.path.abspath(f) == os.path.abspath(sp):
                known[name] = info
    for cn, f in names.items():
        known[cn] = scripts[f]
    ref_re = re.compile(r'(?<![\w.])(%s)\.([A-Za-z_]\w*)' % "|".join(sorted(known.keys(), key=len, reverse=True))) if known else None
    if ref_re:
        for f, info in scripts.items():
            for lineno, line in enumerate(info["lines"], 1):
                code = strip_strings_and_comments(line)
                for m in ref_re.finditer(code):
                    owner, member = m.group(1), m.group(2)
                    target = known[owner]
                    if member in target["members"] or member in COMMON_MEMBERS:
                        continue
                    # Allow members inherited from another of our scripts.
                    parent = target["extends"]
                    found = False
                    while parent in known and not found:
                        if member in known[parent]["members"]:
                            found = True
                        parent = known[parent]["extends"]
                    if found:
                        continue
                    if member[0].isupper() and member.isupper():
                        err("%s:%d: %s has no constant/enum value %s" % (rel(f), lineno, owner, member))
                    elif target["extends"] in ("RefCounted", "Node", "Resource", "Object") or owner in autoload_map:
                        err("%s:%d: %s has no member '%s'" % (rel(f), lineno, owner, member))

    # 9. rpc targets exist
    rpc_call = re.compile(r'\b([A-Za-z_]\w*)\.rpc(?:_id)?\(')
    for f, info in scripts.items():
        for lineno, line in enumerate(info["lines"], 1):
            code = strip_strings_and_comments(line)
            for m in rpc_call.finditer(code):
                fn = m.group(1)
                if fn in ("self", "node"):
                    continue
                if fn not in info["members"]:
                    err("%s:%d: .rpc on '%s' but no such function in this file" % (rel(f), lineno, fn))
                else:
                    # the function must carry an @rpc annotation
                    idx = None
                    for i, l in enumerate(info["lines"]):
                        if re.match(r'^func\s+%s\s*\(' % re.escape(fn), l):
                            idx = i
                            break
                    if idx is not None and not info["lines"][idx - 1].startswith("@rpc"):
                        err("%s:%d: function %s is called with .rpc but has no @rpc annotation" % (rel(f), lineno, fn))
    return scripts


def check_gdtoolkit(scripts):
    try:
        from gdtoolkit.parser import parser  # type: ignore
    except Exception:
        warnings.append("gdtoolkit not installed: skipped full GDScript parse (pip install gdtoolkit)")
        return
    for f, info in scripts.items():
        try:
            parser.parse(info["text"])
        except Exception as e:  # noqa: BLE001
            first = str(e).splitlines()[0] if str(e) else repr(e)
            err("%s: GDScript parse error: %s" % (rel(f), first))


def check_scenes():
    for f in walk_files():
        if f.endswith(".tscn"):
            text = open(f, encoding="utf-8").read()
            if not text.startswith("[gd_scene"):
                err("%s: does not start with [gd_scene" % rel(f))
            ids = re.findall(r'\[ext_resource[^\]]*id="([^"]+)"', text)
            for used in re.findall(r'ExtResource\("([^"]+)"\)', text):
                if used not in ids:
                    err("%s: ExtResource(%s) not declared" % (rel(f), used))


def main():
    cfg = check_project()
    amap = autoloads(cfg)
    check_res_paths()
    scripts = check_gdscript(amap)
    check_gdtoolkit(scripts)
    check_scenes()
    for w in warnings:
        print("note: " + w)
    if errors:
        print("VALIDATION FAILED (%d problems):" % len(errors))
        for e in errors:
            print("  - " + e)
        return 1
    print("Validation OK: %d scripts checked." % len(scripts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
