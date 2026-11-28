#!/usr/bin/env python3
"""Writes the third-party notices of the Licenses screen (About > Licenses).

What ships in the app besides Pass-Y's own code (GPLv3, based on Bitwarden iOS):
- the Bitwarden SDK (Swift package `sdk-swift`, pinned in project-common.yml), a binary built from the Rust workspace
  `bitwarden/sdk-internal`; its Rust crates are listed from `cargo about` (see below),
- SwiftUI-Introspect (Swift package of BitwardenKit, project-bwk.yml),
- the Inter font files in BitwardenResources/Fonts.
Swift packages used only by tests (ViewInspector, swift-snapshot-testing, ...) do not ship and are not listed.

Crate list (a superset: it also contains crates used only while compiling, such as proc-macros):

    git clone https://github.com/bitwarden/sdk-internal && cd sdk-internal && git checkout <sdk-internal revision>
    cargo install cargo-about --locked --features cli
    cargo about generate --format json --locked -m crates/bitwarden-uniffi/Cargo.toml \
        --target aarch64-apple-ios -c <repo>/Scripts-passy/third-party-licenses/about.toml -o licenses.json

Then: Scripts-passy/generate_third_party_notices.py licenses.json <sdk-internal revision>
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INPUTS = ROOT / "Scripts-passy" / "third-party-licenses"
OUTPUT = ROOT / "BitwardenShared/UI/Platform/Settings/Settings/About/Licenses/ThirdPartyNotices.json"


def main() -> None:
    about_path, sdk_revision = sys.argv[1], sys.argv[2]
    about = json.loads(pathlib.Path(about_path).read_text())

    texts: list[str] = []
    index: dict[str, int] = {}

    def text_id(text: str) -> int:
        text = text.strip("\n") + "\n"
        if text not in index:
            index[text] = len(texts)
            texts.append(text)
        return index[text]

    gpl = text_id((ROOT / "LICENSE.txt").read_text())

    crates: dict[str, dict] = {}
    for license in about["licenses"]:
        # The GPL of the SDK's own crates is the same GPLv3 as Pass-Y's.
        tid = gpl if license["id"].startswith("GPL-3.0") else text_id(license["text"])
        for used in license["used_by"]:
            package = used["crate"]
            key = f'{package["name"]} {package["version"]}'
            entry = crates.setdefault(key, {
                "name": package["name"],
                "version": package["version"],
                "license": package.get("license") or license["id"],
                "texts": [],
            })
            if tid not in entry["texts"]:
                entry["texts"].append(tid)
    for entry in about["crates"]:
        package = entry["package"]
        key = f'{package["name"]} {package["version"]}'
        if key not in crates:
            raise SystemExit(f"{key}: no licence text")

    components = [
        {
            "name": "Bitwarden SDK",
            "version": f"sdk-internal {sdk_revision}",
            "license": "GPL-3.0-only OR LicenseRef-Bitwarden-SDK (used under GPL-3.0-only)",
            "url": "https://github.com/bitwarden/sdk-internal",
            "texts": [text_id((INPUTS / "sdk-internal-LICENSE").read_text()), gpl],
        },
        {
            "name": "SwiftUI-Introspect",
            "version": "27.1.0",
            "license": "MIT",
            "url": "https://github.com/siteline/swiftui-introspect",
            "texts": [text_id((INPUTS / "SwiftUI-Introspect-LICENSE").read_text())],
        },
        {
            "name": "Inter",
            "version": "",
            "license": "OFL-1.1",
            "url": "https://github.com/rsms/inter",
            "texts": [text_id((INPUTS / "Inter-LICENSE.txt").read_text())],
        },
    ]

    notices = {
        "sdkRevision": sdk_revision,
        "gplText": gpl,
        "components": components,
        "crates": sorted(crates.values(), key=lambda c: (c["name"].lower(), c["version"])),
        "texts": texts,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(notices, ensure_ascii=False, indent=1) + "\n")
    print(f"{len(crates)} crates, {len(texts)} texts, {OUTPUT.stat().st_size // 1024} KB -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
