"""Thin proxy: receives remote kitty calls, resolves target_window_id.
Writes or deletes entry files directly.  Knows nothing about the data format."""

import argparse
import base64
import os
import tempfile
from pathlib import Path
from typing import List

from kittens.tui.handler import result_handler

CACHE_DIR = Path.home() / ".cache" / "coding-agent-status" / "kitty"


def main(args: List[str]):
    pass


@result_handler(no_ui=True)
def handle_result(args: List[str], answer: str, target_window_id: int, boss):
    parser = argparse.ArgumentParser(
        description="Relay coding agent status update",
        add_help=False,
        exit_on_error=False,
    )
    parser.add_argument("command", choices=["write", "delete"])
    parser.add_argument("--content-b64", default="")

    try:
        parsed = parser.parse_args(args[1:])
    except SystemExit:
        return True

    file_path = CACHE_DIR / f"{target_window_id}.json"

    if parsed.command == "delete":
        try:
            file_path.unlink()
        except FileNotFoundError:
            pass
        return True

    # write
    content = base64.b64decode(parsed.content_b64.encode("ascii")).decode("utf-8")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(
        prefix="entry.", suffix=".json", dir=str(CACHE_DIR)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp, file_path)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
    return True
