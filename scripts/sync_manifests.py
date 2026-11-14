#!/usr/bin/env python3
"""Audit and optionally sync seL4 Google repo manifests & fetcher hygiene."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"

REMOTE_OWNERS = {
    "seL4": "seL4",
    "nanopb": "nanopb",
    "opensbi": "riscv-software-src",
    "picotcp": "tass-belgium",
    "polly": "ruslo",
    "zeromq": "zeromq",
}

# Canonical Nix flake input names for known manifest repositories
REPO_INPUT_NAMES = {
    ("seL4", "seL4"): "seL4-src",
    ("seL4", "capdl"): "capdl-src",
    ("seL4", "camkes-tool"): "camkes-tool-src",
    ("seL4", "camkes-vm-examples"): "camkes-vm-examples-src",
    ("seL4", "camkes-vm-images"): "camkes-vm-images-src",
    ("seL4", "camkes-vm-linux"): "camkes-vm-linux-src",
    ("seL4", "camkes-vm"): "camkes-vm-src",
    ("seL4", "global-components"): "global-components-src",
    ("zeromq", "libzmq"): "libzmq-src",
    ("seL4", "lwip"): "lwip-src",
    ("seL4", "musllibc"): "musllibc-src",
    ("nanopb", "nanopb"): "nanopb-src",
    ("riscv-software-src", "opensbi"): "opensbi-sel4test-src",
    ("tass-belgium", "picotcp"): "picotcp-src",
    ("ruslo", "polly"): "polly-src",
    ("seL4", "projects_libs"): "projects-libs-src",
    ("seL4", "seL4_libs"): "seL4-libs-src",
    ("seL4", "seL4_projects_libs"): "seL4-projects-libs-src",
    ("seL4", "sel4_projects_libs"): "seL4-projects-libs-src",
    ("seL4", "seL4_tools"): "seL4-tools-src",
    ("seL4", "sel4runtime"): "sel4runtime-src",
    ("seL4", "sel4test"): "sel4test-src",
    ("seL4", "util_libs"): "util-libs-src",
}

# Top-level inputs maintained outside # BEGIN/END MANIFEST INPUTS
CORE_INPUT_NAMES = {"seL4-src", "capdl-src"}

# Read-only asset repos symlinked instead of copied into $TMPDIR during unpackPhase
SYMLINK_INPUTS = {"camkes-vm-images-src"}


@dataclass(frozen=True)
class LinkFile:
    src: str
    dest: str


@dataclass(frozen=True)
class Project:
    input_name: str
    owner: str
    repo: str
    path: str
    revision: str
    linkfiles: tuple[LinkFile, ...]


def run_cmd(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{proc.stderr.strip()}")
    return proc.stdout.strip()


def get_locked_node(lock_data: dict, input_name: str) -> dict:
    nodes = lock_data.get("nodes", {})
    root_inputs = nodes.get("root", {}).get("inputs", {})
    node_key = root_inputs.get(input_name, input_name)
    if not isinstance(node_key, str):
        return {}
    return nodes.get(node_key, {})


def resolve_manifest_store_path(lock_data: dict, input_name: str) -> Path:
    node = get_locked_node(lock_data, input_name)
    locked = node.get("locked", {})
    if locked.get("type") == "github":
        url = f"github:{locked['owner']}/{locked['repo']}/{locked['rev']}"
        data = json.loads(run_cmd(["nix", "flake", "prefetch", "--json", url]))
        return Path(data["storePath"])

    # Fallback for local path/git+file overrides
    expr = f'(builtins.getFlake ("path:" + toString ./.)).inputs."{input_name}".outPath'
    return Path(run_cmd(["nix", "eval", "--impure", "--raw", "--expr", expr]))


def parse_manifest_xml(xml_path: Path) -> list[Project]:
    tree = ET.parse(xml_path)
    root = tree.getroot()

    default_el = root.find("default")
    default_remote = default_el.attrib.get("remote", "seL4") if default_el is not None else "seL4"

    projects: list[Project] = []
    for proj in root.findall("project"):
        remote = proj.attrib.get("remote", default_remote)
        owner = REMOTE_OWNERS.get(remote, remote)
        raw_name = proj.attrib["name"]
        repo = re.sub(r"\.git$", "", raw_name)
        if owner == "seL4" and repo == "sel4_projects_libs":
            repo = "seL4_projects_libs"
        path = proj.attrib["path"]
        rev = proj.attrib["revision"]
        input_name = REPO_INPUT_NAMES.get((owner, repo), f"{repo.lower().replace('_', '-')}-src")
        links = tuple(
            LinkFile(src=f"{path}/{lf.attrib['src']}", dest=lf.attrib["dest"])
            for lf in proj.findall("linkfile")
        )
        projects.append(
            Project(
                input_name=input_name,
                owner=owner,
                repo=repo,
                path=path,
                revision=rev,
                linkfiles=links,
            )
        )
    return sorted(projects, key=lambda p: p.path)


def audit_fetchers() -> list[tuple[Path, int, str]]:
    pattern = re.compile(
        r"\b(fetchFromGitHub|fetchgit|fetchPypi|fetchurl|fetchTarball|fetchGoogleRepoTool|fetchCargoVendor)\b"
    )
    hits: list[tuple[Path, int, str]] = []
    for nix_file in sorted(ROOT.rglob("*.nix")):
        for idx, line in enumerate(nix_file.read_text().splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if pattern.search(stripped):
                hits.append((nix_file.relative_to(ROOT), idx, stripped))
    return hits


def render_manifest_inputs(projects: list[Project]) -> str:
    unique: dict[str, Project] = {}
    for p in projects:
        if p.input_name not in CORE_INPUT_NAMES:
            unique[p.input_name] = p

    lines = []
    for name in sorted(unique):
        p = unique[name]
        lines.extend([
            f"    {name} = {{",
            f'      url = "github:{p.owner}/{p.repo}/{p.revision}";',
            "      flake = false;",
            "    };",
        ])
    return "\n".join(lines)


def render_workspace_nix(var_name: str, drv_name: str, projects: list[Project]) -> str:
    proj_blocks = "\n".join(
        f'      {{\n        path = "{p.path}";\n        src = inputs.{p.input_name};\n'
        + ("        symlink = true;\n" if p.input_name in SYMLINK_INPUTS else "")
        + "      }"
        for p in projects
    )
    link_blocks = "\n".join(
        f'      {{\n        src = "{lf.src}";\n        dest = "{lf.dest}";\n      }}'
        for p in projects
        for lf in p.linkfiles
    )
    return (
        f"  {var_name} = pkgs.mkRepoWorkspace {{\n"
        f'    name = "{drv_name}";\n'
        f"    projects = [\n{proj_blocks}\n    ];\n"
        f"    linkfiles = [\n{link_blocks}\n    ];\n"
        f"  }};"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write",
        action="store_true",
        help="Update flake.nix manifest block & nix/manifests.nix",
    )
    args = parser.parse_args()

    lock_data = json.loads((ROOT / "flake.lock").read_text())

    print(f"{BOLD}{CYAN}🔍 Resolving manifest flake inputs in parallel...{RESET}")
    with ThreadPoolExecutor(max_workers=4) as pool:
        futs = {
            name: pool.submit(resolve_manifest_store_path, lock_data, name)
            for name in ("sel4test-manifest-src", "camkes-vm-examples-manifest-src")
        }
        paths = {}
        for name, fut in futs.items():
            paths[name] = fut.result()
            print(f"  {GREEN}📦 {name}{RESET} -> {DIM}{paths[name]}{RESET}")

    sel4test_projects = parse_manifest_xml(paths["sel4test-manifest-src"] / "default.xml")
    camkes_projects = parse_manifest_xml(paths["camkes-vm-examples-manifest-src"] / "default.xml")
    all_projects = sel4test_projects + camkes_projects

    print(f"\n{BOLD}{CYAN}📋 Manifest vs flake.lock status:{RESET}")
    drift = 0
    seen: set[str] = set()
    for p in sorted(all_projects, key=lambda x: x.input_name):
        if p.input_name in seen:
            continue
        seen.add(p.input_name)
        node = get_locked_node(lock_data, p.input_name)
        locked_rev = node.get("locked", {}).get("rev", "MISSING")
        ok = locked_rev == p.revision
        if not ok:
            drift += 1
        icon = f"{GREEN}✅{RESET}" if ok else f"{YELLOW}⚠️ {RESET}"
        print(
            f"  {icon} {BOLD}{p.input_name:<26}{RESET} "
            f"manifest={CYAN}{p.revision[:12]}{RESET}  "
            f"lock={GREEN if ok else RED}{locked_rev[:12]}{RESET}"
        )

    print(f"\n{BOLD}{CYAN}🛡️  Auditing .nix files for non-flake fetchers:{RESET}")
    hits = audit_fetchers()
    if not hits:
        print(f"  {GREEN}✅ Zero fetch* calls found.{RESET}")
    else:
        for path, lineno, line in hits:
            color = YELLOW if "fetchCargoVendor" in line else RED
            tag = "ALLOWED (Cargo.lock)" if "fetchCargoVendor" in line else "NON-FLAKE FETCHER"
            print(f"  {color}⚠️  [{tag}] {path}:{lineno}: {line}{RESET}")

    if args.write:
        flake_path = ROOT / "flake.nix"
        flake_text = flake_path.read_text()
        begin_marker = "    # BEGIN MANIFEST INPUTS\n"
        end_marker = "\n    # END MANIFEST INPUTS"
        start = flake_text.index(begin_marker) + len(begin_marker)
        end = flake_text.index(end_marker)
        new_flake = flake_text[:start] + render_manifest_inputs(all_projects) + flake_text[end:]
        flake_path.write_text(new_flake)

        manifests_nix = (
            "{ pkgs, inputs }:\n\n{\n"
            + render_workspace_nix("sel4testWorkspace", "sel4test-workspace", sel4test_projects)
            + "\n\n"
            + render_workspace_nix("camkesVmExamplesWorkspace", "camkes-vm-examples-workspace", camkes_projects)
            + "\n}\n"
        )
        (ROOT / "nix" / "manifests.nix").write_text(manifests_nix)
        print(f"\n{GREEN}✍️  Updated flake.nix manifest block & nix/manifests.nix.{RESET}")

    print(
        f"\n{BOLD}Summary:{RESET} "
        + (
            f"{GREEN}✨ All {len(seen)} manifest inputs in sync!{RESET}"
            if drift == 0
            else f"{YELLOW}🔄 {drift} input(s) differ from upstream manifest.{RESET}"
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
