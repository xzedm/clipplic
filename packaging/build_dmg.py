#!/usr/bin/env python3
"""Package an exported Clipplic app with a persistent Finder installer layout."""

import argparse
import plistlib
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Path to the exported .app bundle")
    parser.add_argument("--output", type=Path, help="Destination .dmg (must not exist)")
    args = parser.parse_args()

    if sys.platform != "darwin":
        parser.error("DMG packaging requires macOS")

    app = args.app.resolve()
    try:
        with (app / "Contents" / "Info.plist").open("rb") as source:
            info = plistlib.load(source)
    except (OSError, plistlib.InvalidFileException) as error:
        parser.error(f"Cannot read the app bundle: {error}")
    if app.suffix != ".app" or info.get("CFBundleIdentifier") != "com.xzedm.clipplic":
        parser.error("Expected an exported Clipplic .app bundle")

    root = Path(__file__).resolve().parent.parent
    version = info["CFBundleShortVersionString"]
    output = (args.output or root / "build" / f"Clipplic-{version}.dmg").resolve()
    if output.suffix != ".dmg":
        parser.error("The output filename must end in .dmg")
    if output.exists():
        parser.error(f"Output already exists; choose a new filename: {output}")

    try:
        from dmgbuild import build_dmg
    except ImportError:
        parser.error("Install packaging/requirements.txt in a virtual environment first")

    output.parent.mkdir(parents=True, exist_ok=True)
    # Write .DS_Store directly so layout does not depend on Finder preferences
    # or on AppleScript successfully saving a window during a release build.
    settings = {
        "files": [str(app)],
        "symlinks": {"Applications": "/Applications"},
        "format": "UDZO",
        "filesystem": "HFS+",
        "background": str(root / "packaging" / "background.png"),
        "window_rect": ((200, 160), (560, 320)),
        "default_view": "icon-view",
        "include_icon_view_settings": True,
        "include_list_view_settings": False,
        "show_status_bar": False,
        "show_tab_view": False,
        "show_toolbar": False,
        "show_pathbar": False,
        "show_sidebar": False,
        "show_icon_preview": False,
        "show_item_info": False,
        "arrange_by": None,
        "scroll_position": (0, 0),
        "label_pos": "bottom",
        "text_size": 13,
        "icon_size": 80,
        "icon_locations": {app.name: (140, 165), "Applications": (420, 165)},
    }
    build_dmg(str(output), "Clipplic", settings=settings)
    print(f"Created {output}")


if __name__ == "__main__":
    main()
