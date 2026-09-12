#!/usr/bin/env python3
"""Generate the backend meta-packages for python-py-key-value-aio.

Upstream (py-key-value-aio) declares every storage backend as an *optional*
extra in ``[project.optional-dependencies]`` of its ``pyproject.toml``.  This
script reads that file from the released sdist, turns each extra into an Arch
meta-package (``python-py-key-value-aio-<extra>``), and rewrites the generated
blocks of ``PKGBUILD``.

It is meant to run from lilac's ``pre_build_script``, after the version bump
and *before* the real build (the pkgname array must be final by then):

    update_pkgver_and_pkgrel(_G.newver)
    run_protected(["updpkgsums"])   # fetches the NEW sdist first
    run_cmd(['python', 'gen_meta.py'])

Note the order: ``updpkgsums`` runs first so the sdist of the new version is
already on disk (makepkg downloads it next to the PKGBUILD). This script then
reads that local tarball and performs NO network access. Downloading remains
only as a fallback when no local copy exists, and any file it fetches is left
in place so makepkg reuses it -- there is never more than one download.

The version is read back from the PKGBUILD (which lilac has just updated), so
the script never has to be told the version explicitly.

Only the regions delimited by the markers below are ever rewritten; everything
else in the PKGBUILD is left untouched:

    # >>>META-BEGIN:pkgname>>>   ...   # >>>META-END:pkgname>>>
    # >>>META-BEGIN:deps>>>      ...   # >>>META-END:deps>>>
    # >>>META-BEGIN:packages>>>  ...   # >>>META-END:packages>>>

Exit codes: 0 = ok (with or without changes), 1 = error.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tomllib
import urllib.request
from pathlib import Path
from tempfile import TemporaryDirectory

PYPI_NAME = "py_key_value_aio"
SDIST_URL = (
    "https://files.pythonhosted.org/packages/source/"
    f"{PYPI_NAME[0]}/{PYPI_NAME}/{PYPI_NAME}-{{version}}.tar.gz"
)

# Extras that must never become a meta-package: they are not runtime backends.
# `docs` only pulls in mkdocs to build the documentation.
DEFAULT_EXCLUDED_EXTRAS = {"docs"}

# PyPI distribution name -> Arch package suffix, for the cases that do not
# follow the plain "python-<pypi name>" rule.
PYPI_TO_ARCH_SUFFIX = {
    "dbus-python": "dbus",          # Arch: python-dbus
    "opensearch-py": "opensearch",  # Arch: python-opensearch
    # typing_extensions is one of the very few Arch python packages that keeps
    # the upstream underscore instead of using a hyphen.
    "typing-extensions": "typing_extensions",
    "typing_extensions": "typing_extensions",
}

MARKER_RE = re.compile(
    r"^# >>>META-BEGIN:(?P<name>[a-z]+)>>>.*?^# >>>META-END:(?P=name)>>>",
    re.DOTALL | re.MULTILINE,
)


def log(msg: str) -> None:
    print(f"[gen_meta] {msg}", file=sys.stderr)


# ---------------------------------------------------------------- PKGBUILD I/O


def read_pkgver(pkgbuild: Path) -> str:
    """Return the current pkgver from a PKGBUILD (last assignment wins)."""
    version = None
    for line in pkgbuild.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*pkgver\s*=\s*['\"]?([^'\"]+)['\"]?", line)
        if m:
            version = m.group(1)
    if not version:
        raise SystemExit(f"error: no pkgver found in {pkgbuild}")
    return version


def read_pkgbase(pkgbuild: Path) -> str:
    """Return pkgbase, which is also the name of the main package."""
    value = None
    for line in pkgbuild.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*pkgbase\s*=\s*['\"]?([^'\"]+)['\"]?", line)
        if m:
            value = m.group(1)
    if not value:
        raise SystemExit(f"error: no pkgbase found in {pkgbuild}")
    return value


def replace_block(text: str, name: str, body: str) -> str:
    """Replace the marker block `name` with `body`, keeping one blank line."""
    block = (
        f"# >>>META-BEGIN:{name}>>>\n"
        f"{body.rstrip()}\n"
        f"# >>>META-END:{name}>>>"
    )
    pattern = re.compile(
        rf"^# >>>META-BEGIN:{name}>>>.*?^# >>>META-END:{name}>>>",
        re.DOTALL | re.MULTILINE,
    )
    if not pattern.search(text):
        raise SystemExit(
            f"error: marker block '{name}' not found in PKGBUILD; "
            "add it before running this script"
        )
    return pattern.sub(lambda _m: block, text, count=1)


# ------------------------------------------------------------ upstream parsing


def read_pyproject_from_archive(archive: Path) -> dict:
    """Extract and parse the pyproject.toml held inside an sdist tarball."""
    import subprocess

    # bsdtar ships with libarchive on Arch; strip the top-level directory so the
    # path does not depend on the sdist's versioned root folder.
    out = subprocess.run(
        ["bsdtar", "-xOf", str(archive), "--strip-components=1", "*/pyproject.toml"],
        capture_output=True,
        check=True,
    )
    return tomllib.loads(out.stdout.decode("utf-8"))


def find_local_sdist(base: Path, version: str) -> Path | None:
    """Return an sdist that lilac/makepkg already fetched, if there is one.

    makepkg normally leaves the tarball next to the PKGBUILD (or in $SRCDEST).
    Reusing it avoids a redundant download: lilac has to fetch the source
    anyway, and makepkg/updpkgsums will reuse this same file afterwards.
    """
    filename = f"{PYPI_NAME}-{version}.tar.gz"
    candidates = [base / filename]
    srcdest = os.environ.get("SRCDEST")
    if srcdest:
        candidates.insert(0, Path(srcdest).expanduser() / filename)
    for cand in candidates:
        if cand.is_file():
            return cand
    return None


def fetch_pyproject(version: str) -> dict:
    """Download the sdist for `version` and return its parsed pyproject.toml.

    Only used as a fallback when no local copy exists yet (e.g. the first build
    of a brand new upstream release).
    """
    url = SDIST_URL.format(version=version)
    log(f"downloading {url}")
    with TemporaryDirectory() as tmp:
        archive = Path(tmp) / "sdist.tar.gz"
        with urllib.request.urlopen(url, timeout=120) as resp, open(archive, "wb") as fh:
            fh.write(resp.read())
        return read_pyproject_from_archive(archive)


_REQ_NAME_RE = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)")


def requirement_name(req: str) -> str | None:
    """Extract the distribution name from a PEP 508 requirement string."""
    # Drop environment markers ("; python_version >= '3.12'") and extras ("[async]").
    req = req.split(";", 1)[0]
    req = re.sub(r"\[[^\]]*\]", "", req).strip()
    m = _REQ_NAME_RE.match(req)
    return m.group(1) if m else None


def pypi_to_arch_suffix(name: str) -> str:
    """Map a PyPI distribution name to an Arch package *suffix*.

    This is the single source of truth for the mapping; both the core deps
    (which get the "python-" prefix later, via ${_py_deps[@]/#/python-}) and
    the extra deps must go through it, otherwise the two drift apart.
    """
    return PYPI_TO_ARCH_SUFFIX.get(name.lower(), name.lower())


def pypi_to_arch(name: str) -> str:
    """Map a PyPI distribution name to the Arch package name."""
    return f"python-{pypi_to_arch_suffix(name)}"


# ------------------------------------------------------------------ generation


def render_pkgname(extras: list[str], pkgbuild: str) -> str:
    # Preserve the current ordering of the pkgname array as much as possible so
    # the diff stays small across runs.
    lines = [f"  ${{{'pkgbase'}}}"]
    for extra in extras:
        lines.append(f"  ${{pkgbase}}-{extra}")
    return "pkgname=(\n" + "\n".join(lines) + "\n)"


def render_deps(core: list[str], extras: dict[str, list[str]]) -> str:
    out = ["_py_deps=("]
    for dep in core:
        out.append(f"  {dep}")
    out.append(")")
    out.append("depends=(")
    out.append("  python")
    out.append('  "${_py_deps[@]/#/python-}"')
    out.append(")")
    out.append("optdepends=(")
    for extra in sorted(extras):
        arch_deps = " ".join(sorted(extras[extra]))
        # Double quotes are REQUIRED here: with single quotes bash would not
        # expand ${pkgbase}, leaving a literal "${...}" in the array, and
        # makepkg rejects optdepends entries containing "${}".
        out.append(f'  "${{pkgbase}}-{extra}: {extra} backend ({arch_deps})"')
    out.append(")")
    return "\n".join(out)


def render_packages(extras: dict[str, list[str]], pkgbase: str) -> str:
    """Render one package_<pkgbase>-<extra>() function per meta package.

    The main package (package_<pkgbase>()) is NOT generated here: it lives
    outside the marker block and is maintained by hand, because it is the one
    that actually installs files.
    """
    chunks = []
    for extra in sorted(extras):
        deps = sorted(extras[extra])
        # A bash function name cannot contain "$", so "${pkgbase}-..." is not
        # usable -- spell the real name out (derived from pkgbase, not hardcoded).
        body = [f"package_{pkgbase}-{extra}() {{"]
        body.append(f'  pkgdesc+=" - {extra} backend"')
        body.append("  depends=(")
        # No version pin: aurx64build resolves this from the local repo, and a
        # "=ver-rel" constraint only gets in the way when the packages are
        # installed from a build directory.
        body.append('    "${pkgbase}"')
        for dep in deps:
            body.append(f"    {dep}")
        body.append("  )")
        body.append("}")
        chunks.append("\n".join(body))
    return "\n\n".join(chunks)


# ------------------------------------------------------------------------ main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pkgbuild", default="PKGBUILD", type=Path)
    ap.add_argument("--version", help="override the version (default: from PKGBUILD)")
    ap.add_argument(
        "--sdist",
        type=Path,
        help="use this local sdist tarball instead of looking one up / downloading",
    )
    ap.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="EXTRA",
        help="extra to skip (repeatable); always excludes: "
        + ", ".join(sorted(DEFAULT_EXCLUDED_EXTRAS)),
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="only report whether the PKGBUILD is up to date",
    )
    args = ap.parse_args()

    pkgbuild: Path = args.pkgbuild
    if not pkgbuild.exists():
        log(f"error: {pkgbuild} not found")
        return 1

    pkgbase = read_pkgbase(pkgbuild)
    version = args.version or read_pkgver(pkgbuild)
    log(f"pkgbase = {pkgbase}")
    log(f"version = {version}")

    # Prefer the sdist that lilac/makepkg already downloaded; only hit the
    # network when there is none (first build of a new release).
    local = args.sdist or find_local_sdist(pkgbuild.resolve().parent, version)
    if local:
        log(f"using local sdist: {local}")
        data = read_pyproject_from_archive(local)
    else:
        data = fetch_pyproject(version)

    project = data.get("project", {})
    core_raw = project.get("dependencies", []) or []
    optional = project.get("optional-dependencies", {}) or {}

    # Core runtime dependencies (no extra marker) -> main package.
    core = []
    for req in core_raw:
        name = requirement_name(req)
        if name:
            core.append(pypi_to_arch_suffix(name))
    core = sorted(set(core))

    excluded = set(DEFAULT_EXCLUDED_EXTRAS) | {e.lower() for e in args.exclude}

    extras: dict[str, list[str]] = {}
    skipped: list[str] = []
    for extra, reqs in optional.items():
        if extra.lower() in excluded:
            skipped.append(extra)
            continue
        arch_deps = set()
        for req in reqs:
            name = requirement_name(req)
            if name:
                arch_deps.add(pypi_to_arch(name))
        if not arch_deps:
            skipped.append(extra)
            continue
        extras[extra.lower()] = sorted(arch_deps)

    if skipped:
        log("skipped extras: " + ", ".join(sorted(skipped)))
    log(f"core deps   : {', '.join(core)}")
    log(f"meta packages: {len(extras)}")

    original = pkgbuild.read_text(encoding="utf-8")

    # The main package function is hand-written and lives outside the generated
    # blocks. makepkg needs either package_<pkgbase>() or a generic package().
    # Warn loudly instead of silently producing a build that cannot work.
    if f"package_{pkgbase}()" not in original and "package()" not in original:
        log(
            f"warning: neither 'package_{pkgbase}()' nor 'package()' found in "
            f"{pkgbuild}; the main package will not be built"
        )

    updated = original
    updated = replace_block(updated, "pkgname", render_pkgname(sorted(extras), updated))
    updated = replace_block(updated, "deps", render_deps(core, extras))
    updated = replace_block(updated, "packages", render_packages(extras, pkgbase))

    if updated == original:
        log("PKGBUILD already up to date")
        return 0

    if args.check:
        log("PKGBUILD is NOT up to date")
        return 1

    pkgbuild.write_text(updated, encoding="utf-8")
    log(f"updated {pkgbuild}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
