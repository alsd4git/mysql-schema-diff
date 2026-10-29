#!/usr/bin/env python3
"""Generate an SVG preview from SqlCompare.sh using synthetic SQL fixtures."""

from __future__ import annotations

import argparse
import html
import re
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COMPARE_SCRIPT = REPO_ROOT / "SqlCompare.sh"
DEFAULT_OUTPUT = REPO_ROOT / "docs" / "schema-diff.svg"
ANSI = re.compile(r"\x1b\[([0-9;]*)m")
COLORS = {"31": "#f38ba8", "32": "#a6e3a1"}

BEFORE_SQL = """CREATE TABLE `accounts` (
  `id` int NOT NULL,
  `email` varchar(128) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
"""
AFTER_SQL = """CREATE TABLE `accounts` (
  `id` int NOT NULL,
  `email` varchar(255) NOT NULL,
  `created_at` timestamp NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
"""


def run_comparison() -> str:
    with tempfile.TemporaryDirectory(prefix="mysql-schema-diff-") as directory:
        temporary_directory = Path(directory)
        (temporary_directory / "before.sql").write_text(BEFORE_SQL, encoding="utf-8")
        (temporary_directory / "after.sql").write_text(AFTER_SQL, encoding="utf-8")
        result = subprocess.run(
            ["bash", str(COMPARE_SCRIPT), "before.sql", "after.sql", "3"],
            cwd=temporary_directory,
            check=False,
            capture_output=True,
            text=True,
        )

    if result.returncode != 1:
        raise RuntimeError(
            "Expected mode 3 to find differences and exit 1, "
            f"got exit {result.returncode}: {result.stderr.strip()}"
        )
    if not result.stdout:
        raise RuntimeError("SqlCompare.sh produced no diff output")
    return result.stdout


def colored_spans(line: str, current_color: str) -> tuple[str, str]:
    parts: list[str] = []
    position = 0
    for match in ANSI.finditer(line):
        parts.append(
            f'<tspan fill="{current_color}">{html.escape(line[position:match.start()])}</tspan>'
        )
        codes = match.group(1).split(";") if match.group(1) else ["0"]
        current_color = next((COLORS[code] for code in codes if code in COLORS), "#cdd6f4")
        position = match.end()
    parts.append(f'<tspan fill="{current_color}">{html.escape(line[position:])}</tspan>')
    return "".join(parts), current_color


def render_svg(output: str) -> str:
    diff_lines = [
        line for line in output.rstrip("\n").splitlines() if ANSI.sub("", line)
    ]
    lines = ["$ bash SqlCompare.sh before.sql after.sql 3", *diff_lines]
    line_height = 24
    height = 48 + (len(lines) * line_height) + 18
    rendered_lines: list[str] = []
    current_color = "#cdd6f4"
    for index, line in enumerate(lines):
        spans, current_color = colored_spans(line, current_color)
        rendered_lines.append(
            f'<text x="24" y="{70 + index * line_height}" xml:space="preserve">'
            f"{spans}</text>"
        )
    rendered_markup = "\n".join(rendered_lines)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="800" height="{height}" viewBox="0 0 800 {height}" role="img" aria-labelledby="title description">
  <title id="title">SqlCompare.sh terminal diff preview</title>
  <desc id="description">A synthetic mode 3 comparison shows an email column width change and a new created_at column.</desc>
  <rect width="800" height="{height}" rx="12" fill="#181825"/>
  <path d="M12 0h776a12 12 0 0 1 12 12v34H0V12A12 12 0 0 1 12 0Z" fill="#313244"/>
  <circle cx="22" cy="23" r="6" fill="#f38ba8"/>
  <circle cx="42" cy="23" r="6" fill="#f9e2af"/>
  <circle cx="62" cy="23" r="6" fill="#a6e3a1"/>
  <text x="400" y="28" text-anchor="middle" fill="#bac2de" font-family="Arial, sans-serif" font-size="13">SqlCompare.sh</text>
  <g fill="#cdd6f4" font-family="SFMono-Regular, Consolas, monospace" font-size="14">
{rendered_markup}
  </g>
</svg>
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    output = run_comparison()
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(render_svg(output), encoding="utf-8")
    print(output, end="")
    print(f"Preview written to {arguments.output}")
    print("Exit status 1 is expected because the synthetic schemas differ.")


if __name__ == "__main__":
    main()
