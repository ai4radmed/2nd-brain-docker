#!/usr/bin/env python3
"""brain-pdf — Docling + MinerU dual PDF parser CLI.

Subcommands:
  parse-docling <pdf>    Parse PDF with Docling. Stdout: JSON.
  parse-mineru  <pdf>    Parse PDF with MinerU. Stdout: JSON.
  diff <a> <b>           Compare two parser JSON outputs. Stdout: structured diff.

Phase 0~1 stubs — actual parser logic lands in P1.4 / P1.5 / P2.x per
brainify-inbox PROGRESS.md governance.
"""
import argparse
import json
import sys

VERSION = "0.1.0-design"

EX_NOT_IMPLEMENTED = 78  # sysexits.h EX_CONFIG — configuration / not-yet-built


def parse_docling(pdf_path: str) -> dict:
    raise NotImplementedError(
        "parse-docling: P1.4 / P2.1 implementation pending"
    )


def parse_mineru(pdf_path: str) -> dict:
    raise NotImplementedError(
        "parse-mineru: P1.5 / P2.2 implementation pending"
    )


def diff_outputs(a_path: str, b_path: str) -> dict:
    raise NotImplementedError(
        "diff: P2.3 implementation pending"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="brain-pdf",
        description="2nd-brain Docling+MinerU dual PDF parser",
    )
    parser.add_argument("--version", action="version", version=VERSION)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_docling = sub.add_parser("parse-docling", help="Parse PDF with Docling")
    p_docling.add_argument("pdf")

    p_mineru = sub.add_parser("parse-mineru", help="Parse PDF with MinerU")
    p_mineru.add_argument("pdf")

    p_diff = sub.add_parser("diff", help="Compare two parser outputs")
    p_diff.add_argument("a", help="Docling JSON output path")
    p_diff.add_argument("b", help="MinerU JSON output path")

    args = parser.parse_args(argv)

    try:
        if args.cmd == "parse-docling":
            result = parse_docling(args.pdf)
        elif args.cmd == "parse-mineru":
            result = parse_mineru(args.pdf)
        elif args.cmd == "diff":
            result = diff_outputs(args.a, args.b)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except NotImplementedError as e:
        print(f"[brain-pdf] {e}", file=sys.stderr)
        return EX_NOT_IMPLEMENTED


if __name__ == "__main__":
    sys.exit(main())
