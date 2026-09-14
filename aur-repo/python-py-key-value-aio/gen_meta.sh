#!/usr/bin/env bash
# Generate the backend meta-packages for python-py-key-value-aio.
#
# Bash port of gen_meta.py (behaviour is intended to be identical).
#
# Upstream declares every storage backend as an optional extra in
# [project.optional-dependencies] of its pyproject.toml.  This script reads
# that file from the released sdist, turns each extra into an Arch
# meta-package (python-py-key-value-aio-<extra>), and rewrites the three
# generated blocks of PKGBUILD:
#
#   # >>>META-BEGIN:pkgname>>>   ...  # >>>META-END:pkgname>>>
#   # >>>META-BEGIN:deps>>>      ...  # >>>META-END:deps>>>
#   # >>>META-BEGIN:packages>>>  ...  # >>>META-END:packages>>>
#
# It is meant to run from lilac's pre_build_script *after* the version bump and
# *before* the real build:
#
#   update_pkgver_and_pkgrel(_G.newver)
#   run_protected(["updpkgsums"])     # fetches the NEW sdist first
#   run_cmd(['bash', 'gen_meta.sh'])
#
# updpkgsums runs first so the new sdist is already on disk; this script then
# reuses it and does NO network access.  Downloading remains only as a fallback
# for the first build of a brand new release.
#
# Exit codes: 0 = ok (with or without changes), 1 = error / not up to date.

set -euo pipefail

readonly PYPI_NAME="py_key_value_aio"
readonly PROG="gen_meta"

# Extras that must never become a meta-package: they are not runtime backends
# (`docs` only pulls in mkdocs to build the documentation).
readonly DEFAULT_EXCLUDED_EXTRAS="docs"

log() { printf '[%s] %s\n' "$PROG" "$*" >&2; }
die() { log "error: $*"; exit 1; }

# ------------------------------------------------------------------- mapping

# PyPI distribution name -> Arch package *suffix*.
# This is the single source of truth: both the core deps (which get their
# "python-" prefix later via ${_py_deps[@]/#/python-}) and the extra deps go
# through it, otherwise the two drift apart.
pypi_to_arch_suffix() {
  local name="${1,,}"
  case "$name" in
    dbus-python)   echo "dbus" ;;          # Arch: python-dbus
    opensearch-py) echo "opensearch" ;;    # Arch: python-opensearch
    # typing_extensions is one of the very few Arch python packages that keeps
    # the upstream underscore instead of using a hyphen.
    typing-extensions|typing_extensions) echo "typing_extensions" ;;
    *) echo "$name" ;;
  esac
}

pypi_to_arch() { printf 'python-%s\n' "$(pypi_to_arch_suffix "$1")"; }

# Extract the distribution name from a PEP 508 requirement string.
#   "rocksdict>=0.3.24 ; python_version >= '3.12'" -> rocksdict
#   "opensearch-py[async]>=2.0.0"                  -> opensearch-py
requirement_name() {
  local req="$1"
  req="${req%%;*}"                        # drop environment marker
  req="${req%%\[*}"                       # drop extras
  req="${req#"${req%%[![:space:]]*}"}"    # ltrim
  [[ $req =~ ^[A-Za-z0-9][A-Za-z0-9._-]* ]] || return 0
  printf '%s\n' "${BASH_REMATCH[0]}"
}

# -------------------------------------------------------------- PKGBUILD I/O

# Print the last assignment of a simple scalar variable in a PKGBUILD
# (last one wins, matching how bash would evaluate it).
read_pkgbuild_var() {
  local file="$1" var="$2" value="" line
  local re="^[[:space:]]*${var}[[:space:]]*=[[:space:]]*['\"]?([^'\"]+)"
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ $re ]] && value="${BASH_REMATCH[1]}"
  done < "$file"
  [[ -n $value ]] || die "no $var found in $file"
  printf '%s\n' "$value"
}

# Replace the marker block `name` with the contents of `bodyfile`.
replace_block() {
  local name="$1" bodyfile="$2" file="$3" tmp
  grep -q "^# >>>META-BEGIN:${name}>>>$" "$file" ||
    die "marker block '${name}' not found in $file; add it before running this script"

  tmp="$(mktemp)"
  awk -v name="$name" -v bodyfile="$bodyfile" '
    {
      if (inblock) {
        if ($0 == "# >>>META-END:" name ">>>") inblock = 0
        next
      }
      if ($0 == "# >>>META-BEGIN:" name ">>>") {
        print "# >>>META-BEGIN:" name ">>>"
        while ((getline line < bodyfile) > 0) print line
        close(bodyfile)
        print "# >>>META-END:" name ">>>"
        inblock = 1
        next
      }
      print
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# ----------------------------------------------------------- upstream source

# Locate the sdist that lilac/makepkg already fetched (next to the PKGBUILD, or
# in $SRCDEST).  Reusing it avoids a redundant download.
find_local_sdist() {
  local version="$1" base="$2" f="${PYPI_NAME}-${version}.tar.gz"
  if [[ -n ${SRCDEST:-} && -f ${SRCDEST}/${f} ]]; then
    printf '%s\n' "${SRCDEST}/${f}"
  elif [[ -f ${base}/${f} ]]; then
    printf '%s\n' "${base}/${f}"
  fi
}

fetch_sdist() {
  local version="$1" dest="$2" url
  url="https://files.pythonhosted.org/packages/source/${PYPI_NAME:0:1}/${PYPI_NAME}/${PYPI_NAME}-${version}.tar.gz"
  log "downloading ${url}"
  curl -fsSL --retry 2 --max-time 120 -o "$dest" "$url" ||
    die "failed to download ${url}"
}

# Print pyproject.toml from an sdist tarball.
# bsdtar ships with libarchive on Arch; --strip-components removes the
# versioned top-level directory so the path does not depend on the version.
pyproject_from_archive() {
  bsdtar -xOf "$1" --strip-components=1 "*/pyproject.toml" ||
    die "cannot extract pyproject.toml from $1"
}

# ------------------------------------------------------------- TOML parsing

# Emit one line per TOML array:
#   <section>\t<key>\t<item><US><item>...      (US = 0x1f)
# Only flat arrays of strings are handled, which is all pyproject.toml needs.
toml_arrays() {
  awk '
    function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    function collect(s,   out, m) {
      out = ""
      while (match(s, /"[^"]*"/)) {
        m = substr(s, RSTART + 1, RLENGTH - 2)
        out = out (out == "" ? "" : US) m
        s = substr(s, RSTART + RLENGTH)
      }
      return out
    }
    function emit() { if (key != "") print sect "\t" key "\t" buf; key = ""; buf = "" }
    BEGIN { US = "\037"; sect = ""; key = ""; buf = ""; inarr = 0 }
    inarr {
      line = trim($0)
      if (line ~ /^\]/) { emit(); inarr = 0; next }
      c = collect(line)
      if (c != "") buf = buf (buf == "" ? "" : US) c
      next
    }
    {
      line = trim($0)
      if (line ~ /^\[/) { sect = line; gsub(/[][]/, "", sect); next }
      if (match(line, /^[A-Za-z0-9_.-]+[ \t]*=/)) {
        k = substr(line, 1, RLENGTH)
        sub(/[ \t]*=$/, "", k)
        k = trim(k)
        rest = trim(substr(line, RLENGTH + 1))
        if (rest ~ /^\[/) {
          key = k
          buf = ""
          if (rest ~ /\]/) { buf = collect(rest); emit() }
          else inarr = 1
        }
      }
    }
    END { if (inarr) emit() }
  ' "$1"
}

# -------------------------------------------------------------- rendering

render_pkgname() {
  printf 'pkgname=(\n'
  printf '  ${pkgbase}\n'
  (( ${#EXTRAS[@]} )) && printf '  ${pkgbase}-%s\n' $(printf '%s\n' "${EXTRAS[@]}" | sort -u)
  printf ')\n'
}

render_deps() {
  printf '_py_deps=(\n'
  if (( ${#CORE[@]} )); then
    printf '%s\n' "${CORE[@]}" | sort -u | sed 's/^/  /'
  fi
  printf ')\n'
  printf 'depends=(\n'
  printf '  python\n'
  printf '  "${_py_deps[@]/#/python-}"\n'
  printf ')\n'
  printf 'optdepends=(\n'
  if (( ${#EXTRAS[@]} )); then
    # Double quotes are REQUIRED here: with single quotes bash would not expand
    # ${pkgbase}, leaving a literal "${...}" in the array, and makepkg rejects
    # optdepends entries containing "${}".
    while IFS= read -r extra; do
      printf '  "${pkgbase}-%s: %s backend (%s)"\n' \
        "$extra" "$extra" "${EXTRA_DEPS[$extra]% }"
    done < <(printf '%s\n' "${EXTRAS[@]}" | sort -u)
  fi
  printf ')\n'
}

render_packages() {
  local extra dep first=1
  while IFS= read -r extra; do
    (( first )) || printf '\n'
    first=0
    # A bash function name cannot contain "$", so "${pkgbase}-..." is not
    # usable -- spell the real name out (derived from pkgbase, not hardcoded).
    printf 'package_%s-%s() {\n' "$PKGBASE" "$extra"
    printf '  pkgdesc+=" - %s backend"\n' "$extra"
    printf '  depends=(\n'
    # No version pin: aurx64build resolves this from the local repo, and a
    # "=ver-rel" constraint only gets in the way.
    printf '    "${pkgbase}"\n'
    for dep in ${EXTRA_DEPS[$extra]}; do
      printf '    %s\n' "$dep"
    done
    printf '  )\n'
    printf '}\n'
  done < <(printf '%s\n' "${EXTRAS[@]}" | sort -u)
}

# -------------------------------------------------------------------- main

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

main() {
  local pkgbuild="PKGBUILD" version="" sdist="" check=0
  local -a user_excluded=()

  while (( $# )); do
    case "$1" in
      --pkgbuild) pkgbuild="$2"; shift 2 ;;
      --version)  version="$2"; shift 2 ;;
      --sdist)    sdist="$2"; shift 2 ;;
      --exclude)  user_excluded+=("${2,,}"); shift 2 ;;
      --check)    check=1; shift ;;
      -h|--help)  usage 0 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  [[ -f $pkgbuild ]] || die "${pkgbuild} not found"

  PKGBASE="$(read_pkgbuild_var "$pkgbuild" pkgbase)"
  [[ -n $version ]] || version="$(read_pkgbuild_var "$pkgbuild" pkgver)"
  log "pkgbase = ${PKGBASE}"
  log "version = ${version}"

  # Prefer the sdist lilac/makepkg already downloaded; only hit the network
  # when there is none (first build of a new release).
  local pyproject tmpdl=""
  if [[ -n $sdist ]]; then
    log "using local sdist: ${sdist}"
    pyproject="$(pyproject_from_archive "$sdist")"
  else
    local local_sdist
    local_sdist="$(find_local_sdist "$version" "$(dirname "$pkgbuild")")" || true
    if [[ -n $local_sdist ]]; then
      log "using local sdist: ${local_sdist}"
      pyproject="$(pyproject_from_archive "$local_sdist")"
    else
      tmpdl="$(mktemp -d)"
      fetch_sdist "$version" "${tmpdl}/sdist.tar.gz"
      pyproject="$(pyproject_from_archive "${tmpdl}/sdist.tar.gz")"
    fi
  fi

  local -a CORE=() EXTRAS=() SKIPPED=()
  local -A EXTRA_DEPS=()
  local excluded=" ${DEFAULT_EXCLUDED_EXTRAS} ${user_excluded[*]-} "

  local sect key items req name extra
  local -a reqs deps sorted
  while IFS=$'\t' read -r sect key items; do
    case "$sect" in
      project)
        [[ $key == dependencies ]] || continue
        IFS=$'\037' read -r -a reqs <<< "$items"
        for req in "${reqs[@]}"; do
          name="$(requirement_name "$req")" || continue
          [[ -n $name ]] && CORE+=("$(pypi_to_arch_suffix "$name")")
        done
        ;;
      project.optional-dependencies)
        extra="${key,,}"
        if [[ $excluded == *" ${extra} "* ]]; then
          SKIPPED+=("$extra")
          continue
        fi
        IFS=$'\037' read -r -a reqs <<< "$items"
        deps=()
        for req in "${reqs[@]}"; do
          name="$(requirement_name "$req")" || continue
          [[ -n $name ]] && deps+=("$(pypi_to_arch "$name")")
        done
        if (( ${#deps[@]} == 0 )); then
          SKIPPED+=("$extra")
          continue
        fi
        mapfile -t sorted < <(printf '%s\n' "${deps[@]}" | sort -u)
        EXTRA_DEPS["$extra"]="$(printf '%s ' "${sorted[@]}")"
        EXTRAS+=("$extra")
        ;;
    esac
  done < <(printf '%s\n' "$pyproject" | toml_arrays /dev/stdin)

  [[ -n ${tmpdl:-} ]] && rm -rf "$tmpdl"

  (( ${#SKIPPED[@]} )) && log "skipped extras: $(printf '%s\n' "${SKIPPED[@]}" | sort -u | tr '\n' ' ' | sed 's/ $//')"
  log "core deps   : $( (( ${#CORE[@]} )) && printf '%s\n' "${CORE[@]}" | sort -u | tr '\n' ' ' | sed 's/ $//')"
  log "meta packages: ${#EXTRAS[@]}"

  local original updated
  original="$(cat "$pkgbuild")"

  # The main package function is hand-written and lives outside the generated
  # blocks. makepkg needs either package_<pkgbase>() or a generic package().
  if ! grep -q "^package_${PKGBASE}()\|^package()" "$pkgbuild"; then
    log "warning: neither 'package_${PKGBASE}()' nor 'package()' found in ${pkgbuild}; the main package will not be built"
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" EXIT

  render_pkgname   > "${tmpdir}/pkgname"
  render_deps      > "${tmpdir}/deps"
  render_packages  > "${tmpdir}/packages"

  cp "$pkgbuild" "${tmpdir}/PKGBUILD"
  replace_block pkgname  "${tmpdir}/pkgname"  "${tmpdir}/PKGBUILD"
  replace_block deps     "${tmpdir}/deps"     "${tmpdir}/PKGBUILD"
  replace_block packages "${tmpdir}/packages" "${tmpdir}/PKGBUILD"

  updated="$(cat "${tmpdir}/PKGBUILD")"

  if [[ $updated == "$original" ]]; then
    log "PKGBUILD already up to date"
    return 0
  fi

  if (( check )); then
    log "PKGBUILD is NOT up to date"
    return 1
  fi

  printf '%s\n' "$updated" > "$pkgbuild"
  log "updated ${pkgbuild}"
}

main "$@"
