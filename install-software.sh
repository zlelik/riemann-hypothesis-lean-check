#!/usr/bin/env bash
#
# install-software.sh
#
# Part 1 of 2 for verifying a Lean proof; part 2 is run-checks.sh. README.md explains every step
# in section "1. Software installation"; this script prints the same step numbers.
#
# The script first asks which Lean project to install:
#   1  riemann-hypothesis  the proof of the Riemann Hypothesis claim, published at https://alpo.ge
#                          as lean.tar.gz.part01 ... lean.tar.gz.part14
#   2  test-project        a small Lean project that proves sin(x)^2 + cos(x)^2 = 1; with it, all
#                          steps can be tried in a few minutes instead of days
# It then downloads the project, joins and unpacks it, confirms that the files are identical to
# the published files, and installs all software that run-checks.sh needs.
#
# Usage, in the folder where everything should be stored (normally the folder of this script):
#   ./install-software.sh                               asks which project to install
#   PROJECT=riemann-hypothesis ./install-software.sh    installs that project without asking
#   PROJECT=test-project ./install-software.sh          installs that project without asking
#
# Everything is written into the folder from which you start the script (WORK_DIR), including
# elan, Lean, Rust and all downloaded files; nothing is written into your home folder. The only
# exception: system tools that are missing (step 1.2) are installed into the operating system
# with apt-get, which needs administrator rights.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =================================================================================================
# Settings that you can change
# =================================================================================================

# Where the test project comes from: a web link to a .tar.gz archive of the test project, for
# example "https://example.org/test-project.tar.gz", or the path of such an archive on this
# computer. The default is the archive test-project.tar.gz in this repository.
TEST_PROJECT_URL="$REPO_DIR/test-project.tar.gz"

# SHA-256 checksum of that archive. If you change the test project, put the checksum of the new
# archive here (README.md, section "The two projects"), or leave the quotes empty ("") to skip
# this comparison.
TEST_PROJECT_SHA256="e2fb653639cd758859cb10f90356ad3c7b2f8a81396fe4bae24060296f4dd224"

# Working folder: by default the folder from which you start the script. Start run-checks.sh from
# the same folder. Another folder can be set as an environment variable, for example:
# WORK_DIR=/data/rh-check ./install-software.sh
WORK_DIR="${WORK_DIR:-$PWD}"
mkdir -p "$WORK_DIR" && WORK_DIR="$(cd "$WORK_DIR" && pwd)"
TOOLS_DIR="${TOOLS_DIR:-$WORK_DIR/tools}"

# elan, Lean, Rust and Mathlib's downloaded files are installed inside TOOLS_DIR, not in the home
# folder. run-checks.sh uses the same settings.
export ELAN_HOME="$TOOLS_DIR/elan"
export RUSTUP_HOME="$TOOLS_DIR/rustup"
export CARGO_HOME="$TOOLS_DIR/cargo"
export MATHLIB_CACHE_DIR="$TOOLS_DIR/mathlib-cache"
export PATH="$ELAN_HOME/bin:$CARGO_HOME/bin:$PATH"

# =================================================================================================
# Reference values of the published files (README.md, section "Checksums")
# =================================================================================================

# Riemann Hypothesis proof: computed from the files downloaded from https://alpo.ge on
# 21 November 2026.
RH_PART_URL="https://alpo.ge/lean.tar.gz.part"     # followed by 01, 02, ..., 14
RH_PART_SHA256=(
  "86974b1c242ca7b6748f3299df4fc64ee0f6e06c776ac964fb64888101a3de77"  # part01
  "1c2a2477354a9dfa97ff1ce54861e96ed885bd456fffbaaabc2028314a229c42"  # part02
  "1465a23b1b579a881e24e5ffaf7c4c3727af28ea24741f1ec80e1d67947530a3"  # part03
  "3929e327eecb4e2c5c7cae30e104e6a4a52fa6b82d28325bcda8e9da1c86893b"  # part04
  "f25d7e80f7c4ad6d674aa18b323ca760f848857c8755501c149317c38a66c75d"  # part05
  "a8c651a68327811b37dce3cca8eda5e0b2102fa227c0d395cbb7553e4dd69939"  # part06
  "65c7e502a9b236a0f68d9e0aa6e089d4c09b9fc7a0960a149384063ccbe5e869"  # part07
  "71b027ad6e4179c3a50ce72921e3fec0a2dd751ec7472ac2c644ad145a50ec7e"  # part08
  "47718977ebaa8613f1647e93134479780db9320c5fa911463fd312a6257b796f"  # part09
  "1d85ece78e0779cec26b0cce29c6462d9f90180e56d78120b152df101715240b"  # part10
  "cf83a159d1a9540012229c376562587dd966da10cd657cbcef53acfd03232448"  # part11
  "1aa5415bd2db83b2689afeeb946419303b3c4f599ae790ad74d38465f768b502"  # part12
  "2de4edbce8ebdbfd0b94bc89bab518c7294209f408ec5b14a7be9e4832d9da81"  # part13
  "53f8ea43a9b5dcab97b84a52f3ac2848711c844a5420a4c56418093bacb3c6f6"  # part14
)
RH_ARCHIVE_SHA256="9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc"
RH_FILES_SHA256="006b98c1b955017540cd9e2dc8e95936da168de104427bf170528e93bd6ebebe"   # step 1.8
RH_MANIFEST_SHA256="fee57ee9ed399d0a638ca955e5ad40a37a36eeb9b6dfd9f5964114fa7bbe4774"

# Library versions that lake-manifest.json must pin: folder name and Git commit. Both projects use
# the same versions.
PINNED_LIBRARIES=(
  "mathlib 0df444a360eaa60ab8c11dca51a86af692955474"
  "plausible b7eb3304aeae834b12dda98993a37f6a41f6f0bb"
  "LeanSearchClient 5f4d51b81cbd3f6b32b156bfad9056621a040404"
  "importGraph 16f02aa7642864af59f1ff0e384a015994db9118"
  "proofwidgets 4be2e3d5087eeb272cf5a8853b8f9dd025ef5957"
  "aesop 3448c0bcc5ce01b2d1546e483ec3620e32df3d0e"
  "Qq 92c15be17b7caf78c2ad767ec40f89052d908d81"
  "batteries 4488d40d070b9700d4d5a6aa342f0d40c31b2a2d"
  "Cli 6130a47896ce867c6a4a55373441e59e565bad0f"
)

# Versions of the checking tools (README.md, section "Versions of the checking tools").
# lean4export and Lean4Lean are built with the Lean version of the project.
LEAN4EXPORT_COMMIT="15f6055e299ad5b89345e533cc2192f4cc00f659"   # tag v4.33.0
LEAN4LEAN_COMMIT="67f63b0c818920dfaed2ad07ccff187a6a8fe1e3"     # newest version on 21 November 2026
NANODA_COMMIT="0da9f98feadd3a0a2ef4b3dbcf52a298a6fef929"        # nanoda_lib 0.4.32, newest on 21 November 2026

# =================================================================================================

say()    { printf '\n==> %s\n' "$*"; }
warn()   { printf 'WARNING: %s\n' "$*" >&2; }
die()    { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
sha256() { sha256sum "$1" | cut -d' ' -f1; }
FAILED=()

# Downloads $1 (a web link, or the path of a file on this computer) into the file $2.
fetch() {
  case "$1" in
    http://*|https://*|file://*) curl -fsSL --retry 5 --retry-delay 10 -o "$2" "$1" ;;
    *) cp "$1" "$2" ;;
  esac
}

# Checksum over all unpacked files, except the folder .lake (created by Lake) and
# lake-manifest.json (which Lake may rewrite; the pinned versions in it are checked separately).
files_checksum() {
  (cd "$PROJECT_WORK_DIR" && find lean -path lean/.lake -prune -o -type f ! -path lean/lake-manifest.json -print0 \
     | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
}

# Puts the Git working copy in folder $1 at commit $2.
checkout_commit() {
  git -C "$1" checkout -q -f "$2" 2>/dev/null \
    || { git -C "$1" fetch -q origin && git -C "$1" checkout -q -f "$2"; }
}

# -------------------------------------------------------------------------------------------------
say "1.1 Choose the project"
PROJECT="${PROJECT:-}"
if [ -z "$PROJECT" ]; then
  echo "Which Lean project do you want to install?"
  echo "  1  riemann-hypothesis: the proof of the Riemann Hypothesis claim, from https://alpo.ge"
  echo "     (14 files, 239 megabytes; run-checks.sh then needs about 4 to 14 days)"
  echo "  2  test-project: a small project that proves sin(x)^2 + cos(x)^2 = 1, from"
  echo "     $TEST_PROJECT_URL"
  echo "     (run-checks.sh then needs about 10 minutes)"
  read -r -p "Enter 1 or 2: " answer \
    || die "no answer; to run without the question, set PROJECT=riemann-hypothesis or PROJECT=test-project"
  case "$answer" in
    1) PROJECT=riemann-hypothesis ;;
    2) PROJECT=test-project ;;
    *) die "the answer must be 1 or 2" ;;
  esac
fi
case "$PROJECT" in
  riemann-hypothesis)
    PART_URLS=(); PART_FILES=()
    for i in $(seq -w 1 14); do
      PART_URLS+=("$RH_PART_URL$i")
      PART_FILES+=("lean.tar.gz.part$i")
    done
    PART_SHA256=("${RH_PART_SHA256[@]}")
    ARCHIVE_NAME="lean.tar.gz"
    ARCHIVE_SHA256="$RH_ARCHIVE_SHA256"
    FILES_SHA256="$RH_FILES_SHA256"
    MANIFEST_SHA256="$RH_MANIFEST_SHA256"
    MIN_DISK_GB=200; MIN_MEMORY_GB=32 ;;
  test-project)
    [ -n "$TEST_PROJECT_URL" ] || die "TEST_PROJECT_URL is empty; set it at the top of install-software.sh"
    PART_URLS=("$TEST_PROJECT_URL")
    PART_FILES=("test-project.tar.gz")
    PART_SHA256=("")     # the single downloaded file is the archive; it is checked in step 1.6
    ARCHIVE_NAME="test-project.tar.gz"
    ARCHIVE_SHA256="$TEST_PROJECT_SHA256"
    FILES_SHA256=""      # step 1.8 records the checksum of the unpacked files for run-checks.sh
    MANIFEST_SHA256=""
    MIN_DISK_GB=20; MIN_MEMORY_GB=8 ;;
  *)
    die "unknown project '$PROJECT'; use riemann-hypothesis or test-project" ;;
esac
PROJECT_WORK_DIR="$WORK_DIR/check-$PROJECT"
PROJECT_DIR="$PROJECT_WORK_DIR/lean"
echo "Project: $PROJECT"
echo "Folder:  $PROJECT_WORK_DIR"

# -------------------------------------------------------------------------------------------------
say "1.2 System tools"
missing=()
for tool in git curl tar gzip sha256sum find sort xargs df awk; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
command -v cc >/dev/null 2>&1 || missing+=("cc")
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing system tools: ${missing[*]}"
  if command -v apt-get >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
    apt-get update
    apt-get install -y git curl tar gzip coreutils findutils gawk build-essential
  else
    echo "Install them and run this script again."
    echo "  Debian or Ubuntu: sudo apt-get install -y git curl tar gzip coreutils findutils gawk build-essential"
    echo "  Fedora:           sudo dnf install -y git curl tar gzip coreutils findutils gawk gcc"
    exit 1
  fi
fi
echo "All system tools are present."
mkdir -p "$PROJECT_WORK_DIR" "$TOOLS_DIR"
free_gb=$(df -Pk "$WORK_DIR" | awk 'NR==2 {printf "%d", $4/1048576}')
mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo)
echo "Working folder: $WORK_DIR ($free_gb gigabytes free)"
echo "Memory: $mem_gb gigabytes; processor cores: $(nproc)"
[ "$free_gb" -ge "$MIN_DISK_GB" ] \
  || warn "less than $MIN_DISK_GB gigabytes free in $WORK_DIR: the build may run out of disk space"
[ "$mem_gb" -ge "$MIN_MEMORY_GB" ] \
  || warn "less than $MIN_MEMORY_GB gigabytes of memory: the build and the checks that load the whole project may fail"

# -------------------------------------------------------------------------------------------------
if [ -d "$PROJECT_DIR" ]; then
  say "1.3 to 1.7 skipped"
  echo "$PROJECT_DIR already exists, so it is not downloaded and unpacked again; step 1.8 checks it."
  echo "To start this project again from the beginning, delete the folder $PROJECT_WORK_DIR."
else
  say "1.3 Download the project files"
  mkdir -p "$PROJECT_WORK_DIR/download"
  for k in "${!PART_URLS[@]}"; do
    file="$PROJECT_WORK_DIR/download/${PART_FILES[$k]}"
    if [ -n "${PART_SHA256[$k]}" ] && [ -f "$file" ] && [ "$(sha256 "$file")" = "${PART_SHA256[$k]}" ]; then
      echo "${PART_FILES[$k]}: already downloaded"
    else
      echo "${PART_FILES[$k]}: downloading ${PART_URLS[$k]}"
      fetch "${PART_URLS[$k]}" "$file" || die "could not download ${PART_URLS[$k]}"
    fi
  done

  say "1.4 Check each downloaded file"
  for k in "${!PART_FILES[@]}"; do
    file="$PROJECT_WORK_DIR/download/${PART_FILES[$k]}"
    got="$(sha256 "$file")"
    if [ -z "${PART_SHA256[$k]}" ]; then
      echo "${PART_FILES[$k]}: checksum $got (this file is the archive; step 1.6 compares it)"
    elif [ "$got" = "${PART_SHA256[$k]}" ]; then
      echo "${PART_FILES[$k]}: checksum correct"
    else
      die "${PART_FILES[$k]} has checksum $got; expected ${PART_SHA256[$k]}. Delete $file and run this script again."
    fi
  done

  say "1.5 Join the downloaded files into one archive"
  ARCHIVE="$PROJECT_WORK_DIR/$ARCHIVE_NAME"
  (cd "$PROJECT_WORK_DIR/download" && cat "${PART_FILES[@]}") > "$ARCHIVE"
  echo "$ARCHIVE: $(wc -c < "$ARCHIVE") bytes"

  say "1.6 Check the archive"
  got="$(sha256 "$ARCHIVE")"
  if [ -z "$ARCHIVE_SHA256" ]; then
    warn "TEST_PROJECT_SHA256 is empty, so the archive is not compared; its checksum is $got"
  elif [ "$got" = "$ARCHIVE_SHA256" ]; then
    echo "$ARCHIVE_NAME is identical to the published archive (checksum $got)."
  elif [ "$PROJECT" = test-project ]; then
    die "$ARCHIVE_NAME has checksum $got; expected $ARCHIVE_SHA256. If you changed the test project, put the new checksum into TEST_PROJECT_SHA256 at the top of install-software.sh."
  else
    die "$ARCHIVE_NAME has checksum $got; expected $ARCHIVE_SHA256"
  fi

  say "1.7 Unpack the archive"
  UNPACK_DIR="$PROJECT_WORK_DIR/unpack"
  rm -rf -- "$UNPACK_DIR"
  mkdir -p "$UNPACK_DIR"
  tar -xzf "$ARCHIVE" -C "$UNPACK_DIR" --no-same-owner
  # The project folder is the folder that contains the file lean-toolchain.
  mapfile -t found < <(find "$UNPACK_DIR" -maxdepth 3 -type f -name lean-toolchain)
  [ "${#found[@]}" -eq 1 ] \
    || die "the archive must contain exactly one Lean project (one file named lean-toolchain); it contains ${#found[@]}"
  mv "$(dirname "${found[0]}")" "$PROJECT_DIR"
  rm -rf -- "$UNPACK_DIR"
  echo "Unpacked into $PROJECT_DIR ($(find "$PROJECT_DIR" -type f | wc -l) files)"
fi

# -------------------------------------------------------------------------------------------------
say "1.8 Check the unpacked files"
got="$(files_checksum)"
if [ -z "$FILES_SHA256" ]; then
  echo "Checksum of the unpacked files: $got"
elif [ "$got" = "$FILES_SHA256" ]; then
  echo "The unpacked files are identical to the published files (checksum $got)."
else
  die "the files in $PROJECT_DIR differ from the published files (checksum $got; expected $FILES_SHA256)"
fi
printf '%s\n' "$got" > "$PROJECT_WORK_DIR/files.sha256"
manifest="$PROJECT_DIR/lake-manifest.json"
[ -f "$manifest" ] || die "$manifest not found"
if [ -n "$MANIFEST_SHA256" ]; then
  if [ "$(sha256 "$manifest")" = "$MANIFEST_SHA256" ]; then
    echo "lake-manifest.json is the original file."
  else
    warn "lake-manifest.json differs from the original file; checking the pinned library versions"
  fi
fi
for entry in "${PINNED_LIBRARIES[@]}"; do
  read -r name rev <<< "$entry"
  grep -Eq "\"rev\"[[:space:]]*:[[:space:]]*\"$rev\"" "$manifest" || die "lake-manifest.json does not pin $name at commit $rev"
done
echo "lake-manifest.json pins all ${#PINNED_LIBRARIES[@]} libraries at the expected commits."
LEAN_TOOLCHAIN="$(tr -d '[:space:]' < "$PROJECT_DIR/lean-toolchain")"   # leanprover/lean4:v4.33.1
LEAN_VERSION="${LEAN_TOOLCHAIN##*:}"                                   # v4.33.1
echo "Lean version required by the project: $LEAN_VERSION"
printf '%s\n' "$PROJECT" > "$WORK_DIR/selected-project"

# -------------------------------------------------------------------------------------------------
say "1.9 Install elan, the Lean version manager"
# --no-modify-path: the installer does not add lines to the shell start files in the home folder.
if [ ! -x "$ELAN_HOME/bin/elan" ]; then
  curl -sSf -o "$TOOLS_DIR/elan-init.sh" https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh
  sh "$TOOLS_DIR/elan-init.sh" -y --default-toolchain none --no-modify-path
fi
elan --version

# -------------------------------------------------------------------------------------------------
say "1.10 Install Lean $LEAN_VERSION (it includes leanchecker)"
(cd "$PROJECT_DIR" && lean --version)
LEAN_PREFIX="$(cd "$PROJECT_DIR" && lean --print-prefix)"
if [ -x "$LEAN_PREFIX/bin/leanchecker" ]; then
  echo "leanchecker is included: $LEAN_PREFIX/bin/leanchecker"
else
  warn "leanchecker was not found in $LEAN_PREFIX/bin (it is part of Lean 4.28.0 and newer); step 2.8 will fail"
fi

# -------------------------------------------------------------------------------------------------
say "1.11 Download Mathlib and the other libraries"
if (cd "$PROJECT_DIR" && lake exe cache get); then
  echo "Prebuilt Mathlib files downloaded."
else
  warn "prebuilt Mathlib files could not be downloaded; run-checks.sh will then also build Mathlib (1 to 3 more hours)"
fi
for entry in "${PINNED_LIBRARIES[@]}"; do
  read -r name rev <<< "$entry"
  dir="$PROJECT_DIR/.lake/packages/$name"
  if [ -d "$dir" ]; then
    head=$(git -C "$dir" rev-parse HEAD)
    [ "$head" = "$rev" ] || die "library $name is at commit $head; expected $rev"
    echo "library $name: commit $rev (as pinned)"
  else
    warn "library $name is not downloaded yet; lake build will download it"
  fi
done

# -------------------------------------------------------------------------------------------------
install_lean_tool() {   # $1 = step, $2 = name, $3 = Git address, $4 = commit, $5 = Lake target ("" = default)
  local step="$1" name="$2" url="$3" commit="$4" target="$5" dir="$TOOLS_DIR/$2"
  say "$step Install $name"
  if [ ! -d "$dir/.git" ]; then
    git clone -q "$url" "$dir" || { warn "could not download $name"; FAILED+=("$name"); return 0; }
  fi
  checkout_commit "$dir" "$commit" || { warn "$name: commit $commit not found"; FAILED+=("$name"); return 0; }
  # Compiled Lean files can be read only by the Lean version that wrote them, so the tool is
  # built with exactly the Lean version of the project.
  printf '%s\n' "$LEAN_TOOLCHAIN" > "$dir/lean-toolchain"
  echo "$name: commit $commit, built with $LEAN_TOOLCHAIN"
  if (cd "$dir" && lake build ${target:+"$target"}); then
    echo "$name is built: $dir/.lake/build/bin/$name"
  else
    warn "building $name failed; see the messages above"
    FAILED+=("$name")
  fi
}
install_lean_tool 1.12 lean4export https://github.com/leanprover/lean4export "$LEAN4EXPORT_COMMIT" ""
install_lean_tool 1.13 lean4lean   https://github.com/digama0/lean4lean      "$LEAN4LEAN_COMMIT"   lean4lean

# -------------------------------------------------------------------------------------------------
say "1.14 Install the Rust compiler"
if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
  curl -sSf -o "$TOOLS_DIR/rustup-init.sh" https://sh.rustup.rs
  sh "$TOOLS_DIR/rustup-init.sh" -y --profile minimal --no-modify-path
fi
cargo --version

# -------------------------------------------------------------------------------------------------
say "1.15 Install nanoda"
dir="$TOOLS_DIR/nanoda_lib"
if [ ! -d "$dir/.git" ]; then
  git clone -q https://github.com/ammkrn/nanoda_lib "$dir" || { warn "could not download nanoda"; FAILED+=("nanoda"); }
fi
if [ -d "$dir/.git" ]; then
  if ! checkout_commit "$dir" "$NANODA_COMMIT"; then
    warn "nanoda: commit $NANODA_COMMIT not found"
    FAILED+=("nanoda")
  elif (cd "$dir" && cargo build --release --locked); then
    echo "nanoda: commit $NANODA_COMMIT, built: $dir/target/release/nanoda_bin"
  else
    warn "building nanoda failed; see the messages above (an old Rust compiler can be updated with: rustup update)"
    FAILED+=("nanoda")
  fi
fi

# -------------------------------------------------------------------------------------------------
say "Summary"
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "The project $PROJECT and all software are installed."
  echo "Next step: ./run-checks.sh, started from the same folder ($WORK_DIR). It checks the project $PROJECT."
else
  echo "The project $PROJECT is installed, and all software except: ${FAILED[*]}"
  echo "run-checks.sh will report the steps that need the missing software as SKIPPED."
  exit 1
fi
