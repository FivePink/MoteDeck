"""File replacement helpers for Windows redirected user-data directories."""

from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import Union


PathLike = Union[str, os.PathLike[str]]


def replace_file(source: PathLike, destination: PathLike) -> None:
    """Replace a file, with a verified fallback for WinError 17 redirection."""

    source_path = Path(source)
    destination_path = Path(destination)
    try:
        os.replace(source_path, destination_path)
        return
    except OSError as exc:
        if getattr(exc, "winerror", None) != 17:
            raise
        try:
            same_directory = os.path.samefile(
                source_path.parent, destination_path.parent
            )
        except (FileNotFoundError, OSError):
            same_directory = False
        if not same_directory:
            raise

    previous = None
    destination_exists = destination_path.exists()
    if destination_exists:
        previous = destination_path.read_bytes()
    try:
        shutil.copyfile(source_path, destination_path)
    except Exception:
        try:
            if destination_exists and previous is not None:
                destination_path.write_bytes(previous)
            elif not destination_exists:
                destination_path.unlink(missing_ok=True)
        except OSError:
            pass
        raise
