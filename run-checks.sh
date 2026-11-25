#!/usr/bin/env bash
#
# run-checks.sh
#
# Part 2 of 2 for verifying a Lean proof; run install-software.sh first, from the same folder.
# README.md explains every step in section "2. Verification"; this script prints the same step
# numbers. All steps are automatic.
#
# It checks the project that install-software.sh installed last (its name is in the file
# selected-project in the working folder). To check another installed project, set PROJECT, for
# example:
#   PROJECT=test-project ./run-checks.sh
#
#   2.1   the project files are identical to the published files; the library versions are pinned
#   2.2   lake build: every file is elaborated and every proof is checked by Lean's kernel
#   2.3   the libraries used by the build are at the pinned versions
#   2.4   the build messages contain no errors and no "declaration uses 'sorry'"
#   2.5   #print axioms: the main theorems use only propext, Classical.choice and Quot.sound
#   2.6   the statements of the main theorems are exactly the reference statements in this script
#   2.7   leanchecker --fresh: Lean's kernel checks every stored declaration again, in a new process
#   2.8   lean4export: the main theorems and everything they depend on are written to one file
#   2.9   nanoda: an external type checker, written separately in Rust, checks that file
#   2.10  Lean4Lean: a second implementation of Lean's kernel, written in Lean, checks every
#         stored declaration
#
# Resuming: ./run-checks.sh --resume-step=2.10 starts at step 2.10. The steps before it are not
# run again: their results are copied from the previous summary.txt, and the files they created
# must still be there. A copy of the previous summary.txt is kept. If the value is empty or is not
# one of the step numbers above, all steps run, from step 2.1.
#
# Results: check-<project>/results/ in the working folder (one log file per step, and summary.txt)
#
# Optional settings (environment variables):
#   WORK_DIR, TOOLS_DIR   as in install-software.sh (default: the folder from which you start it)
#   PROJECT               riemann-hypothesis or test-project (default: the project installed last)
#   NANODA_CMD            complete command that runs nanoda, if the default command does not fit
#                         the installed nanoda version (see the nanoda_lib README)
#   LEAN4LEAN_CMD         complete command that runs Lean4Lean, if the default command does not
#                         fit; it is run inside the project folder

set -uo pipefail

# Step budget of Lean4Lean (step 2.10). Lean4Lean stops with "(kernel) deterministic timeout" when
# one of its step counters runs out (file Lean4Lean/FuelConfig.lean in the Lean4Lean source). Its
# defaults (whnf 100000, whnfEager 1000000, lazyDelta 1000) are too small for the proofs by
# computation in the Riemann Hypothesis project: PI.PC.loop_run, for example, makes the checker run
# a loop of 131,070 rounds (`decide +kernel`). These values are 1000 times the defaults. A larger
# budget cannot make Lean4Lean accept a wrong proof; it only lets it compute longer before it
# gives up.
LEAN4LEAN_FUEL=(--config:whnf=100000000 --config:whnfEager=1000000000 --config:lazyDelta=1000000)

# The steps, in order.
STEPS=(2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 2.10)

# Command-line argument: --resume-step=<step>
RESUME_STEP=""
for arg in "$@"; do
  case "$arg" in
    --resume-step=*) RESUME_STEP="${arg#--resume-step=}" ;;
    *) echo "ERROR: unknown argument '$arg'. The only argument is --resume-step=<step>, for example --resume-step=2.10."
       exit 1 ;;
  esac
done
START_INDEX=0
for i in "${!STEPS[@]}"; do
  if [ "${STEPS[$i]}" = "$RESUME_STEP" ]; then START_INDEX=$i; fi
done
if [ -n "$RESUME_STEP" ] && [ "${STEPS[$START_INDEX]}" != "$RESUME_STEP" ]; then
  echo "NOTE: --resume-step=$RESUME_STEP is not one of the steps ${STEPS[0]} to ${STEPS[-1]}; all steps run, from step ${STEPS[0]}."
fi

WORK_DIR="${WORK_DIR:-$PWD}"
[ -d "$WORK_DIR" ] || { echo "ERROR: the folder $WORK_DIR does not exist."; exit 1; }
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
TOOLS_DIR="${TOOLS_DIR:-$WORK_DIR/tools}"

# The same locations as in install-software.sh: everything is inside the working folder.
export ELAN_HOME="$TOOLS_DIR/elan"
export RUSTUP_HOME="$TOOLS_DIR/rustup"
export CARGO_HOME="$TOOLS_DIR/cargo"
export MATHLIB_CACHE_DIR="$TOOLS_DIR/mathlib-cache"
export PATH="$ELAN_HOME/bin:$CARGO_HOME/bin:$PATH"

# Library versions that lake-manifest.json must pin (README.md, section "Checksums").
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

PROJECT="${PROJECT:-$(cat "$WORK_DIR/selected-project" 2>/dev/null)}"
case "$PROJECT" in
  riemann-hypothesis)
    # The five main theorems (src/Main.lean) and the definitions of their statements.
    THEOREMS=(riemannHypothesis riemannZeta_eq_zero_re LFunction_ne_zero_of_half_lt_re
              LFunction_eq_zero_re LFunction_eq_zero_re_of_isPrimitive)
    STATEMENTS=(RiemannHypothesis RiemannZetaZerosOnLine DirichletLNonvanishingRightOfHalf
                DirichletLZerosOnLine PrimitiveDirichletLZerosOnLine)
    # Checksum of the author's files, all except lake-manifest.json (README.md, section "Checksums").
    EXPECTED_FILES_SHA256="006b98c1b955017540cd9e2dc8e95936da168de104427bf170528e93bd6ebebe" ;;
  test-project)
    THEOREMS=(sin_sq_add_cos_sq_eq_one)
    STATEMENTS=(SinSqAddCosSq)
    # Checksum that install-software.sh recorded in step 1.8, when it unpacked the test project.
    EXPECTED_FILES_SHA256="$(cat "$WORK_DIR/check-test-project/files.sha256" 2>/dev/null)" ;;
  "")
    echo "ERROR: no project is installed in $WORK_DIR (the file selected-project is missing)."
    echo "Run install-software.sh first, from the same folder."
    exit 1 ;;
  *)
    echo "ERROR: unknown project '$PROJECT'; use riemann-hypothesis or test-project."
    exit 1 ;;
esac

# Reference statements for step 2.6. Lean must accept every "example" in this file. Each "rfl"
# example says that a statement of the project is exactly the reference statement written here;
# the examples at the end say that each main theorem proves exactly its statement.
write_statement_check() {
  case "$PROJECT" in
    riemann-hypothesis) cat <<'EOF'
import Main

set_option autoImplicit false
set_option maxSynthPendingDepth 3

-- The Riemann Hypothesis, as defined in Mathlib (Mathlib/NumberTheory/LSeries/RiemannZeta.lean):
-- every zero s of the Riemann zeta function, except the negative even integers and s = 1, has
-- real part 1/2.
example : RiemannHypothesis =
    (∀ (s : ℂ) (_ : riemannZeta s = 0) (_ : ¬∃ n : ℕ, s = -2 * (n + 1)) (_ : s ≠ 1), s.re = 1 / 2) :=
  rfl

-- The same statement, as written in the project.
example : RiemannZetaZerosOnLine =
    (∀ s : ℂ, riemannZeta s = 0 → (¬∃ n : ℕ, s = -2 * ((n : ℂ) + 1)) → s ≠ 1 → s.re = 1 / 2) :=
  rfl

-- Dirichlet L-functions have no zeros with real part greater than 1/2 (the trivial character
-- at s = 1, where its L-function has a pole, is excluded).
example : DirichletLNonvanishingRightOfHalf =
    (∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N) (s : ℂ),
      1 / 2 < s.re → (χ ≠ 1 ∨ s ≠ 1) → DirichletCharacter.LFunction χ s ≠ 0) :=
  rfl

-- Every zero of a Dirichlet L-function with real part between 0 and 1 has real part 1/2.
example : DirichletLZerosOnLine =
    (∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N) (s : ℂ),
      0 < s.re → s.re < 1 → DirichletCharacter.LFunction χ s = 0 → s.re = 1 / 2) :=
  rfl

-- The same, for primitive Dirichlet characters.
example : PrimitiveDirichletLZerosOnLine =
    (∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N), χ.IsPrimitive →
      ∀ s : ℂ, 0 < s.re → s.re < 1 → DirichletCharacter.LFunction χ s = 0 → s.re = 1 / 2) :=
  rfl

-- Each main theorem proves exactly its statement.
example : RiemannHypothesis := riemannHypothesis
example : RiemannZetaZerosOnLine := riemannZeta_eq_zero_re
example : DirichletLNonvanishingRightOfHalf := LFunction_ne_zero_of_half_lt_re
example : DirichletLZerosOnLine := LFunction_eq_zero_re
example : PrimitiveDirichletLZerosOnLine := LFunction_eq_zero_re_of_isPrimitive
EOF
      ;;
    test-project) cat <<'EOF'
import Main

set_option autoImplicit false

-- For every real number x: sin(x)^2 + cos(x)^2 = 1.
example : SinSqAddCosSq = (∀ x : ℝ, Real.sin x ^ 2 + Real.cos x ^ 2 = 1) := rfl

-- The main theorem proves exactly this statement.
example : SinSqAddCosSq := sin_sq_add_cos_sq_eq_one
EOF
      ;;
  esac
}

PROJECT_WORK_DIR="$WORK_DIR/check-$PROJECT"
PROJECT_DIR="$PROJECT_WORK_DIR/lean"
RESULTS_DIR="$PROJECT_WORK_DIR/results"
CHECKS_DIR="$PROJECT_WORK_DIR/checks"
EXPORT_FILE="$PROJECT_WORK_DIR/main.ndjson"
LEAN4EXPORT_BIN="$TOOLS_DIR/lean4export/.lake/build/bin/lean4export"
LEAN4LEAN_BIN="$TOOLS_DIR/lean4lean/.lake/build/bin/lean4lean"
NANODA_BIN="$TOOLS_DIR/nanoda_lib/target/release/nanoda_bin"

[ -d "$PROJECT_DIR" ] || { echo "ERROR: $PROJECT_DIR not found. Run install-software.sh first, from the same folder."; exit 1; }
mkdir -p "$RESULTS_DIR" "$CHECKS_DIR"
SUMMARY="$RESULTS_DIR/summary.txt"
ALL_PASSED=1
BUILD_OK=0    # set by step 2.2; step 2.4 needs it
EXPORT_OK=0   # set by step 2.8; step 2.9 needs it

# The title of each step, as it appears in summary.txt.
declare -A TITLE=(
  [2.1]="2.1 Project files identical to the published files"
  [2.2]="2.2 lake build (Lean's kernel checks every proof)"
  [2.3]="2.3 Libraries at the pinned versions"
  [2.4]="2.4 No errors and no 'sorry' in the build messages"
  [2.5]="2.5 Only the standard axioms are used"
  [2.6]="2.6 Statements are the reference statements"
  [2.7]="2.7 leanchecker: Lean's kernel again"
  [2.8]="2.8 Export for nanoda"
  [2.9]="2.9 nanoda: external type checker"
  [2.10]="2.10 Lean4Lean: second kernel implementation"
)

result() {   # $1 = step title, $2 = PASSED, FAILED or SKIPPED, $3 = details
  printf '%-52s %-8s %s\n' "$1" "$2" "$3" | tee -a "$SUMMARY"
  if [ "$2" != PASSED ]; then ALL_PASSED=0; fi
}
start_timer() { T0=$(date +%s); }
elapsed() {
  local s=$(( $(date +%s) - T0 ))
  printf '%d hours %d minutes' $(( s / 3600 )) $(( s % 3600 / 60 ))
}
heading() { printf '\n== %s (started %s)\n' "$1" "$(date)"; }
commit_of() { git -C "$1" rev-parse HEAD 2>/dev/null || echo "not installed"; }
json_list() {   # prints its arguments as a list in JSON format: ["a", "b"]
  local sep="" x
  printf '['
  for x in "$@"; do printf '%s"%s"' "$sep" "$x"; sep=", "; done
  printf ']'
}

# For a step before the resume step: copy its result line from the previous summary, and restore
# what later steps need from it.
carry_over() {   # $1 = step
  local line="" status=SKIPPED
  if [ -n "$PREVIOUS_SUMMARY" ]; then
    line=$(grep -E "^${1//./\\.} " "$PREVIOUS_SUMMARY" | tail -n 1)
  fi
  if [[ "$line" =~ [[:space:]](PASSED|FAILED|SKIPPED)([[:space:]]|$) ]]; then
    status="${BASH_REMATCH[1]}"
    printf '%s\n' "$line" | tee -a "$SUMMARY"
    if [ "$status" != PASSED ]; then ALL_PASSED=0; fi
  else
    result "${TITLE[$1]}" SKIPPED "not run (--resume-step=$RESUME_STEP), and there is no earlier result"
  fi
  case "$1" in
    2.2) if [ "$status" = PASSED ]; then BUILD_OK=1; fi ;;
    2.8) if [ "$status" = PASSED ] && [ -s "$EXPORT_FILE" ]; then EXPORT_OK=1; fi ;;
  esac
}

# Start summary.txt. When resuming, keep a copy of the previous summary and its first lines (start
# time and tool versions).
PREVIOUS_SUMMARY=""
if [ "$START_INDEX" -gt 0 ] && [ -f "$SUMMARY" ]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  PREVIOUS_SUMMARY="$RESULTS_DIR/summary-before-resume-$stamp.txt"
  n=2
  while [ -e "$PREVIOUS_SUMMARY" ]; do   # never overwrite an earlier copy
    PREVIOUS_SUMMARY="$RESULTS_DIR/summary-before-resume-$stamp-$n.txt"
    n=$((n + 1))
  done
  cp "$SUMMARY" "$PREVIOUS_SUMMARY"
fi
lean_version=$(cd "$PROJECT_DIR" && lean --version 2>/dev/null | head -n 1)
{
  if [ -n "$PREVIOUS_SUMMARY" ]; then
    awk '/^2\.[0-9]+ /{exit} NF{print}' "$PREVIOUS_SUMMARY"
  else
    echo "Verification of the Lean project '$PROJECT' in $PROJECT_DIR"
    echo "Started:     $(date)"
    echo "Lean:        ${lean_version:-not installed}"
    echo "lean4export: commit $(commit_of "$TOOLS_DIR/lean4export")"
    echo "Lean4Lean:   commit $(commit_of "$TOOLS_DIR/lean4lean")"
    echo "nanoda:      commit $(commit_of "$TOOLS_DIR/nanoda_lib")"
  fi
  if [ "$START_INDEX" -gt 0 ]; then
    echo "Resumed:     $(date), at step $RESUME_STEP; previous summary: ${PREVIOUS_SUMMARY:-none found}"
  fi
  echo
} > "$SUMMARY"

# -------------------------------------------------------------------------------------------------
step_2_1() {
  heading "2.1 Project files and pinned library versions"
  local problems=() got entry name rev
  got=$(cd "$PROJECT_WORK_DIR" && find lean -path lean/.lake -prune -o -type f ! -path lean/lake-manifest.json -print0 \
          | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
  if [ -z "$EXPECTED_FILES_SHA256" ]; then
    problems+=("no reference checksum; run install-software.sh first")
  elif [ "$got" != "$EXPECTED_FILES_SHA256" ]; then
    problems+=("the files differ from the published files (checksum $got)")
  fi
  for entry in "${PINNED_LIBRARIES[@]}"; do
    read -r name rev <<< "$entry"
    grep -Eq "\"rev\"[[:space:]]*:[[:space:]]*\"$rev\"" "$PROJECT_DIR/lake-manifest.json" \
      || problems+=("lake-manifest.json does not pin $name at $rev")
  done
  if [ "${#problems[@]}" -eq 0 ]; then
    result "${TITLE[2.1]}" PASSED "checksum $got"
  else
    result "${TITLE[2.1]}" FAILED "${problems[*]}"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_2() {
  heading "2.2 lake build (progress is written to $RESULTS_DIR/build.log)"
  start_timer
  BUILD_OK=0
  if (cd "$PROJECT_DIR" && lake build) > "$RESULTS_DIR/build.log" 2>&1; then
    BUILD_OK=1
    result "${TITLE[2.2]}" PASSED "$(elapsed); log: $RESULTS_DIR/build.log"
  else
    result "${TITLE[2.2]}" FAILED "$(elapsed); see $RESULTS_DIR/build.log"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_3() {
  heading "2.3 Library versions used by the build"
  local problems=() entry name rev head
  if [ ! -d "$PROJECT_DIR/.lake/packages" ]; then
    problems+=("the libraries are not downloaded ($PROJECT_DIR/.lake/packages does not exist)")
  else
    for entry in "${PINNED_LIBRARIES[@]}"; do
      read -r name rev <<< "$entry"
      head=$(git -C "$PROJECT_DIR/.lake/packages/$name" rev-parse HEAD 2>/dev/null || echo "missing")
      [ "$head" = "$rev" ] || problems+=("$name is at $head, expected $rev")
    done
  fi
  if [ "${#problems[@]}" -eq 0 ]; then
    result "${TITLE[2.3]}" PASSED "all ${#PINNED_LIBRARIES[@]} libraries"
  else
    result "${TITLE[2.3]}" FAILED "${problems[*]}"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_4() {
  heading "2.4 Errors and 'sorry' in the build messages"
  local error_pattern='(^|[^[:alnum:]_])error:' sorry_pattern="declaration uses .sorry." errors sorries
  errors=$(grep -c -E "$error_pattern" "$RESULTS_DIR/build.log" 2>/dev/null)
  sorries=$(grep -c -E "$sorry_pattern" "$RESULTS_DIR/build.log" 2>/dev/null)
  grep -n -E "$error_pattern|$sorry_pattern" "$RESULTS_DIR/build.log" > "$RESULTS_DIR/errors-and-sorry.txt" 2>/dev/null
  if [ "$BUILD_OK" -ne 1 ]; then
    result "${TITLE[2.4]}" SKIPPED "the build did not complete (step 2.2)"
  elif [ ! -s "$RESULTS_DIR/build.log" ]; then
    result "${TITLE[2.4]}" FAILED "$RESULTS_DIR/build.log is missing or empty"
  elif [ "${errors:-0}" -eq 0 ] && [ "${sorries:-0}" -eq 0 ]; then
    result "${TITLE[2.4]}" PASSED "0 errors, 0 sorry"
  else
    result "${TITLE[2.4]}" FAILED "${errors:-?} error lines, ${sorries:-?} sorry warnings; see $RESULTS_DIR/errors-and-sorry.txt"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_5() {
  heading "2.5 Axioms used by the main theorems"
  local bad=() t line list a
  { echo "import Main"; echo; for t in "${THEOREMS[@]}"; do echo "#print axioms $t"; done; } > "$CHECKS_DIR/CheckAxioms.lean"
  start_timer
  if (cd "$PROJECT_DIR" && lake env lean "$CHECKS_DIR/CheckAxioms.lean") > "$RESULTS_DIR/axioms.txt" 2>&1; then
    for t in "${THEOREMS[@]}"; do
      line=$(grep -F "'$t'" "$RESULTS_DIR/axioms.txt" | head -n 1)
      if [ -z "$line" ]; then bad+=("$t: no output"); continue; fi
      case "$line" in *"does not depend on any axioms"*) continue ;; esac
      list=$(printf '%s\n' "$line" | sed -n 's/.*depends on axioms: *\[\(.*\)\].*/\1/p')
      if [ -z "$list" ]; then bad+=("$t: output not readable, see axioms.txt"); continue; fi
      for a in $(printf '%s' "$list" | tr ',' ' '); do
        case "$a" in propext|Classical.choice|Quot.sound) ;; *) bad+=("$t uses $a") ;; esac
      done
    done
    if [ "${#bad[@]}" -eq 0 ]; then
      result "${TITLE[2.5]}" PASSED "propext, Classical.choice, Quot.sound; $(elapsed)"
    else
      result "${TITLE[2.5]}" FAILED "${bad[*]}"
    fi
  else
    result "${TITLE[2.5]}" FAILED "Lean could not run CheckAxioms.lean; see $RESULTS_DIR/axioms.txt"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_6() {
  heading "2.6 Statements of the main theorems are the reference statements"
  write_statement_check > "$CHECKS_DIR/CheckStatements.lean"
  start_timer
  if (cd "$PROJECT_DIR" && lake env lean "$CHECKS_DIR/CheckStatements.lean") > "$RESULTS_DIR/statements.log" 2>&1 \
       && ! grep -q "error:" "$RESULTS_DIR/statements.log"; then
    result "${TITLE[2.6]}" PASSED "statements checked: ${#STATEMENTS[@]}, theorems checked: ${#THEOREMS[@]}; $(elapsed)"
  else
    result "${TITLE[2.6]}" FAILED "see $RESULTS_DIR/statements.log"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_7() {
  heading "2.7 leanchecker (Lean's kernel again, in a new process)"
  if (cd "$PROJECT_DIR" && lake env sh -c 'command -v leanchecker') >/dev/null 2>&1; then
    start_timer
    if (cd "$PROJECT_DIR" && lake env leanchecker --fresh Main) > "$RESULTS_DIR/leanchecker.log" 2>&1; then
      result "${TITLE[2.7]}" PASSED "$(elapsed)"
    else
      result "${TITLE[2.7]}" FAILED "$(elapsed); see $RESULTS_DIR/leanchecker.log"
    fi
  else
    result "${TITLE[2.7]}" FAILED "leanchecker not found; it is part of Lean 4.28.0 and newer"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_8() {
  heading "2.8 lean4export (write the main theorems and everything they depend on to $EXPORT_FILE)"
  EXPORT_OK=0
  if [ -x "$LEAN4EXPORT_BIN" ]; then
    start_timer
    # LEAN_ABORT_ON_PANIC=1 makes lean4export stop with an error, instead of only printing a
    # message, if for example one of the theorem names is not found.
    if (cd "$PROJECT_DIR" && LEAN_ABORT_ON_PANIC=1 lake env "$LEAN4EXPORT_BIN" Main -- "${THEOREMS[@]}") \
         > "$EXPORT_FILE" 2> "$RESULTS_DIR/lean4export.log" && [ -s "$EXPORT_FILE" ]; then
      EXPORT_OK=1
      result "${TITLE[2.8]}" PASSED "$(du -h "$EXPORT_FILE" | cut -f1) written; $(elapsed)"
    else
      result "${TITLE[2.8]}" FAILED "see $RESULTS_DIR/lean4export.log"
    fi
  else
    result "${TITLE[2.8]}" SKIPPED "lean4export is not installed ($LEAN4EXPORT_BIN)"
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_9() {
  heading "2.9 nanoda (external type checker written in Rust)"
  # Settings as described in the nanoda_lib README: only the three standard axioms are allowed, and
  # any other axiom in the export file stops the check with an error. The main theorems and their
  # statements must be in the export file; nanoda prints them into its log.
  cat > "$CHECKS_DIR/nanoda-config.json" <<EOF
{
  "export_file_path": "$EXPORT_FILE",
  "num_threads": $(nproc),
  "stack_size_bytes": 1073741824,
  "permitted_axioms": ["propext", "Classical.choice", "Quot.sound"],
  "unpermitted_axiom_hard_error": true,
  "nat_extension": true,
  "string_extension": true,
  "pp_declars": $(json_list "${THEOREMS[@]}" "${STATEMENTS[@]}"),
  "pp_to_stdout": true,
  "print_success_message": true
}
EOF
  if [ -n "${NANODA_CMD:-}" ]; then
    start_timer
    if bash -c "$NANODA_CMD" > "$RESULTS_DIR/nanoda.log" 2>&1; then
      result "${TITLE[2.9]}" PASSED "$(elapsed)"
    else
      result "${TITLE[2.9]}" FAILED "$(elapsed); see $RESULTS_DIR/nanoda.log"
    fi
  elif [ ! -x "$NANODA_BIN" ]; then
    result "${TITLE[2.9]}" SKIPPED "nanoda is not installed ($NANODA_BIN)"
  elif [ "$EXPORT_OK" -ne 1 ]; then
    result "${TITLE[2.9]}" SKIPPED "no export file (step 2.8)"
  else
    start_timer
    if "$NANODA_BIN" "$CHECKS_DIR/nanoda-config.json" > "$RESULTS_DIR/nanoda.log" 2>&1 \
         && grep -q "declarations with no errors" "$RESULTS_DIR/nanoda.log"; then
      result "${TITLE[2.9]}" PASSED "$(grep -o 'Checked [0-9]* declarations' "$RESULTS_DIR/nanoda.log" | tail -n 1); $(elapsed)"
    else
      result "${TITLE[2.9]}" FAILED "$(elapsed); see $RESULTS_DIR/nanoda.log"
    fi
  fi
}

# -------------------------------------------------------------------------------------------------
step_2_10() {
  heading "2.10 Lean4Lean (Lean's kernel written again in Lean)"
  local status checked
  if [ -n "${LEAN4LEAN_CMD:-}" ] || [ -x "$LEAN4LEAN_BIN" ]; then
    start_timer
    if [ -n "${LEAN4LEAN_CMD:-}" ]; then
      echo "Command: $LEAN4LEAN_CMD"
      (cd "$PROJECT_DIR" && bash -c "$LEAN4LEAN_CMD") > "$RESULTS_DIR/lean4lean.log" 2>&1
    else
      echo "Command: lake env $LEAN4LEAN_BIN --fresh ${LEAN4LEAN_FUEL[*]} Main"
      (cd "$PROJECT_DIR" && lake env "$LEAN4LEAN_BIN" --fresh "${LEAN4LEAN_FUEL[@]}" Main) > "$RESULTS_DIR/lean4lean.log" 2>&1
    fi
    status=$?
    if [ "$status" -eq 0 ]; then
      checked=$(grep -o 'checked [0-9]* declarations' "$RESULTS_DIR/lean4lean.log" | tail -n 1)
      result "${TITLE[2.10]}" PASSED "${checked:+$checked; }$(elapsed)"
    else
      result "${TITLE[2.10]}" FAILED "$(elapsed); see $RESULTS_DIR/lean4lean.log"
    fi
  else
    result "${TITLE[2.10]}" SKIPPED "Lean4Lean is not installed ($LEAN4LEAN_BIN)"
  fi
}

# -------------------------------------------------------------------------------------------------
# Run the steps in order. Steps before the resume step are not run; their results are copied from
# the previous summary.
for i in "${!STEPS[@]}"; do
  step="${STEPS[$i]}"
  if [ "$i" -lt "$START_INDEX" ]; then
    if [ "$i" -eq 0 ]; then
      printf '\n== Steps %s to %s are not run again (--resume-step=%s); results of the previous run:\n' \
        "${STEPS[0]}" "${STEPS[$((START_INDEX - 1))]}" "$RESUME_STEP"
    fi
    carry_over "$step"
  else
    "step_${step/./_}"
  fi
done

{ echo; echo "Finished: $(date)"; } >> "$SUMMARY"
echo
if [ "$ALL_PASSED" -eq 1 ]; then
  if [ "$START_INDEX" -gt 0 ]; then
    echo "All ${#STEPS[@]} steps PASSED (steps ${STEPS[0]} to ${STEPS[$((START_INDEX - 1))]} in the previous run). Summary: $SUMMARY"
  else
    echo "All ${#STEPS[@]} steps PASSED. Summary: $SUMMARY"
  fi
  exit 0
else
  echo "Not all steps PASSED. Summary: $SUMMARY"
  exit 1
fi
