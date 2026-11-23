"""Generate herdr's plugins.json registry from Nix-built plugin directories.

herdr 的插件注册表是 ~/.config/herdr/plugins.json，平时由 `herdr plugin
install/link` 写入。这里改成完全由 Nix 生成：每个插件是一个含
herdr-plugin.toml 的 store 路径，herdr 启动时会重新读 manifest_path 里的
manifest（见 src/persist/plugin_registry.rs 的 reload_manifests），所以注册表
只需要写定位插件用的字段，action/event/build 那些都从 manifest 现读。
"""

import json
import sys
import tomllib
from pathlib import Path


def entry(root: str) -> dict[str, object]:
    manifest_path = Path(root) / "herdr-plugin.toml"
    with manifest_path.open("rb") as f:
        manifest = tomllib.load(f)
    return {
        "plugin_id": manifest["id"],
        "name": manifest["name"],
        "version": manifest["version"],
        "min_herdr_version": manifest.get("min_herdr_version", ""),
        "manifest_path": str(manifest_path),
        "plugin_root": root,
        "enabled": True,
        "source": {"kind": "local"},
    }


def main() -> None:
    entries = sorted(
        (entry(root) for root in sys.argv[1:]), key=lambda e: str(e["plugin_id"])
    )
    json.dump(entries, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
