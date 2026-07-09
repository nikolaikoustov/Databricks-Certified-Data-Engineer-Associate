#!/usr/bin/env python3
"""Idempotently set `targets.<target>.variables.<name>` in a bundle YAML file.

Edits the file as text (line insert/replace) rather than parsing and
re-dumping YAML, so comments and formatting elsewhere in the file are left
untouched. Only understands the plain 2-space-indent style used by this
repo's databricks.yml.

Usage: set_target_variable.py <bundle-file> <target> <var-name> <var-value>
"""
import sys


def main() -> None:
    if len(sys.argv) != 5:
        sys.exit(f"Usage: {sys.argv[0]} <bundle-file> <target> <var-name> <var-value>")
    path, target, var_name, var_value = sys.argv[1:5]

    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    target_header = f"  {target}:\n"
    try:
        header_idx = next(i for i, line in enumerate(lines) if line == target_header)
    except StopIteration:
        sys.exit(f"Target '{target}' not found in {path}")

    # Block for this target runs until the next line at indent <= 2
    # (the next target, or a comment introducing it).
    block_end = len(lines)
    for i in range(header_idx + 1, len(lines)):
        raw = lines[i]
        if raw.strip() == "":
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if indent <= 2:
            block_end = i
            break

    variables_idx = None
    for i in range(header_idx + 1, block_end):
        if lines[i] == "    variables:\n":
            variables_idx = i
            break

    new_line = f'      {var_name}: "{var_value}"\n'

    if variables_idx is not None:
        vars_end = block_end
        for i in range(variables_idx + 1, block_end):
            if lines[i].strip() and not lines[i].startswith("      "):
                vars_end = i
                break
        key_prefix = f"      {var_name}:"
        for i in range(variables_idx + 1, vars_end):
            if lines[i].startswith(key_prefix):
                lines[i] = new_line
                break
        else:
            lines.insert(vars_end, new_line)
    else:
        insert_at = block_end
        while insert_at > header_idx + 1 and lines[insert_at - 1].strip() == "":
            insert_at -= 1
        lines[insert_at:insert_at] = ["    variables:\n", new_line]

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    main()
