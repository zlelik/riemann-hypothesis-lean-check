#!/usr/bin/env bash
#
# run-checks.sh
#
# Part 2 of 2 for verifying a Lean proof; run install-software.sh first. README.md explains every
# step in section "2. Verification"; this script prints the same step numbers.
#
# It checks the project that install-software.sh installed last (its name is in the file
# $WORK_DIR/selected-project). To check another installed project, set PROJECT, for example:
#   PROJECT=test-project ./run-checks.sh
#
#   2.1   the project files are identical to the published files; the library versions are pinned
#   2.2   lake build: every file is elaborated and every proof is checked by Lean's kernel
#   2.3   the libraries used by the build are at the pinned versions
#   2.4   the build messages contain no errors and no "declaration uses 'sorry'"
#   2.5   #print axioms: the main theorems use only propext, Classical.choice and Quot.sound
#   2.6   the exact statements of the main theorems are printed
#   2.7   a person reads those statements (this script only reminds you)
#   2.8   leanchecker --fresh: Lean's kernel checks every stored declaration again, in a new process
#   2.9   lean4export: the main theorems and everything they depend on are written to one file
#   2.10  nanoda: an external type checker, written separately in Rust, checks that file
#   2.11  Lean4Lean: a second implementation of Lean's kernel, written in Lean, checks every
#         stored declaration
#
# Results: $WORK_DIR/<project>/results/ (one log file per step, and summary.txt)
#
# Optional settings (environment variables):
#   WORK_DIR, TOOLS_DIR   as in install-software.sh
#   PROJECT               riemann-hypothesis or test-project (default: the project installed last)
#   NANODA_CMD            complete command that runs nanoda, if the default command does not fit
#                         the installed nanoda version (see the nanoda_lib README)
#   LEAN4LEAN_CMD         complete command that runs Lean4Lean, if the default command does not
#                         fit; it is run inside the project folder

set -uo pipefail

WORK_DIR="${WORK_DIR:-$HOME/rh-check}"
TOOLS_DIR="${TOOLS_DIR:-$WORK_DIR/tools}"
export PATH="$HOME/.elan/bin:$HOME/.cargo/bin:$PATH"

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
    EXPECTED_FILES_SHA256="$(cat "$WORK_DIR/test-project/files.sha256" 2>/dev/null)" ;;
  "")
    echo "ERROR: no project is installed yet ($WORK_DIR/selected-project not found). Run install-software.sh first."
    exit 1 ;;
  *)
    echo "ERROR: unknown project '$PROJECT'; use riemann-hypothesis or test-project."
    exit 1 ;;
esac
PROJECT_WORK_DIR="$WORK_DIR/$PROJECT"
PROJECT_DIR="$PROJECT_WORK_DIR/lean"
RESULTS_DIR="$PROJECT_WORK_DIR/results"
CHECKS_DIR="$PROJECT_WORK_DIR/checks"
EXPORT_FILE="$PROJECT_WORK_DIR/main.ndjson"
LEAN4EXPORT_BIN="$TOOLS_DIR/lean4export/.lake/build/bin/lean4export"
LEAN4LEAN_BIN="$TOOLS_DIR/lean4lean/.lake/build/bin/lean4lean"
NANODA_BIN="$TOOLS_DIR/nanoda_lib/target/release/nanoda_bin"

[ -d "$PROJECT_DIR" ] || { echo "ERROR: $PROJECT_DIR not found. Run install-software.sh first."; exit 1; }
mkdir -p "$RESULTS_DIR" "$CHECKS_DIR"
SUMMARY="$RESULTS_DIR/summary.txt"
ALL_PASSED=1

result() {   # $1 = step, $2 = PASSED, FAILED, SKIPPED or "TO DO", $3 = details
  printf '%-52s %-8s %s\n' "$1" "$2" "$3" | tee -a "$SUMMARY"
  if [ "$2" = FAILED ]; then ALL_PASSED=0; fi
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

lean_version=$(cd "$PROJECT_DIR" && lean --version 2>/dev/null | head -n 1)
{
  echo "Verification of the Lean project '$PROJECT' in $PROJECT_DIR"
  echo "Started:     $(date)"
  echo "Lean:        ${lean_version:-not installed}"
  echo "lean4export: commit $(commit_of "$TOOLS_DIR/lean4export")"
  echo "Lean4Lean:   commit $(commit_of "$TOOLS_DIR/lean4lean")"
  echo "nanoda:      commit $(commit_of "$TOOLS_DIR/nanoda_lib")"
  echo
} > "$SUMMARY"

# -------------------------------------------------------------------------------------------------
heading "2.1 Project files and pinned library versions"
problems=()
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
  result "2.1 Project files identical to the published files" PASSED "checksum $got"
else
  result "2.1 Project files identical to the published files" FAILED "${problems[*]}"
fi

# -------------------------------------------------------------------------------------------------
heading "2.2 lake build (progress is written to $RESULTS_DIR/build.log)"
start_timer
BUILD_OK=0
if (cd "$PROJECT_DIR" && lake build) > "$RESULTS_DIR/build.log" 2>&1; then
  BUILD_OK=1
  result "2.2 lake build (Lean's kernel checks every proof)" PASSED "$(elapsed); log: $RESULTS_DIR/build.log"
else
  result "2.2 lake build (Lean's kernel checks every proof)" FAILED "$(elapsed); see $RESULTS_DIR/build.log"
fi

# -------------------------------------------------------------------------------------------------
heading "2.3 Library versions used by the build"
problems=()
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
  result "2.3 Libraries at the pinned versions" PASSED "all ${#PINNED_LIBRARIES[@]} libraries"
else
  result "2.3 Libraries at the pinned versions" FAILED "${problems[*]}"
fi

# -------------------------------------------------------------------------------------------------
heading "2.4 Errors and 'sorry' in the build messages"
ERROR_PATTERN='(^|[^[:alnum:]_])error:'
SORRY_PATTERN="declaration uses .sorry."
errors=$(grep -c -E "$ERROR_PATTERN" "$RESULTS_DIR/build.log" 2>/dev/null)
sorries=$(grep -c -E "$SORRY_PATTERN" "$RESULTS_DIR/build.log" 2>/dev/null)
grep -n -E "$ERROR_PATTERN|$SORRY_PATTERN" "$RESULTS_DIR/build.log" > "$RESULTS_DIR/errors-and-sorry.txt" 2>/dev/null
if [ "$BUILD_OK" -ne 1 ]; then
  result "2.4 No errors and no 'sorry' in the build messages" SKIPPED "the build did not complete (step 2.2)"
elif [ "${errors:-0}" -eq 0 ] && [ "${sorries:-0}" -eq 0 ]; then
  result "2.4 No errors and no 'sorry' in the build messages" PASSED "0 errors, 0 sorry"
else
  result "2.4 No errors and no 'sorry' in the build messages" FAILED "${errors:-?} error lines, ${sorries:-?} sorry warnings; see $RESULTS_DIR/errors-and-sorry.txt"
fi

# -------------------------------------------------------------------------------------------------
heading "2.5 Axioms used by the main theorems"
{ echo "import Main"; echo; for t in "${THEOREMS[@]}"; do echo "#print axioms $t"; done; } > "$CHECKS_DIR/CheckAxioms.lean"
start_timer
if (cd "$PROJECT_DIR" && lake env lean "$CHECKS_DIR/CheckAxioms.lean") > "$RESULTS_DIR/axioms.txt" 2>&1; then
  bad=()
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
    result "2.5 Only the standard axioms are used" PASSED "propext, Classical.choice, Quot.sound; $(elapsed)"
  else
    result "2.5 Only the standard axioms are used" FAILED "${bad[*]}"
  fi
else
  result "2.5 Only the standard axioms are used" FAILED "Lean could not run CheckAxioms.lean; see $RESULTS_DIR/axioms.txt"
fi

# -------------------------------------------------------------------------------------------------
heading "2.6 Exact statements of the main theorems"
{ echo "import Main"; echo
  for t in "${THEOREMS[@]}"; do echo "#check @$t"; done; echo
  for d in "${STATEMENTS[@]}"; do echo "#print $d"; done; } > "$CHECKS_DIR/CheckStatements.lean"
if (cd "$PROJECT_DIR" && lake env lean "$CHECKS_DIR/CheckStatements.lean") > "$RESULTS_DIR/statements.txt" 2>&1; then
  result "2.6 Statements printed" PASSED "see $RESULTS_DIR/statements.txt"
else
  result "2.6 Statements printed" FAILED "Lean could not run CheckStatements.lean; see $RESULTS_DIR/statements.txt"
fi
result "2.7 Statements read by a person" "TO DO" "read $RESULTS_DIR/statements.txt (README.md, step 2.7)"

# -------------------------------------------------------------------------------------------------
heading "2.8 leanchecker (Lean's kernel again, in a new process)"
if (cd "$PROJECT_DIR" && lake env sh -c 'command -v leanchecker') >/dev/null 2>&1; then
  start_timer
  if (cd "$PROJECT_DIR" && lake env leanchecker --fresh Main) > "$RESULTS_DIR/leanchecker.log" 2>&1; then
    result "2.8 leanchecker: Lean's kernel again" PASSED "$(elapsed)"
  else
    result "2.8 leanchecker: Lean's kernel again" FAILED "$(elapsed); see $RESULTS_DIR/leanchecker.log"
  fi
else
  result "2.8 leanchecker: Lean's kernel again" FAILED "leanchecker not found; it is part of Lean 4.28.0 and newer"
fi

# -------------------------------------------------------------------------------------------------
heading "2.9 lean4export (write the main theorems and everything they depend on to $EXPORT_FILE)"
EXPORT_OK=0
if [ -x "$LEAN4EXPORT_BIN" ]; then
  start_timer
  # LEAN_ABORT_ON_PANIC=1 makes lean4export stop with an error, instead of only printing a
  # message, if for example one of the theorem names is not found.
  if (cd "$PROJECT_DIR" && LEAN_ABORT_ON_PANIC=1 lake env "$LEAN4EXPORT_BIN" Main -- "${THEOREMS[@]}") \
       > "$EXPORT_FILE" 2> "$RESULTS_DIR/lean4export.log" && [ -s "$EXPORT_FILE" ]; then
    EXPORT_OK=1
    result "2.9 Export for nanoda" PASSED "$(du -h "$EXPORT_FILE" | cut -f1) written; $(elapsed)"
  else
    result "2.9 Export for nanoda" FAILED "see $RESULTS_DIR/lean4export.log"
  fi
else
  result "2.9 Export for nanoda" SKIPPED "lean4export is not installed ($LEAN4EXPORT_BIN)"
fi

# -------------------------------------------------------------------------------------------------
heading "2.10 nanoda (external type checker written in Rust)"
# Settings as described in the nanoda_lib README: only the three standard axioms are allowed, and
# any other axiom in the export file stops the check with an error. nanoda also prints the main
# theorems and their statements back, as nanoda itself reads them.
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
    result "2.10 nanoda: external type checker" PASSED "$(elapsed)"
  else
    result "2.10 nanoda: external type checker" FAILED "$(elapsed); see $RESULTS_DIR/nanoda.log"
  fi
elif [ ! -x "$NANODA_BIN" ]; then
  result "2.10 nanoda: external type checker" SKIPPED "nanoda is not installed ($NANODA_BIN)"
elif [ "$EXPORT_OK" -ne 1 ]; then
  result "2.10 nanoda: external type checker" SKIPPED "no export file (step 2.9)"
else
  start_timer
  if "$NANODA_BIN" "$CHECKS_DIR/nanoda-config.json" > "$RESULTS_DIR/nanoda.log" 2>&1 \
       && grep -q "declarations with no errors" "$RESULTS_DIR/nanoda.log"; then
    result "2.10 nanoda: external type checker" PASSED "$(grep -o 'Checked [0-9]* declarations' "$RESULTS_DIR/nanoda.log" | tail -n 1); $(elapsed)"
  else
    result "2.10 nanoda: external type checker" FAILED "$(elapsed); see $RESULTS_DIR/nanoda.log"
  fi
fi

# -------------------------------------------------------------------------------------------------
heading "2.11 Lean4Lean (Lean's kernel written again in Lean)"
if [ -n "${LEAN4LEAN_CMD:-}" ] || [ -x "$LEAN4LEAN_BIN" ]; then
  start_timer
  if [ -n "${LEAN4LEAN_CMD:-}" ]; then
    (cd "$PROJECT_DIR" && bash -c "$LEAN4LEAN_CMD") > "$RESULTS_DIR/lean4lean.log" 2>&1
  else
    (cd "$PROJECT_DIR" && lake env "$LEAN4LEAN_BIN" --fresh Main) > "$RESULTS_DIR/lean4lean.log" 2>&1
  fi
  if [ $? -eq 0 ]; then
    result "2.11 Lean4Lean: second kernel implementation" PASSED "$(elapsed)"
  else
    result "2.11 Lean4Lean: second kernel implementation" FAILED "$(elapsed); see $RESULTS_DIR/lean4lean.log"
  fi
else
  result "2.11 Lean4Lean: second kernel implementation" SKIPPED "Lean4Lean is not installed ($LEAN4LEAN_BIN)"
fi

# -------------------------------------------------------------------------------------------------
{ echo; echo "Finished: $(date)"; } >> "$SUMMARY"
echo
echo "Summary written to $SUMMARY"
echo
echo "Step 2.7 is for a person: read $RESULTS_DIR/statements.txt and confirm that the"
echo "statements say exactly what the project claims (README.md, step 2.7)."
if [ "$ALL_PASSED" -eq 1 ]; then exit 0; else exit 1; fi
