#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def nix_package_json(repo: Path, system: str) -> list[dict]:
    expr = f'''
      let
        flake = builtins.getFlake "path:{repo}";
        system = "{system}";
        packages = flake.packages.${{system}};
        lib = flake.legacyPackages.${{system}}.lib;

        isDerivation = value:
          builtins.isAttrs value && (value.type or "") == "derivation";

        licenseName = license:
          if license == null then ""
          else if builtins.isList license then lib.concatMapStringsSep ", " licenseName license
          else if builtins.isAttrs license then
            license.spdxId or license.shortName or license.fullName or license.url or ""
          else if builtins.isString license then license
          else "";

        packageInfo = name:
          let
            drv = packages.${{name}};
            meta = drv.meta or {{}};
          in
          {{
            inherit name system;
            attr = "packages.${{system}}.${{name}}";
            pname = drv.pname or name;
            version = drv.version or "";
            description = meta.description or "";
            homepage = meta.homepage or "";
            mainProgram = meta.mainProgram or "";
            license = licenseName (meta.license or null);
            platforms = meta.platforms or [];
            broken = meta.broken or false;
            collection = lib.hasSuffix "-tools" name || name == "default";
          }};

        names = builtins.filter (name: isDerivation packages.${{name}}) (builtins.attrNames packages);
      in
        builtins.toJSON (map packageInfo names)
    '''
    result = subprocess.run(
        ["nix", "eval", "--json", "--impure", "--expr", expr],
        cwd=repo,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return json.loads(json.loads(result.stdout))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".", help="Repository root")
    parser.add_argument("--system", default="x86_64-linux", help="Flake system to index")
    parser.add_argument("--out", default="_site", help="Output directory")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    out = Path(args.out).resolve()
    site = repo / "site"

    out.mkdir(parents=True, exist_ok=True)
    for path in site.iterdir():
        if path.is_file():
            shutil.copy2(path, out / path.name)

    packages = nix_package_json(repo, args.system)
    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "system": args.system,
        "packageCount": len(packages),
        "packages": packages,
    }

    (out / "packages.json").write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    print(f"Wrote {out / 'packages.json'} with {len(packages)} packages")


if __name__ == "__main__":
    main()
