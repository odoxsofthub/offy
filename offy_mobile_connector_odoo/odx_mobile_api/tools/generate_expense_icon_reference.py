#!/usr/bin/env python3
"""Regenerate docs/EXPENSE_ICONS.md from the icon table in controllers/expense.py.
Run from odx_mobile_api after editing the table; reads the module via `ast`, so Odoo is not needed."""

import ast
import os
import re
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.join(HERE, "..", "controllers", "expense.py")
OUTPUT = os.path.join(HERE, "..", "docs", "EXPENSE_ICONS.md")

WANTED = ("_ICON_KEYWORDS", "DEFAULT_ICON")


def load_table():
    """Evaluate only the two assignments we need, not the whole module."""
    tree = ast.parse(open(MODULE, encoding="utf-8").read())
    namespace = {"re": re}
    for node in tree.body:
        targets = getattr(node, "targets", [])
        if isinstance(node, ast.Assign) and targets and \
                getattr(targets[0], "id", "") in WANTED:
            exec(compile(ast.Module([node], []), "<expense>", "exec"), namespace)
    missing = [name for name in WANTED if name not in namespace]
    if missing:
        raise SystemExit("could not find %s in %s" % (", ".join(missing), MODULE))
    return namespace["_ICON_KEYWORDS"], namespace["DEFAULT_ICON"]


def main():
    keywords, default = load_table()
    slugs = [icon for icon, _kw in keywords] + [default]

    lines = [
        "# Expense category icons",
        "",
        "> **Generated file — do not edit.**",
        "> Source: `controllers/expense.py` (`_ICON_KEYWORDS`).",
        "> Regenerate: `python3 tools/generate_expense_icon_reference.py`",
        "> Last generated: %s" % date.today().isoformat(),
        "",
        "The `icon` field returned by:",
        "",
        "```",
        "GET /api/mobile/v1/expense          -> data.expenses[].icon",
        "GET /api/mobile/v1/expense/categories -> data[].icon",
        "```",
        "",
        "## What it is",
        "",
        "A **stable API slug**, not a Material or FontAwesome icon name. The",
        "server classifies the expense category name (`product_id.name`); the",
        "client owns the glyph. Adding a slug is a contract *addition* — a",
        "client that does not recognise one must fall back to `%s`" % default,
        "rather than break.",
        "",
        "Purely presentational. It never affects amounts, approval or",
        "accounting, so an unrecognised category name resolving to `%s`" % default,
        "is a correct outcome, not an error.",
        "",
        "## Matching rules",
        "",
        "1. **Whole word, case-insensitive.** The name is matched against",
        "   `\\b(?:keyword|…)\\b`, never as a bare substring. This is what makes",
        "   short keywords safe: `car` does not match *card*, `tax` does not",
        "   match *taxi*, `bus` does not match *business*, `book` does not",
        "   match *booking*.",
        "2. **First match wins.** The table order below is significant and is",
        "   part of the contract — see the ordering notes at the end.",
        "3. **No match → `%s`.**" % default,
        "",
        "## The %d slugs, in evaluation order" % len(slugs),
        "",
        "| # | `icon` | Matches when the category name contains |",
        "|---|---|---|",
    ]

    for index, (icon, words) in enumerate(keywords, 1):
        lines.append("| %d | `%s` | %s |" % (index, icon, ", ".join(words)))
    lines.append("| %d | `%s` | *(default — nothing above matched)* |"
                 % (len(slugs), default))

    lines += [
        "",
        "## Ordering rules that are load-bearing",
        "",
        "If you reorder the table, preserve these:",
        "",
        "- `fuel` / `parking` / `toll` **before** `car` — otherwise a fuel or",
        "  parking claim is swallowed by the generic vehicle bucket.",
        "- `plane` **before** `car` — a bare \"Travel\" category has mapped to",
        "  `plane` since the first version; keep it there.",
        "- `building` **before** `box` — \"Office Rent\" is rent, not office",
        "  supplies, even though it contains *office*.",
        "- `car` **before** `building` — \"Car Rental\" is a vehicle. Whole-word",
        "  matching already stops `rent` matching *rental*, so this is",
        "  belt-and-braces.",
        "",
        "## Odoo's shipped categories",
        "",
        "`addons/hr_expense/data/hr_expense_data.xml` ships exactly six, which",
        "every database starts with:",
        "",
        "| Category | `icon` |",
        "|---|---|",
        "| Meals | `utensils` |",
        "| Travel & Accommodation | `plane` |",
        "| Mileage | `car` |",
        "| Gifts | `gift` |",
        "| Communication | `phone` |",
        "| Expenses | `%s` |" % default,
        "",
        "## Known limitation",
        "",
        "The keyword table is **English-only**. A database whose expense",
        "categories are named in another language classifies everything as",
        "`%s`. Fixing that properly means keying off something" % default,
        "language-independent (a category field, or an `ir.model.data` xmlid)",
        "rather than translating the table.",
        "",
        "## For client implementers",
        "",
        "`EXPENSE_ICONS` in `controllers/expense.py` exports every slug in",
        "order, so a client-side mapping can be generated from it rather than",
        "hand-copied. Always include a `default:` branch.",
        "",
        "Dart sketch:",
        "",
        "```dart",
        "IconData iconFor(String slug) {",
        "  switch (slug) {",
    ]

    for icon, _words in keywords:
        lines.append("    case '%s':" % icon)
        lines.append("      return /* your glyph */;")
    lines += [
        "    default: // includes '%s' and any slug added later" % default,
        "      return Icons.receipt_long;",
        "  }",
        "}",
        "```",
        "",
    ]

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    print("wrote %s (%d slugs)" % (os.path.normpath(OUTPUT), len(slugs)))


if __name__ == "__main__":
    main()
