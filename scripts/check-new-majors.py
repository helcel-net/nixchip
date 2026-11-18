#!/usr/bin/env python3
"""Report upstream releases whose major is newer than our highest _N slot.

Major-pinned slots (attrs ending in _N) only follow their own release series
in scripts/update-packages.sh, so a new upstream major never shows up as an
update PR. This lists them as a markdown checklist for a tracking issue.
"""
import argparse
import json
import re
import subprocess
import sys

# Release tags: an optional one-word prefix (z3-, cvc5-, release/, vtr_), an
# optional v or r (nvc tags r1.9.0), a dotted version (5.4.1, 13_0, 26Q2), and
# an optional git-describe suffix (verible tags v0.0-4302-gc6b29d62). Stricter than the
# per-slot regex in update-packages.sh, which is anchored to a known major;
# here snapshot and date tags (v3.0-SNAPSHOT_2017-09-14, smtcomp-2021) would
# otherwise read as new majors.
TAG_RE = re.compile(
    r"^(?:[A-Za-z][A-Za-z0-9]*[-_/])?[vr]?([0-9]+)((?:[._Q][0-9]+)+[a-z]?)(?:-[0-9]+-g[0-9a-f]+)?$"
)

# Tags that parse as a newer major but are not one: family -> ignored majors.
IGNORED = {
    "fusesoc": {"3"},  # orpsoc-3.x tags are fusesoc's pre-2.0 predecessor
}

ISSUE_ITEM_RE = re.compile(r"^- \[([ xX])\] \*\*([^*]+)\*\* (\d+)", re.M)


def slot_families(system: str) -> list[dict]:
    expr = """
      pkgs:
      let
        slots = builtins.filter (n: builtins.match ".*_[0-9]+$" n != null) (builtins.attrNames pkgs);
        info = n: {
          attr = n;
          family = builtins.head (builtins.match "(.*)_[0-9]+$" n);
          major = builtins.head (builtins.match ".*_([0-9]+)$" n);
          # fetchgit sources (xyce) expose their URL as src.url.
          repo = pkgs.${n}.src.gitRepoUrl or (
            let u = pkgs.${n}.src.url or ""; in
            if builtins.match "(https://|git://).*" u != null && builtins.match ".*(sourceforge|hackage|pythonhosted).*" u == null then u else ""
          );
        };
      in builtins.map info slots
    """
    out = subprocess.run(
        ["nix", "eval", "--json", f".#packages.{system}", "--apply", expr],
        check=True, capture_output=True, text=True,
    ).stdout
    families: dict[str, dict] = {}
    for slot in json.loads(out):
        fam = families.setdefault(slot["family"], {"family": slot["family"], "major": -1, "attr": "", "repo": ""})
        if int(slot["major"]) > fam["major"]:
            fam.update(major=int(slot["major"]), attr=slot["attr"])
        fam["repo"] = fam["repo"] or slot["repo"]
    return sorted(families.values(), key=lambda f: f["family"])


def upstream_releases(repo: str) -> dict[int, str]:
    """Newest release tag per major, from `git ls-remote --tags`."""
    out = subprocess.run(
        ["git", "ls-remote", "--tags", "--refs", repo],
        check=True, capture_output=True, text=True, timeout=60,
    ).stdout
    newest: dict[int, tuple] = {}
    for line in out.splitlines():
        tag = line.split("refs/tags/", 1)[1]
        m = TAG_RE.match(tag)
        if not m:
            continue
        major = int(m.group(1))
        key = tuple(int(x) for x in re.findall(r"[0-9]+", m.group(1) + m.group(2)))
        if major not in newest or key > newest[major][0]:
            newest[major] = (key, tag)
    return {major: tag for major, (_, tag) in newest.items()}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--system", default="x86_64-linux")
    parser.add_argument("--previous-body", help="file with the current issue body, to keep ticked boxes")
    args = parser.parse_args()

    ticked = set()
    if args.previous_body:
        with open(args.previous_body) as f:
            ticked = {(m[1], m[2]) for m in ISSUE_ITEM_RE.findall(f.read()) if m[0] in "xX"}

    items, unchecked = [], []
    for fam in slot_families(args.system):
        if not fam["repo"]:
            unchecked.append(fam["attr"])
            continue
        try:
            releases = upstream_releases(fam["repo"])
        except (subprocess.SubprocessError, OSError) as e:
            print(f"warning: {fam['family']}: {e}", file=sys.stderr)
            unchecked.append(fam["attr"])
            continue
        for major in sorted(releases):
            if major <= fam["major"] or str(major) in IGNORED.get(fam["family"], set()):
                continue
            box = "x" if (fam["family"], str(major)) in ticked else " "
            items.append(
                f"- [{box}] **{fam['family']}** {major} — upstream `{releases[major]}`, "
                f"newest slot `{fam['attr']}` — add `{fam['family']}_{major}` ({fam['repo']})"
            )

    if items:
        print("Upstream has released majors newer than our highest slot. "
              "Add a `<family>_<major>` slot in `pkgs/default.nix` for each; "
              "the item disappears once the slot exists.\n")
        print("\n".join(items))
        if unchecked:
            print("\nNot checked (no git source): " + ", ".join(f"`{a}`" for a in unchecked))
    return 0


if __name__ == "__main__":
    sys.exit(main())
