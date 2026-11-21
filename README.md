# How to verify the Lean proof of the Riemann Hypothesis claim

This repository lets anyone check, on a Linux computer, the Lean proof that was released at https://alpo.ge as `lean.tar.gz.part01` to `lean.tar.gz.part14` and announced at https://lean4.dev/proofs/riemann-hypothesis-claim. It also contains a small test project. With the test project, every step can be tried in a few hours, before the check of the real proof, which takes days.

## Contents of this repository

| File or folder | Purpose |
|---|---|
| `README.md` | this description: every step, with its command, folder, input, output, software and estimated time |
| `install-software.sh` | section 1: asks which project to install, downloads it, checks it, and installs all software |
| `run-checks.sh` | section 2: runs all checks and writes a summary |
| `test-project/` | the source files of the test project (section "The two projects") |
| `test-project.tar.gz` | the test project packed into one archive; `install-software.sh` takes the test project from this archive, or from the web link that you set |

The files of the Riemann Hypothesis proof are **not** part of this repository. `install-software.sh` downloads the 14 parts from the author's website, joins them into one archive, unpacks it, and confirms with checksums that every file is identical to the author's release (section "Checksums").

## Quick start

```bash
git clone <address of this repository>
cd <repository folder>
./install-software.sh     # asks: 1 = Riemann Hypothesis proof, 2 = test project
./run-checks.sh           # checks the project that was installed last
```

Recommended order: install and check the test project first (about 1 to 3 hours of checking), then the Riemann Hypothesis proof (about 4 to 14 days of checking). Both projects can stay installed at the same time, and they share the software.

To give the answer in advance, or to use another working folder, set environment variables:

```bash
PROJECT=test-project ./install-software.sh
PROJECT=riemann-hypothesis WORK_DIR=/data/rh-check ./install-software.sh
PROJECT=riemann-hypothesis WORK_DIR=/data/rh-check ./run-checks.sh
```

With the Riemann Hypothesis proof, `run-checks.sh` runs for days. Start it so that it continues when the terminal window is closed:

```bash
nohup ./run-checks.sh > run-checks.out 2>&1 &
```

## The two projects

| | Riemann Hypothesis proof | Test project |
|---|---|---|
| Answer to the question of `install-software.sh` | `1` | `2` |
| Name, as the value of `PROJECT` | `riemann-hypothesis` | `test-project` |
| Source | https://alpo.ge: 14 parts, 239,275,554 bytes together | the address in `TEST_PROJECT_URL` at the top of `install-software.sh`; by default the file `test-project.tar.gz` of this repository |
| What it proves | the Riemann Hypothesis and the generalized Riemann Hypothesis for Dirichlet L-functions, in five main theorems | for every real number x: sin(x)² + cos(x)² = 1, in one main theorem |
| Size | 175,187 Lean files, about 1.5 million definitions and theorems | 3 Lean files, 5 definitions and theorems |
| Lean version and libraries | Lean 4.33.1; Mathlib at commit `0df444a3…` and 8 helper libraries (section "Checksums") | the same |
| Time of `run-checks.sh` on a modern computer | about 4 to 14 days | about 1 to 3 hours |
| Free disk space and memory | 200 gigabytes; 32 gigabytes of memory, 64 recommended | 20 gigabytes; 8 gigabytes of memory, 16 recommended |

The test project is built like the Riemann Hypothesis project, so that every step of sections 1 and 2 runs in the same way:

| File in `test-project/` | Content |
|---|---|
| `lean-toolchain` | `leanprover/lean4:v4.33.1`: the same Lean version |
| `lakefile.toml` | the project settings; requires Mathlib at the same commit |
| `lake-manifest.json` | the same library versions as the Riemann Hypothesis project; only the project name differs |
| `src/Statements.lean` | the statement, as a definition: `def SinSqAddCosSq : Prop := ∀ x : ℝ, Real.sin x ^ 2 + Real.cos x ^ 2 = 1` |
| `src/Lemmata.lean` | the proof in three steps, from two facts in Mathlib: cos(x − y) = cos x · cos y + sin x · sin y (`Real.cos_sub`) and cos 0 = 1 (`Real.cos_zero`) |
| `src/Main.lean` | the main theorem: `theorem sin_sq_add_cos_sq_eq_one : SinSqAddCosSq` |

**Where the test project comes from.** `install-software.sh` takes the test project from the address in `TEST_PROJECT_URL`, at the top of the script. The address can be a web link to a `.tar.gz` archive, for example a file attached to a GitHub release or a file on a website, or the path of such an archive on the same computer. The default is the file `test-project.tar.gz` of this repository. The project folder may be at the top level of the archive or up to two folders deeper, so the archive that GitHub makes of a whole repository also works: `https://github.com/<account>/<repository>/archive/refs/heads/main.tar.gz`.

**After changing the test project,** pack it again and put the new checksum into `TEST_PROJECT_SHA256` at the top of `install-software.sh`, or set `TEST_PROJECT_SHA256=""` to skip that comparison. These commands, run in the repository folder, produce the same archive every time from the same files:

```bash
tar --sort=name --owner=0 --group=0 --numeric-owner --mode='u=rwX,go=rX' \
    --mtime='2026-11-21 00:00:00 UTC' -cf - test-project | gzip -n -9 > test-project.tar.gz
sha256sum test-project.tar.gz
```

The test project must keep Lean 4.33.1 and the library versions of the Riemann Hypothesis project, because both projects share the checking tools, and the tools are built for one Lean version.

## Folders

| Name | Meaning | Default |
|---|---|---|
| `REPO_DIR` | the folder of this repository (the folder that contains the scripts) | wherever you cloned it |
| `WORK_DIR` | working folder on a fast local disk | `$HOME/rh-check` |
| `TOOLS_DIR` | lean4export, Lean4Lean and nanoda, shared by both projects | `$WORK_DIR/tools` |
| `PROJECT_WORK_DIR` | working folder of one project | `$WORK_DIR/riemann-hypothesis` or `$WORK_DIR/test-project` |
| `PROJECT_DIR` | the unpacked Lean project | `$PROJECT_WORK_DIR/lean` |
| `CHECKS_DIR` | small files generated by `run-checks.sh` | `$PROJECT_WORK_DIR/checks` |
| `RESULTS_DIR` | the log of every step, and `summary.txt` | `$PROJECT_WORK_DIR/results` |
| `$HOME/.elan`, `$HOME/.cargo`, `$HOME/.rustup` | where elan, Lean and Rust install themselves | set by those installers |
| `$HOME/.cache/mathlib` | prebuilt Mathlib files, downloaded once and used by both projects | set by Mathlib's cache program |

Contents of `WORK_DIR` after both projects are installed and checked:

```text
$WORK_DIR/
├── selected-project              name of the project installed last; run-checks.sh reads it
├── elan-init.sh, rustup-init.sh  installers of elan and Rust (only if the script installed them)
├── tools/                        lean4export/, lean4lean/, nanoda_lib/
├── riemann-hypothesis/
│   ├── download/                 lean.tar.gz.part01 … lean.tar.gz.part14
│   ├── lean.tar.gz               the 14 parts joined
│   ├── files.sha256              checksum of the unpacked files (step 1.8)
│   ├── lean/                     the Lean project; Lake adds lean/.lake/ with the libraries and compiled files
│   ├── checks/                   CheckAxioms.lean, CheckStatements.lean, nanoda-config.json
│   ├── results/                  summary.txt and one log file per step
│   └── main.ndjson               the export file of step 2.9
└── test-project/
    └── …                         the same structure, with download/test-project.tar.gz and test-project.tar.gz
```

## Requirements and the reference computer

- **Operating system:** Linux, with the bash shell.
- **Disk:** a local solid-state disk for `WORK_DIR`, with at least 200 gigabytes free for the Riemann Hypothesis proof, or 20 gigabytes for the test project alone. A network drive, or a Windows drive used from the Windows Subsystem for Linux, is far too slow for hundreds of thousands of small files.
- **Memory:** for the Riemann Hypothesis proof, at least 32 gigabytes, 64 gigabytes recommended: the last build steps and several checks load the whole project, about 1.5 million definitions and theorems, at once. For the test project, at least 8 gigabytes, 16 gigabytes recommended.
- **Internet:** for the downloads of section 1, several gigabytes, mostly Mathlib and its prebuilt files.
- **Estimated times** are rough estimates, not measurements. They assume a **modern computer**: 16 processor cores, 64 gigabytes of memory, a solid-state disk, and an internet connection of about 100 megabits per second.

## 1. Software installation (script: `install-software.sh`)

The script prints the same step numbers as this table. Steps 1.3 to 1.8 depend on the chosen project. Steps 1.9 to 1.15 install the same software for both projects. If the other project was installed before, steps 1.9, 1.10 and 1.12 to 1.15 take only seconds, because the software is already there, and step 1.11 is faster, because the prebuilt Mathlib files are already in `$HOME/.cache/mathlib`.

| Step | Command | Folder to run in | Input | Output (files created or text printed) | Software (name and maker) | Time: Riemann Hypothesis proof | Time: test project |
|---|---|---|---|---|---|---|---|
| 1.1 Choose the project | `./install-software.sh` asks `Enter 1 or 2`; to answer in advance, set `PROJECT=riemann-hypothesis` or `PROJECT=test-project` | `REPO_DIR` | your answer | the chosen project and its folder `$PROJECT_WORK_DIR` | bash (GNU Project) | seconds | seconds |
| 1.2 System tools | Debian or Ubuntu: `sudo apt-get install -y git curl tar gzip coreutils findutils gawk build-essential`; Fedora: `sudo dnf install -y git curl tar gzip coreutils findutils gawk gcc` | any folder | the operating system's package sources | the programs `git`, `curl`, `tar`, `gzip`, `sha256sum`, `find`, `sort`, `xargs`, `df`, `awk` and the C compiler `cc`; the script also prints the free disk space and the memory | the operating system's package manager; Git (Git project); curl (curl project); GNU tools and the GNU C compiler (GNU Project, Free Software Foundation) | 1 to 5 minutes; seconds if all tools are present | the same |
| 1.3 Download the project files | Riemann Hypothesis proof: `curl -fsSL -o download/lean.tar.gz.partNN https://alpo.ge/lean.tar.gz.partNN` for NN = 01 to 14; a part that is already there with the correct checksum is not downloaded again. Test project: `curl -fsSL -o download/test-project.tar.gz <TEST_PROJECT_URL>`, or `cp` if `TEST_PROJECT_URL` is a path on this computer | `$PROJECT_WORK_DIR` | the files at the source address | `$PROJECT_WORK_DIR/download/`, with the 14 parts or with `test-project.tar.gz` | curl (curl project) | 1 to 5 minutes | seconds |
| 1.4 Check each downloaded file | `sha256sum download/lean.tar.gz.partNN` | `$PROJECT_WORK_DIR` | the downloaded files | one checksum per part; each must equal the value in section "Checksums". The test project is one file, the archive itself, which step 1.6 checks | sha256sum (GNU coreutils, GNU Project) | seconds | seconds |
| 1.5 Join the downloaded files into one archive | `cat download/lean.tar.gz.part{01..14} > lean.tar.gz`; for the test project, the one downloaded file is copied to `test-project.tar.gz` | `$PROJECT_WORK_DIR` | the downloaded files | `$PROJECT_WORK_DIR/lean.tar.gz` or `$PROJECT_WORK_DIR/test-project.tar.gz` | cat (GNU coreutils) | seconds | seconds |
| 1.6 Check the archive | `sha256sum lean.tar.gz` or `sha256sum test-project.tar.gz` | `$PROJECT_WORK_DIR` | the archive | its checksum; it must equal the value in section "Checksums", for the test project the value of `TEST_PROJECT_SHA256` | sha256sum (GNU coreutils) | seconds | seconds |
| 1.7 Unpack the archive | `tar -xzf lean.tar.gz -C unpack --no-same-owner`; the folder that contains `lean-toolchain` is then moved to `lean` | `$PROJECT_WORK_DIR` | the archive | `$PROJECT_DIR`: 175,190 files (about 1 gigabyte), or 6 files for the test project | GNU tar (GNU Project) | 1 to 2 minutes | seconds |
| 1.8 Check the unpacked files | `find lean -path lean/.lake -prune -o -type f ! -path lean/lake-manifest.json -print0 \| LC_ALL=C sort -z \| xargs -0 sha256sum \| sha256sum`; then confirm that `lake-manifest.json` pins the 9 library commits listed in section "Checksums" | `$PROJECT_WORK_DIR` | `$PROJECT_DIR` | one checksum over all files except `lake-manifest.json`; it must equal the value in section "Checksums" and is written to `files.sha256` for step 2.1. The project name is written to `$WORK_DIR/selected-project` | GNU findutils, GNU coreutils, GNU grep (GNU Project) | about 1 minute | seconds |
| 1.9 Install elan, the Lean version manager | `curl -sSf -o $WORK_DIR/elan-init.sh https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh`, then `sh $WORK_DIR/elan-init.sh -y --default-toolchain none` | any folder | the installer, downloaded from GitHub | `$HOME/.elan/` with the programs `elan`, `lean` and `lake` | elan (Lean developers, Lean Focused Research Organization); curl | 1 minute | 1 minute |
| 1.10 Install Lean 4.33.1 | `lean --version` | `$PROJECT_DIR` | the file `lean-toolchain`, which contains `leanprover/lean4:v4.33.1` | Lean 4.33.1 in `$HOME/.elan/toolchains/`, including the programs `lean`, `lake` and `leanchecker`; prints the Lean version | elan; Lean 4 (Lean Focused Research Organization) | 2 to 5 minutes | 2 to 5 minutes |
| 1.11 Download Mathlib and the other libraries | `lake exe cache get` | `$PROJECT_DIR` | `lakefile.toml` and `lake-manifest.json` | `$PROJECT_DIR/.lake/packages/`: Mathlib and 8 helper libraries at the pinned commits, and the prebuilt Mathlib files, which are also kept in `$HOME/.cache/mathlib` | Lake (Lean Focused Research Organization); Git; the `cache` program of Mathlib (Mathlib community) | 10 to 30 minutes | 10 to 30 minutes |
| 1.12 Install lean4export | `git clone https://github.com/leanprover/lean4export $TOOLS_DIR/lean4export`; in that folder: `git checkout 15f6055e299ad5b89345e533cc2192f4cc00f659` (tag `v4.33.0`), write `leanprover/lean4:v4.33.1` into `lean-toolchain`, and `lake build` | `$TOOLS_DIR/lean4export` | the source code from GitHub | `$TOOLS_DIR/lean4export/.lake/build/bin/lean4export` | lean4export (Lean developers, Lean Focused Research Organization); Git; Lake | 2 to 10 minutes | 2 to 10 minutes |
| 1.13 Install Lean4Lean | `git clone https://github.com/digama0/lean4lean $TOOLS_DIR/lean4lean`; in that folder: `git checkout 67f63b0c818920dfaed2ad07ccff187a6a8fe1e3`, write `leanprover/lean4:v4.33.1` into `lean-toolchain`, and `lake build lean4lean` (only the command-line program, not the proofs about Lean's type theory that the repository also contains) | `$TOOLS_DIR/lean4lean` | the source code from GitHub | `$TOOLS_DIR/lean4lean/.lake/build/bin/lean4lean` | Lean4Lean (Mario Carneiro); Git; Lake | 5 to 20 minutes | 5 to 20 minutes |
| 1.14 Install the Rust compiler | `curl -sSf -o $WORK_DIR/rustup-init.sh https://sh.rustup.rs`, then `sh $WORK_DIR/rustup-init.sh -y --profile minimal` | any folder | the installer, downloaded from rustup.rs | `$HOME/.cargo/` and `$HOME/.rustup/` with `rustc` and `cargo` | rustup, the Rust compiler and Cargo (Rust project) | 2 to 5 minutes | 2 to 5 minutes |
| 1.15 Install nanoda | `git clone https://github.com/ammkrn/nanoda_lib $TOOLS_DIR/nanoda_lib`; in that folder: `git checkout 0da9f98feadd3a0a2ef4b3dbcf52a298a6fef929` and `cargo build --release --locked` | `$TOOLS_DIR/nanoda_lib` | the source code from GitHub, and the Rust libraries that it uses, from crates.io | `$TOOLS_DIR/nanoda_lib/target/release/nanoda_bin` | nanoda (Chris Bailey, independent developer); Cargo (Rust project) | 1 to 5 minutes | 1 to 5 minutes |
| **Total** | | | | | | **about 30 minutes to 2 hours** | **about 30 minutes to 1.5 hours** |

## 2. Verification (script: `run-checks.sh`)

The script prints the same step numbers as this table, and `$RESULTS_DIR/summary.txt` lists the result of every step with its duration. `<main theorems>` stands for the names of the main theorems: the five names in `CheckAxioms.lean` below for the Riemann Hypothesis proof, and `sin_sq_add_cos_sq_eq_one` for the test project.

| Step | Command | Folder to run in | Input | Output (files created or text printed) | Software (name and maker) | Time: Riemann Hypothesis proof | Time: test project |
|---|---|---|---|---|---|---|---|
| 2.1 Check the project files again | the commands of step 1.8 | `$PROJECT_WORK_DIR` | `$PROJECT_DIR` | PASSED if the checksum equals the value in section "Checksums" (for the test project: the value in `files.sha256`) and all 9 library commits are pinned | GNU findutils, coreutils and grep | 1 to 2 minutes | seconds |
| 2.2 Build: elaborate every file and check every proof with Lean's kernel | `lake build > $RESULTS_DIR/build.log 2>&1` | `$PROJECT_DIR` | `src/` with the Lean files, `lakefile.toml`, the libraries | `$PROJECT_DIR/.lake/build/`: a compiled `.olean` file and bookkeeping files for every Lean file (tens of gigabytes for the Riemann Hypothesis proof); `$RESULTS_DIR/build.log`, which should end with a success message such as `Build completed successfully` | Lake and Lean 4 (Lean Focused Research Organization) | 1.5 to 5 days; 1 to 3 hours more if Mathlib had no prebuilt files | 1 to 5 minutes |
| 2.3 Check the library versions that the build used | `git -C .lake/packages/<library> rev-parse HEAD` for each of the 9 libraries | `$PROJECT_DIR` | `$PROJECT_DIR/.lake/packages/` | each printed commit must equal the pinned commit in section "Checksums" | Git (Git project) | seconds | seconds |
| 2.4 Look for errors and `sorry` | `grep -n -E "(^\|[^[:alnum:]_])error:\|declaration uses .sorry." $RESULTS_DIR/build.log > $RESULTS_DIR/errors-and-sorry.txt` | any folder | `$RESULTS_DIR/build.log` | `$RESULTS_DIR/errors-and-sorry.txt`; for a complete proof it is empty | GNU grep (GNU Project) | seconds | seconds |
| 2.5 List the axioms of the main theorems | `lake env lean $CHECKS_DIR/CheckAxioms.lean > $RESULTS_DIR/axioms.txt` | `$PROJECT_DIR` | `CheckAxioms.lean` (written by the script; content below) and the compiled files | `$RESULTS_DIR/axioms.txt`, one line per theorem, such as `'riemannHypothesis' depends on axioms: [propext, Classical.choice, Quot.sound]` | Lean 4 | 5 to 30 minutes | under 1 minute |
| 2.6 Print the exact statements | `lake env lean $CHECKS_DIR/CheckStatements.lean > $RESULTS_DIR/statements.txt` | `$PROJECT_DIR` | `CheckStatements.lean` (written by the script; content below) and the compiled files | `$RESULTS_DIR/statements.txt`: the type of each main theorem and the full definition of each statement | Lean 4 | 5 to 30 minutes | under 1 minute |
| 2.7 Read the statements (done by a person) | read `$RESULTS_DIR/statements.txt`; find Mathlib's definition of the Riemann Hypothesis with `grep -rn "def RiemannHypothesis" .lake/packages/mathlib/Mathlib` | `$PROJECT_DIR` | `statements.txt`, Mathlib's source files, and the statements as printed by nanoda in `nanoda.log` (step 2.10) | a person's confirmation that the statements are the Riemann Hypothesis and the generalized Riemann Hypothesis for Dirichlet L-functions; for the test project, that the statement is sin(x)² + cos(x)² = 1 for every real number x. The summary shows this step as `TO DO` | a person who knows the mathematics; GNU grep | 30 to 60 minutes of reading | 5 minutes |
| 2.8 Check every stored declaration again with Lean's kernel, in a new process | `lake env leanchecker --fresh Main > $RESULTS_DIR/leanchecker.log 2>&1` | `$PROJECT_DIR` | the compiled files of `Main` and of everything it imports, including Lean's own library and Mathlib | `$RESULTS_DIR/leanchecker.log`; success means that it finishes without an error | leanchecker, part of Lean 4 since version 4.28.0 (Lean Focused Research Organization; formerly the separate program lean4checker, written by Kim Morrison); it uses the same kernel code as Lean | 0.5 to 2 days | 10 to 40 minutes |
| 2.9 Export the main theorems and everything they depend on | `lake env $TOOLS_DIR/lean4export/.lake/build/bin/lean4export Main -- <main theorems> > $PROJECT_WORK_DIR/main.ndjson` | `$PROJECT_DIR` | the compiled files | `$PROJECT_WORK_DIR/main.ndjson`: every definition, theorem and axiom that the main theorems depend on, as text in export format 3.1.0 (one JSON object per line) | lean4export (Lean developers) | 2 to 8 hours | 1 to 5 minutes |
| 2.10 Check with nanoda, an external type checker | `$TOOLS_DIR/nanoda_lib/target/release/nanoda_bin $CHECKS_DIR/nanoda-config.json > $RESULTS_DIR/nanoda.log 2>&1` | `$PROJECT_WORK_DIR` | `main.ndjson` and the settings file `nanoda-config.json` (written by the script; content below) | `$RESULTS_DIR/nanoda.log`: the main theorems and their statements as nanoda reads them, and at the end `Checked N declarations with no errors` | nanoda (Chris Bailey; written separately, in the Rust language) | 0.5 to 2 days | 1 to 10 minutes |
| 2.11 Check with Lean4Lean, a second implementation of Lean's kernel | `lake env $TOOLS_DIR/lean4lean/.lake/build/bin/lean4lean --fresh Main > $RESULTS_DIR/lean4lean.log 2>&1` | `$PROJECT_DIR` | the compiled files | `$RESULTS_DIR/lean4lean.log`; success means that it finishes without an error | Lean4Lean (Mario Carneiro; Lean's kernel written again in the Lean language) | 1 to 5 days | 30 minutes to 2 hours |
| **Total** | | | | | | **about 4 to 14 days of computing** | **about 1 to 3 hours** |

## Content of the generated check files

`run-checks.sh` writes these files into `$CHECKS_DIR`. For the Riemann Hypothesis proof:

`CheckAxioms.lean`:

```lean
import Main

#print axioms riemannHypothesis
#print axioms riemannZeta_eq_zero_re
#print axioms LFunction_ne_zero_of_half_lt_re
#print axioms LFunction_eq_zero_re
#print axioms LFunction_eq_zero_re_of_isPrimitive
```

`CheckStatements.lean`:

```lean
import Main

#check @riemannHypothesis
#check @riemannZeta_eq_zero_re
#check @LFunction_ne_zero_of_half_lt_re
#check @LFunction_eq_zero_re
#check @LFunction_eq_zero_re_of_isPrimitive

#print RiemannHypothesis
#print RiemannZetaZerosOnLine
#print DirichletLNonvanishingRightOfHalf
#print DirichletLZerosOnLine
#print PrimitiveDirichletLZerosOnLine
```

For the test project, the same files contain `sin_sq_add_cos_sq_eq_one` instead of the five theorems and `SinSqAddCosSq` instead of the five statements.

`nanoda-config.json`, the settings file of nanoda, shown here for the test project:

```json
{
  "export_file_path": "<PROJECT_WORK_DIR>/main.ndjson",
  "num_threads": <number of processor cores>,
  "stack_size_bytes": 1073741824,
  "permitted_axioms": ["propext", "Classical.choice", "Quot.sound"],
  "unpermitted_axiom_hard_error": true,
  "nat_extension": true,
  "string_extension": true,
  "pp_declars": ["sin_sq_add_cos_sq_eq_one", "SinSqAddCosSq"],
  "pp_to_stdout": true,
  "print_success_message": true
}
```

What the settings mean, as described in the nanoda README:

- `permitted_axioms` and `unpermitted_axiom_hard_error`: any other axiom in the export file stops nanoda with an error. Because step 2.9 exports only what the main theorems depend on, this repeats the axiom check of step 2.5 with a separately written program.
- `nat_extension` and `string_extension`: the built-in fast arithmetic on natural numbers and strings that Lean's kernel also has.
- `pp_declars` and `pp_to_stdout`: nanoda prints these declarations into `nanoda.log`, so that a person can compare nanoda's reading of the statements with Lean's (step 2.7). A name that is missing from the export file is an error.
- `num_threads` and `stack_size_bytes`: one checking worker per processor core, each with 1 gigabyte of stack for deeply nested proofs.

## What counts as success

1. Steps 2.1 to 2.5 are PASSED. Step 2.5 accepts only the axioms `propext`, `Classical.choice` and `Quot.sound`. `sorryAx` would mean that `sorry` was used, `Lean.ofReduceBool` would mean that `native_decide` was used, and any other name is an extra axiom.
2. Step 2.6 is PASSED, and a person who knows the mathematics has read `statements.txt` and confirms the statements (step 2.7, shown as `TO DO` in the summary).
3. Steps 2.8 to 2.11 are PASSED: the stored proofs were accepted again by Lean's kernel (2.8), by nanoda (2.10) and by Lean4Lean (2.11).

`run-checks.sh` exits with code 0 only if no step FAILED. Every step writes its own log into `$RESULTS_DIR`.

How independent the three re-checks are:

- **leanchecker** (2.8) uses Lean's own kernel code. It protects against changes to the stored results made by the project's own code during the build, not against mistakes in the kernel.
- **Lean4Lean** (2.11) is separate code, written in the Lean language. Its README says that it follows Lean's C++ kernel closely and may therefore share mistakes with it.
- **nanoda** (2.10) is an external type checker, written separately in the Rust language. It is the most independent of the three.

## Checksums

These values were computed from the files downloaded from https://alpo.ge on 21 November 2026, and the scripts compare against them. For full independence, compute them yourself from the author's files too, rather than relying only on this document.

| What | SHA-256 checksum |
|---|---|
| `lean.tar.gz` (the 14 parts joined in order; 239,275,554 bytes) | `9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc` |
| all 175,190 unpacked files (command of step 1.8 without `! -path lean/lake-manifest.json`) | `380706b2ca07209ec036033503a2cfb11ce3d5a7dc002d172174f4b41d65d0a6` |
| all unpacked files except `lake-manifest.json` (command of step 1.8) | `006b98c1b955017540cd9e2dc8e95936da168de104427bf170528e93bd6ebebe` |
| `lean/lake-manifest.json` | `fee57ee9ed399d0a638ca955e5ad40a37a36eeb9b6dfd9f5964114fa7bbe4774` |
| `lean.tar.gz.part01` | `86974b1c242ca7b6748f3299df4fc64ee0f6e06c776ac964fb64888101a3de77` |
| `lean.tar.gz.part02` | `1c2a2477354a9dfa97ff1ce54861e96ed885bd456fffbaaabc2028314a229c42` |
| `lean.tar.gz.part03` | `1465a23b1b579a881e24e5ffaf7c4c3727af28ea24741f1ec80e1d67947530a3` |
| `lean.tar.gz.part04` | `3929e327eecb4e2c5c7cae30e104e6a4a52fa6b82d28325bcda8e9da1c86893b` |
| `lean.tar.gz.part05` | `f25d7e80f7c4ad6d674aa18b323ca760f848857c8755501c149317c38a66c75d` |
| `lean.tar.gz.part06` | `a8c651a68327811b37dce3cca8eda5e0b2102fa227c0d395cbb7553e4dd69939` |
| `lean.tar.gz.part07` | `65c7e502a9b236a0f68d9e0aa6e089d4c09b9fc7a0960a149384063ccbe5e869` |
| `lean.tar.gz.part08` | `71b027ad6e4179c3a50ce72921e3fec0a2dd751ec7472ac2c644ad145a50ec7e` |
| `lean.tar.gz.part09` | `47718977ebaa8613f1647e93134479780db9320c5fa911463fd312a6257b796f` |
| `lean.tar.gz.part10` | `1d85ece78e0779cec26b0cce29c6462d9f90180e56d78120b152df101715240b` |
| `lean.tar.gz.part11` | `cf83a159d1a9540012229c376562587dd966da10cd657cbcef53acfd03232448` |
| `lean.tar.gz.part12` | `1aa5415bd2db83b2689afeeb946419303b3c4f599ae790ad74d38465f768b502` |
| `lean.tar.gz.part13` | `2de4edbce8ebdbfd0b94bc89bab518c7294209f408ec5b14a7be9e4832d9da81` |
| `lean.tar.gz.part14` | `53f8ea43a9b5dcab97b84a52f3ac2848711c844a5420a4c56418093bacb3c6f6` |

Test project, as packed in this repository:

| What | SHA-256 checksum |
|---|---|
| `test-project.tar.gz` | `7871e7afe3575eb2a570cfc23c4480ee97b2cc63bdfa7a7300a10049c2c1529b` |
| all unpacked files except `lake-manifest.json` (command of step 1.8) | `92625addca3c81ee89a44d52e2f9696870a441b5721caf21a80f7931d5b00a83` |

Library commits pinned in `lake-manifest.json` (Git commit identifiers), the same for both projects:

| Library | Commit |
|---|---|
| mathlib | `0df444a360eaa60ab8c11dca51a86af692955474` |
| plausible | `b7eb3304aeae834b12dda98993a37f6a41f6f0bb` |
| LeanSearchClient | `5f4d51b81cbd3f6b32b156bfad9056621a040404` |
| importGraph | `16f02aa7642864af59f1ff0e384a015994db9118` |
| proofwidgets | `4be2e3d5087eeb272cf5a8853b8f9dd025ef5957` |
| aesop | `3448c0bcc5ce01b2d1546e483ec3620e32df3d0e` |
| Qq | `92c15be17b7caf78c2ad767ec40f89052d908d81` |
| batteries | `4488d40d070b9700d4d5a6aa342f0d40c31b2a2d` |
| Cli | `6130a47896ce867c6a4a55373441e59e565bad0f` |

## Versions of the checking tools

| Tool | Version used | Why this version |
|---|---|---|
| Lean, with `lake` and `leanchecker` | 4.33.1, from the project's `lean-toolchain` | the version that the author used |
| lean4export | commit `15f6055e299ad5b89345e533cc2192f4cc00f659` (tag `v4.33.0`), built with Lean 4.33.1 | the release of lean4export for Lean 4.33; there is no tag `v4.33.1`. It writes export format 3.1.0 |
| Lean4Lean | commit `67f63b0c818920dfaed2ad07ccff187a6a8fe1e3`, built with Lean 4.33.1 | the newest version on 21 November 2026, made for Lean 4.33.0-rc2; Lean4Lean has no release tags for Lean versions |
| nanoda | commit `0da9f98feadd3a0a2ef4b3dbcf52a298a6fef929` (nanoda_lib version 0.4.32) | the newest version on 21 November 2026; it reads export format versions from 3.1.0 up to, but not including, 3.2.0 |
| Rust | the newest stable version, installed by rustup | needed only to build nanoda |

Lean's compiled files (`.olean`) can be read only by the exact Lean version that wrote them. Therefore `install-software.sh` builds lean4export and Lean4Lean with Lean 4.33.1, by writing `leanprover/lean4:v4.33.1` into their `lean-toolchain` files. The tool versions are set at the top of `install-software.sh`, in `LEAN4EXPORT_COMMIT`, `LEAN4LEAN_COMMIT` and `NANODA_COMMIT`.

## Notes

- **Never run `lake update`** in `$PROJECT_DIR`. It would replace the pinned library versions with newer ones, and the checks would no longer test the author's setup.
- **Checking the other project.** `run-checks.sh` checks the project that `install-software.sh` installed last. To check the other installed project, run `PROJECT=test-project ./run-checks.sh` or `PROJECT=riemann-hypothesis ./run-checks.sh`.
- **Running again.** Both scripts can be run again. `install-software.sh` does not download a part again if it is already there with the correct checksum, does not unpack again if `$PROJECT_DIR` exists, and does not install software again that is already there. `lake build` only rebuilds what is missing, so a second run of `run-checks.sh` after a completed build takes much less time.
- **Starting a project again from the beginning:** delete its folder `$PROJECT_WORK_DIR`, for example `rm -rf $HOME/rh-check/test-project`, and run `install-software.sh` again.
- **Other commands for nanoda or Lean4Lean.** If a newer version of one of these tools needs a different command, give the complete command in the environment variable `NANODA_CMD` or `LEAN4LEAN_CMD`, for example `NANODA_CMD="/path/to/nanoda_bin /path/to/settings.json" ./run-checks.sh`.

## Software and makers

| Software | What it is | Maker |
|---|---|---|
| elan | installs and selects Lean versions | Lean developers, Lean Focused Research Organization (repository `leanprover/elan`) |
| Lean 4 (programs `lean` and `leanchecker`) | the proof assistant: reads `.lean` files, elaborates them and checks every proof with its kernel. `leanchecker` checks compiled files again with Lean's kernel, in a new process, without running project code; it is part of Lean since version 4.28.0 and was before that the separate program lean4checker | created by Leonardo de Moura at Microsoft Research; since 2023 developed by the Lean Focused Research Organization, a non-profit organization, with community contributors (repository `leanprover/lean4`); lean4checker was written by Kim Morrison |
| Lake (program `lake`) | Lean's build tool; distributed together with Lean | Lean Focused Research Organization; originally written by Mac Malone |
| Mathlib | the community library of mathematics in Lean; defines `RiemannHypothesis`, `riemannZeta`, `DirichletCharacter.LFunction`, `Real.sin` and `Real.cos` | Mathlib community: volunteer maintainers and hundreds of contributors (repository `leanprover-community/mathlib4`) |
| lean4export | writes compiled definitions and proofs into a text format for other checkers | Lean developers (repository `leanprover/lean4export`) |
| nanoda | an external type checker for Lean, written separately in the Rust language | Chris Bailey (repository `ammkrn/nanoda_lib`) |
| Lean4Lean | Lean's kernel written again in the Lean language, closely following the C++ kernel; the repository also contains proofs about Lean's type theory | Mario Carneiro (repository `digama0/lean4lean`) |
| Git, curl, GNU tar, GNU coreutils, GNU findutils, GNU grep, Rust | general tools | Git project; curl project; GNU Project; Rust project |
