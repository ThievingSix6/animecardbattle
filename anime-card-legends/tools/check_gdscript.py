#!/usr/bin/env python3
"""
Static checker for the GDScript mistakes that have actually broken this
project. Run before opening Godot:

    python3 tools/check_gdscript.py

Catches:
  1. `var x := <expr>` that cannot infer a type (Variant sources)
  2. untyped collection literals feeding a loop variable
  3. ternaries in argument lists (parser ambiguity)
  4. mixed tab/space indentation
  5. unbalanced delimiters
  6. unreachable code after a return at function-body level
     (catches a function accidentally spliced into another)
  7. locals shadowing GDScript built-in functions
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
issues = []


def add(f, line_no, kind, text):
    issues.append((f, line_no, kind, text.strip()[:90]))


for path in sorted((ROOT / "scripts").rglob("*.gd")):
    src = path.read_text(encoding="utf-8")
    lines = src.split("\n")
    rel = path.relative_to(ROOT)

    # 5. delimiters
    for o, c in [("(", ")"), ("[", "]"), ("{", "}")]:
        if src.count(o) != src.count(c):
            add(rel, 0, "DELIMITER", f"{o}{c} {src.count(o)}/{src.count(c)}")

    untyped_vars = set()

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue

        # 4. indentation
        indent = re.match(r"^[ \t]*", line).group()
        if (" " in indent and "\t" in indent) or (indent.startswith(" ") and stripped):
            add(rel, i, "INDENT", line)

        # 2. untyped literal driving a loop
        m = re.match(r"for\s+(\w+)\s+in\s+\[", stripped)
        if m:
            add(rel, i, "UNTYPED-LOOP", line)
            untyped_vars.add(m.group(1))

        # loop over an untyped dictionary access
        m = re.match(r"for\s+(\w+)\s+in\s+.*(\.get\(|\[\")", stripped)
        if m:
            untyped_vars.add(m.group(1))

        # 1. inference from a Variant source
        m = re.match(r"var\s+(\w+)\s*:=\s*(.+)$", stripped)
        if m:
            rhs = m.group(2).strip()
            # An explicit conversion or constructor gives a known type,
            # so Variant inputs inside it are fine.
            CASTS = ("float(", "int(", "str(", "bool(", "Color(", "Vector2(",
                     "Vector3(", "StringName(", "NodePath(", "hash(", "len(",
                     "abs(", "round(", "sign(", "min(", "max(")
            if rhs.startswith(CASTS):
                continue
            if re.search(r"\.get\(|\w+\[\"", rhs):
                add(rel, i, "VARIANT-INFER", line)
            else:
                for uv in untyped_vars:
                    if re.search(r"\b" + uv + r"\b", rhs):
                        add(rel, i, "VARIANT-INFER", line)
                        break

        # 3. ternary inside an argument list
        if re.search(r"\([^)]*,[^)]* if .+ else ", stripped):
            add(rel, i, "TERNARY-ARG", line)

    # untyped const collections
    for i, line in enumerate(lines, 1):
        if re.match(r"^const [A-Z_]+ := \[", line):
            add(rel, i, "UNTYPED-CONST", line)

    # 6. unreachable code after a body-level return
    in_func = False
    returned_at = 0
    open_depth = 0
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if re.match(r"^(static )?func ", line):
            in_func, returned_at, open_depth = True, 0, 0
            continue
        if not in_func:
            continue
        indent = len(re.match(r"^\t*", line).group())
        if indent == 0:
            in_func = False
            continue
        if indent == 1 and re.match(r"^return\b", stripped):
            # A return spanning several lines stays "open" until its
            # brackets balance; only then can later code be unreachable.
            depth = sum(stripped.count(c) for c in "([{") - sum(stripped.count(c) for c in ")]}")
            returned_at = i if depth <= 0 else 0
            open_depth = max(0, depth)
        elif indent == 1 and returned_at == 0 and open_depth > 0:
            open_depth += sum(stripped.count(c) for c in "([{") - sum(stripped.count(c) for c in ")]}")
            if open_depth <= 0:
                returned_at = i
                open_depth = 0
        elif indent == 1 and returned_at:
            add(rel, i, "UNREACHABLE", f"after return on line {returned_at}: {stripped}")
            returned_at = 0

    # 7. shadowing built-in functions
    BUILTINS = {
        "sign", "abs", "min", "max", "clamp", "round", "floor", "ceil", "pow",
        "sqrt", "len", "range", "str", "int", "float", "bool", "print", "hash",
        "lerp", "sin", "cos", "tan", "atan", "atan2", "exp", "log", "randf",
        "randi", "wrap", "snapped", "type_string", "instance_from_id",
    }
    for i, line in enumerate(lines, 1):
        m = re.match(r"var\s+(\w+)\s*[:=]", line.strip())
        if m and m.group(1) in BUILTINS:
            add(rel, i, "SHADOWS-BUILTIN", line)


if issues:
    print(f"{len(issues)} issue(s) found:\n")
    for f, n, kind, text in issues:
        where = f"{f}:{n}" if n else str(f)
        print(f"  [{kind:<14}] {where}")
        if text:
            print(f"                   {text}")
    sys.exit(1)

print("No issues found.")
