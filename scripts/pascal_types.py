#!/usr/bin/env python3
"""
Post-process `didc bind --target mo` output: convert snake_case type names to
PascalCase.  Field names and method names stay snake_case; only type-definition
names and their references as types are converted.

Usage:
    didc bind --target mo did/ic.did | python3 scripts/pascal_types.py > src/Types.mo
"""
import re
import sys


def snake_to_pascal(name: str) -> str:
    return "".join(w.capitalize() for w in name.split("_"))


def main() -> None:
    content = sys.stdin.read()

    # Collect every type name defined in the file.
    type_names = set(re.findall(r"public type (\w+)\s*=", content))
    mapping = {n: snake_to_pascal(n) for n in type_names if n != snake_to_pascal(n)}

    # Apply conversion line-by-line.
    # - Skip comment lines (leave them verbatim).
    # - Replace type-name occurrences that are NOT immediately followed by ' :'
    #   (the ' :' pattern marks a field name or method name, not a type reference).
    sorted_pairs = sorted(mapping.items(), key=lambda x: -len(x[0]))
    lines = []
    for line in content.split("\n"):
        if line.strip().startswith("//"):
            lines.append(line)
            continue
        for snake, pascal in sorted_pairs:
            line = re.sub(r"\b" + re.escape(snake) + r"\b(?!\s*:)", pascal, line)
        lines.append(line)

    result = "\n".join(lines)

    # The comment on line 2 contains the literal string "ic:canister_id"; the
    # replacement above turns it into "ic:CanisterId" — restore it.
    result = result.replace("ic:CanisterId", "ic:canister_id")

    sys.stdout.write(result)


if __name__ == "__main__":
    main()
