# Prebuilt native code and compilers on Nix

Why `import numpy`, `require("sharp")`, `cargo build` or a Maven download can
fail on a machine with Nix although they work everywhere else, what this
repository does about it on **both** hosts (the NixOS machines and the Ubuntu
laptop), how to diagnose and fix a new case, and the tests that keep it
working. Read it when a tool fails with `cannot open shared object file`,
`fatal error: ...h: No such file`, `Could not find ... via pkg-config` or
`PKIX path building failed`, and before adding a runtime or a compiler.

## The problem in one paragraph

A program built by Nix is linked against Nix's glibc and its dynamic loader,
which looks for libraries **only in the Nix store** (the executable's RUNPATH).
Code that was not built by Nix expects the opposite: a standard loader
(`/lib64/ld-linux-x86-64.so.2`) and libraries in `/usr/lib`. Three things follow
from that, and a fourth comes from the corporate network:

| Class | What fails | Typical message |
|---|---|---|
| **A. a Nix runtime loads foreign native code** | A Nix-built interpreter (bun, python, lua) loads a prebuilt `.node`/wheel/`.so` that needs `libstdc++`, `libz`, or a library it dlopens later (the GPU driver, `libGL`). The loader cannot find them, and a library with its own RUNPATH (every wheel) ignores the executable's search path. | `ERR_DLOPEN_FAILED: libstdc++.so.6: cannot open shared object file`, `ImportError: libz.so.1: ...`, `torch.cuda.is_available()` is `False` |
| **B. a Nix compiler builds against the host** | Nix's `gcc` (and so `rustc`, `go` with cgo, `node-gyp`, `pip` building an sdist) sees only Nix's headers and libraries, never `/usr/include` or `/usr/lib`. On Ubuntu `/usr/bin/pkg-config` answers with host paths the compiler cannot use. | `fatal error: openssl/ssl.h: No such file`, `Could not find openssl via pkg-config` |
| **C. a tool downloads an unpatched executable** | Gradle JDK provisioning, `mise`/`sdkman` installs, `uv`'s standalone Pythons, a Playwright browser. They run on Ubuntu (its own loader), but not on NixOS without `nix-ld`. (Not Go's toolchains: static binaries, they run everywhere. Not rustup's: nixpkgs' rustup patches what it downloads, see below.) | `Could not start dynamically linked executable`, `stub-ld` |
| **D. a runtime does not trust the corporate CA** | The laptop sits behind Zscaler's TLS inspection. A runtime that ships its own trust store (the JDK) does not know the corporate root, which Ubuntu deploys to its system store. | `PKIX path building failed` |

`nix-ld` only helps class C, and only for **unpatched** executables. A
Nix-built interpreter ignores it (`NIX_LD_LIBRARY_PATH` is read by the stub
loader, which a Nix-built program does not use), and it does not exist on
Ubuntu, where replacing the loader would break the system. So the rule here is:
**make Nix provide it, and use `nix-ld` only as the last resort.**

Do not "fix" any of this with a global `LD_LIBRARY_PATH`: it reaches every
child process. On Ubuntu a Nix `libstdc++` or `libGL` needs a newer glibc than
the host's and crashes the distribution's own programs (the same hazard the
`opencode` wrapper in `nix/packages/default.nix` works around). What exists
instead is narrow and explicit: see "One command, more libraries" below.

## One rule, two hosts

The Nix runtimes (bun, node, python 3.12-3.14, lua, java, php, rust, go, gcc) are
the **baseline on both hosts**: always there, offline, the same commands. On top
of that, **a project's own version manager decides, where the host can run what
it downloads**:

| | Ubuntu laptop (`my.foreignBinaries` on) | NixOS (off) |
|---|---|---|
| team pins its tools (`mise.toml`, Daisy) | `mise install`: official binaries on Ubuntu's own loader, exact pins from the team's file, nothing of Nix in the repository | a dev shell with the exact version: `nix flake init -t ~/dotfiles/nix#bun` |
| Python a project needs that the Nix set lacks (3.11) | `uv` downloads a standalone Python and it runs natively | not possible without `nix-ld`: a dev shell or `nix-ld` |
| Gradle asks for another JDK | downloads it | the project's dev shell |
| Playwright | `playwright install` (its own browsers run on Ubuntu) | the `node` template: browsers built for Nix, of the project's exact version |
| Go `toolchain` line in `go.mod` | the exact version is downloaded | the same (the toolchains are static) |
| Rust, a `rust-toolchain.toml` | `rustup` fetches the channel; it runs natively | the same: nixpkgs' `rustup` patches every toolchain it downloads (the loader and zlib are Nix's, no host library: checked with `LD_DEBUG`), so no `nix-ld` and no dev shell |

`my.foreignBinaries` (a Home Manager option) is on for the Ubuntu laptop, and off
for NixOS unless the runtimes are not patched (`nix/runtimes.nix`, below). It
drives `uv`, Gradle and `mise`; `native-host-policy` pins what each host gets.

**One source per context.** Inside a project with a `mise.toml`, `bun`, `uv`, ...
come from `mise` (its prompt hook puts them first on PATH); everywhere else, from
Nix. `mise`'s own default also puts its shims directory first on PATH, so that a
shim answered in every directory and shadowed Nix; `activate_shims = false`
turns that off. A script, a git hook run by an IDE or cron has no prompt hook:
use `mise exec -- <command>`. Daisy's doctor passes with this (`bun run setup
--check`), and `~/.config/dotfiles/doctor.d/` of the laptop checks that its Bun
equals the pin in `mise.toml`.

## What this repository does, per runtime

Same result on NixOS and Ubuntu: the fixes live in the binaries and the
configuration, not in the host.

| Runtime / tool | Class | Fix | Where |
|---|---|---|---|
| **bun** | A | the executable carries `libstdc++` and `libz` as needed libraries (nixpkgs#573990). Drop it when nixpkgs fixes the issue. | `nix/pkgs/bun-native-libs` |
| **Python** (3.14 with packages, 3.12, 3.13) | A | the interpreter carries them; a virtualenv made from it (venv, uv, poetry) loads wheels. Only the binary is copied and patched, nothing is rebuilt. | `nix/pkgs/python-native-libs` |
| **uv** | A, C | per host (`uv.toml`). NixOS: the Nix interpreters only, never a download (`only-system`, `never`). Ubuntu: Nix's are the baseline, a version the Nix set lacks is downloaded and runs natively (`managed`, `automatic`). Default **3.13** where a project pins nothing (`~/.config/uv/.python-version`), because the wheel ecosystem lags the newest Python and a bare `python3` is 3.14. A project's own pin wins. | `modules/home/shell/cli.nix` |
| **poetry** | A | runs on the **patched** interpreter. Poetry makes a project's virtualenv from its own Python whenever that satisfies `requires-python`, and nixpkgs' poetry runs on the unpatched `python3.14` of its closure: the venv could not load numpy. (Found by the doctor; tests with `<3.14` had hidden it.) | `nix/pkgs/python-native-libs` (`poetry`) |
| **Lua, LuaJIT** | A | same technique; `luarocks` is the one built for the same Lua (nixpkgs' default is for 5.2 and installs rocks 5.5 cannot load) | `nix/pkgs/lua-native-libs` |
| **Node, pnpm** | A | nothing: nixpkgs' node already needs `libstdc++` and `libz` | (guarded by a check) |
| **Java** | A, C, D | JDK from Nix with `JAVA_HOME` (`programs.java`); the JVM already loads JNI libraries. Gradle uses that JDK and downloads another only where a foreign binary runs (Ubuntu). The corporate roots: see below. | `modules/home/toolchains.nix`, `modules/home/corporate/java-truststore.nix` |
| **PHP** | A, B | extensions from Nix (`php.withExtensions`: phpredis added), not `pecl install` | `nix/packages/default.nix` |
| **Rust** | B | `rustup` on **both** hosts, so a project's `rust-toolchain.toml` is honoured without Nix in the project. nixpkgs' rustup patches the toolchains it downloads, so they run on NixOS too. Nix's own toolchain is linked as rustup's default (`rustup toolchain link nix`, by the home module's activation): the baseline works offline, and a project with a toolchain file gets its channel. `-sys` crates need a library from a dev shell: the `rust` template. Quirk of the package: what cargo runs sees the toolchain's library directories and zlib in `LD_LIBRARY_PATH`. | `modules/home/toolchains.nix`, `nix/templates/rust` |
| **Go** | B | Go from Nix; `go.mod`'s `toolchain` line pins an exact version on every host (the official toolchains are static binaries; tested); cgo libraries: the `go` template | `nix/templates/go` |
| **C / C++** | B | Nix's `gcc` and `pkg-config` (so `/usr/bin/pkg-config` cannot mislead); libraries come from a dev shell: the `c` template | `nix/packages/default.nix`, `nix/templates/c` |
| **GPU / GUI wheels** | A | `with-cuda`, `with-gui-libs`, see below. Prefer headless wheels (`opencv-python-headless`; Daisy's `daisy-rag` forces it). | `nix/pkgs/with-libs` |
| **Playwright** | C | NixOS: the Nix-built browsers of the project's exact Playwright version, the `node` template. Ubuntu: Playwright's own. | `nix/templates/node` |
| **mise** | C | where a foreign binary runs (Ubuntu); `activate_shims = false`, see "One rule". On NixOS: a dev shell, `templates/bun` for an exact Bun | `modules/home/standalone/mise.nix`, `nix/templates/bun` |

`nix-ld` stays enabled on NixOS (`modules/nixos/core/nix-ld.nix`) as the safety
net for what cannot be avoided: editors' remote servers, a tool that downloads
its own helper, binaries from npm packages (esbuild, biome, lefthook, ...). If
you reach for it often for the same tool, package that tool instead.

## The shared library list

`nix/pkgs/native-libs.nix` is the one list of libraries the patched runtimes
carry from the start: `libstdc++.so.6` (everything C++) and `libz.so.1` (numpy,
pandas, scipy, OpenCV, onnxruntime, ...). Wheels vendor most of their own
libraries (openssl, libpq, openblas), so the list is short. Add a library only
when a prebuilt module fails with `<name>.so.N: cannot open shared object file`
and that name is a library wheels do **not** vendor. Anything heavier (graphics,
GPU) does not belong here, because a runtime pays for what it loads at every
start: use the wrappers below.

## One command, more libraries: `with-cuda`, `with-gui-libs`

Some code does not need a library to start but dlopens it later by name: torch
asks for the driver's `libcuda.so.1`, `opencv-python` (not the headless one) or
PyQt for `libGL` and `libX11`. These are wrappers that expose just those
libraries to **one command**; nothing else sees them:

```sh
with-cuda python train.py           # torch.cuda.is_available() is True
with-cuda uv run pytest             # also for uv, poetry, bun, ...
with-gui-libs python app.py         # import cv2 (non-headless), PyQt
```

`with-cuda` links only the driver's compute libraries (`libcuda`, NVML, the
PTX JIT compiler, `nvvm`) from `/run/opengl-driver/lib`, which NixOS
(graphics) and Ubuntu (`targets.genericLinux.gpu`) both provide, matched to the
kernel driver. It prints a notice and still runs the command when there is no
driver. **Without the wrapper a CUDA project silently runs on the CPU**
(`torch.cuda.is_available()` is `False`, no error), so a GPU project belongs in
a direnv shell or a Makefile that calls it. Tested on the RTX A2000 of the
laptop: `daisy-rag`'s torch sees the GPU and runs a matrix multiplication.

## Trusting the corporate CA (class D)

**Everything certificate-related lives in the corporate modules and applies only
with `my.corporate.enable`** (`modules/home/corporate/`, `modules/system-manager/
corporate.nix`): a personal machine gets no CA variable, no Java trust store, no
Gradle trust setting. The check `native-corporate-gating` enforces it (the NixOS
VM user has none, the laptop has all). A new certificate setting goes in a
corporate module, never in a shared one.

On the laptop IT deploys the Zscaler root to Ubuntu's store, and nothing
corporate lives in this repository. Each runtime has to be pointed at that
store; the ones that read it by themselves need nothing:

| Runtime | How it trusts it |
|---|---|
| Go, Cargo, Composer/PHP, `luarocks`, `uv`, bun | the system store (tested through the proxy) |
| Python (requests), Node | `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS` (`corporate/ca-env.nix`) |
| **Java, Gradle** | a store built from Ubuntu's bundle at every switch when it changed (`~/.local/share/java/cacerts.p12`, from `corporate/TrustStore.java`), through `JAVA_TOOL_OPTIONS` and Gradle's `systemProp.*` (`corporate/java-truststore.nix`). The JDK from Nix has its own baked store, without the corporate root; Ubuntu's Java used the system store. |

A certificate Java cannot parse is skipped and reported, never fatal (nixpkgs'
own bundle has descriptive text between its certificates; one odd certificate
must not leave Java without the rest). `JAVA_TOOL_OPTIONS` makes every JVM print
a "Picked up ..." note on stderr: that is the price of covering every JVM.
**A new runtime: test an HTTPS download through the proxy before calling it
done.**

## Diagnosing a new case

1. Read the message. `cannot open shared object file` is class A (or C on
   NixOS); a missing header or `pkg-config` error is class B; a downloaded
   executable that will not start is class C; a certificate error is D.
2. Class A: which library, and does the runtime already have it?
   `readelf -d $(readlink -f $(command -v <runtime>)) | grep -E 'NEEDED|RUNPATH'`
   shows what it loads; `LD_DEBUG=libs <runtime> ... 2>&1 | grep -i 'error\|not found'`
   shows where the loader looked.
3. Reproduce it without the project: build a library that needs the missing
   library and has no RPATH, and load it the way the runtime does
   (`checks/native-code.nix` does this for every runtime; copy its `probe`).
4. Fix it, in this order:
   - **Nix provides it.** A package, a dev shell, `withPackages`/`withExtensions`.
   - **The runtime carries it** (class A, runtimes that are one executable):
     `nix/pkgs/patched-runtime.nix` copies and patches the executable
     (`patchelf --add-needed`), nothing is rebuilt. Add the library to
     `native-libs.nix` if more than one runtime needs it.
   - **A wrapper or a dev shell** for libraries that belong to one command or
     one project (GPU, GUI, class B).
   - **`nix-ld`** only when none of that works.
5. Add the runtime to `checks/native-code.nix`, and a line to the table above.

## Projects: dev shells

```sh
nix flake init -t ~/dotfiles/nix#c      # also: #go, #rust, #node, #bun
direnv allow                            # the template's .envrc is `use flake`
```

A dev shell names the libraries a build links against (`buildInputs`), and
Nix's `pkg-config` and headers follow from them. Find a name with
`nix search nixpkgs <name>`; `openssl` and `zlib` are in the templates.

**Playwright (`#node`).** A Playwright browser is tied to the exact version of
`@playwright/test`: `1.61.1` asks for `chromium_headless_shell-1228`, and
nixpkgs' own browsers are another version (`-1248`), so they fail with
`Executable doesn't exist`. The template takes the browsers from
`playwright-web-flake`, which tags one commit per release: set the tag in
`inputs.playwright.url` to the version in the project's `package.json`. Tested
with Daisy's `playwright-core` 1.61.1: Chromium 149 launches from the shell.
(Firefox fails to open a page with "Unexpected number of tabs" with the
browsers Playwright downloads itself as well, so that is this machine's
Firefox, not Nix.) Puppeteer: see the comment in the template.

For a team repository, keep the shell **out** of it: the global gitignore
covers `.envrc` and `.direnv/`; put `flake.nix` in a parent folder (direnv
looks upward) or exclude it with `.git/info/exclude`. A flake file that is not
tracked by git is invisible to a flake inside that repository. The same global
ignore bit this repository once: **`.envrc` files that belong to the repository
itself (the templates') need `git add -f`**, and `nix flake init` copies only
tracked files.

**An exact Bun (`#bun`).** Daisy's doctor requires exactly its pinned Bun
(`Bun.version`), and the Bun from Nix follows nixpkgs. On the Ubuntu laptop
`mise install` gives the pin. On NixOS the `bun` template builds the official
release of the version written in it (with the libraries prebuilt addons need),
and the hash of a new version is one `nix-prefetch-url` away (the template says
how). Tested with Daisy: exact `1.4.2`, and its 188 image tests pass.

## Tests

`nix flake check` runs all of them; each can be run alone with
`nix build path:nix#checks.x86_64-linux.<name>`. The sandbox has no `/usr/lib`
and no distribution headers, like NixOS, so a pass means the fix needs nothing
from the host.

| Check | What it proves |
|---|---|
| `native-addons` | bun, python (and virtualenvs of 3.12, 3.13, 3.14), the virtualenv a default Poetry project gets, lua, luajit load a library that needs `libstdc++` and `libz` and has no RPATH; node, php, java do too |
| `native-toolchains` | gcc and pkg-config do **not** find a library without a dev shell (no host path leaks in), rustup with the linked Nix toolchain builds offline, Go builds and fetches the toolchain a `go.mod` asks for, `uv` uses the Nix interpreters (3.13 by default, a project's pin wins), javac/java work and Gradle follows the host policy, PHP has Laravel's extensions and phpredis |
| `native-host-policy` | what differs per host, and only that (NixOS: no foreign downloads in `uv` and Gradle, no `mise`; Ubuntu: they may). Evaluated. |
| `native-retreat` | `nix/runtimes.nix` with `patched = false`: the runtimes are plain nixpkgs and run, and NixOS adopts the Ubuntu policy |
| `native-with-libs` | `with-cuda` exposes exactly `libcuda.so.1` (not an unrelated library), `with-gui-libs` finds `libGL`/`libX11`, neither leaks into the calling shell, and `with-cuda` still runs without a driver |
| `native-corporate-gating` | certificate settings exist only with `my.corporate.enable`: none on the NixOS VM user, all on the laptop (an evaluation test; mutation-tested) |
| `native-java-truststore` | the generator keeps every certificate Java can read, skips the unreadable, and refuses a file with none |
| `native-template-c`, `native-template-go` | the dev-shell templates build against Nix's openssl (pkg-config; cgo) |
| `bun-upstream-still-broken` | **fails when nixpkgs' own bun loads the library**: the reminder to drop `pkgs/bun-native-libs` |

`tests/ubuntu-vm/verify.sh` asserts the same on a fresh Ubuntu install (the
real wheels, sharp, the trust store, the toolchains), and `scripts/doctor.sh` runs
the workflows (below).

When you change `native-libs.nix` or a patched runtime, break it on purpose
once (remove a library) and confirm the check fails: a test that cannot fail
proves nothing. In a check script do not call a variable `out`: it is Nix's
output path (it bit this file twice). The `rust` and `node` templates are not in
the checks (they need a network and flake inputs); test them by hand:
`nix flake init -t path:~/dotfiles/nix#rust && nix develop -c cargo --version`.

## The doctor: the workflows that must keep working

The checks above prove the mechanism in a sandbox. `scripts/doctor.sh` proves the
**workflow**, on the real machine, with the real network, proxy, GPU and caches,
in the clean environment of a fresh login:

```sh
scripts/doctor.sh                 # run it after a switch and after `nix flake update`
scripts/doctor.sh --offline       # without the checks that need the network
scripts/doctor.sh --only poetry   # the checks whose name contains the text
scripts/doctor.sh --list
```

It installs and loads a native addon with bun, makes virtualenvs with wheels
(uv, venv, poetry), builds a Rust, Go, C, C++ and Java program, fetches over HTTPS
through the proxy (Maven Central, crates, Go modules, PyPI, Composer, luarocks),
runs a container through the registry mirror, and checks the GPU wrapper. The
first run found a bug the sandbox checks had missed (Poetry's own interpreter).
Every other regression of this work (Java behind the proxy, uv picking a Python
too new for a tool, torch without the GPU) would have shown here first.

A machine adds its own checks in `~/.config/dotfiles/doctor.d/*.sh`, so a
project of the laptop (Daisy's pre-push tests, its doctor, `uvx postgres-mcp`, the
Bun-equals-`mise.toml` pin) is checked without a word of it in this repository.
A check is `check "<name>" "<tags>" '<command>'` (tags: `net`, `gpu`); see the
header of the script. The engine is tested by `tests/scripts/test-doctor.sh`.

## CI

`.github/workflows/ci.yml`, in this repository only (nothing of Nix goes into a
team's repository). A GitHub runner has no proxy, no GPU and none of my caches,
so it runs what a sandbox can:

- every push and pull request: format and linters, the script tests, and the
  native-code checks (`native-addons` ... `native-template-go`, `system-work-laptop`);
- **weekly**, and on demand: the same on the **newest nixpkgs** (`nixpkgs` and
  `nixpkgs-unstable` only, updated inside the run, nothing is committed). The patched runtimes depend on
  nixpkgs internals, so a bump that breaks them turns the run red before it
  reaches a machine; and when `bun-upstream-still-broken` fails because nixpkgs
  fixed nixpkgs#573990, the run opens an issue to drop `pkgs/bun-native-libs`.

The doctor is not in CI (it needs the real machine). CI does not build the NixOS
configuration (470 derivations) or boot the VM.

## If this becomes a burden (the retreat)

The patched runtimes are the part that depends on nixpkgs internals (the Python
env builder, Bun's build phase). If a nixpkgs update breaks them twice, or they
cost more than they give, **one line** returns to plain runtimes:

```nix
# nix/runtimes.nix
{ patched = false; }
```

What changes: bun, python and lua are plain nixpkgs (they run, but do not load
prebuilt native code by themselves). Every host may then run foreign binaries
(`my.foreignBinaries`): NixOS adopts the Ubuntu policy, with `mise`, `uv`'s
standalone Pythons and Gradle's JDK downloads, run by `nix-ld`
(`modules/nixos/core/nix-ld.nix`, always on); and the checks of the patching
(`native-addons`, `native-with-libs`, `bun-upstream-still-broken`) are not run.
It is tested both ways: `native-retreat` builds the plain runtimes and asserts the
policy, and the whole check set passed with the flag flipped. What is lost: wheels
and addons load through `uv`'s standalone Pythons and the project's own `bun`
(on the loader of the host), not through the Nix interpreters; the Ubuntu laptop
already works that way for anything outside the Nix set.

## Cleaning up what this replaces

After the switch, `~/.local/share/uv/python` (uv's standalone Pythons) is unused
on a host that cannot run them (`scripts/cleanup.d/home-leftovers.list`; on the
Ubuntu laptop `uv` may use them again). `~/.rustup` is **in use**: the Nix rustup
keeps its toolchains there, so it is not a leftover.
**Check what still runs on them before deleting**, because deleting a Python
breaks every virtualenv and `uv tool` environment made from it:

```sh
find ~ -maxdepth 6 -name pyvenv.cfg -not -path '*/node_modules/*' -not -path '*/.cache/*' \
  | while read f; do grep -H '^home' "$f" | grep uv/python; done
```

- A project virtualenv: rebuild it on the Nix interpreter first
  (`uv sync --frozen --python 3.12`), compare the imports, then delete the old one.
- A `uv tool` environment that cannot be reinstalled (a version that is gone
  from the index, e.g. `postgres-mcp`'s `pglast==7.2.0` on the corporate mirror):
  repoint it instead of reinstalling: its `bin/python` link to
  `~/.nix-profile/bin/python3.13` and `home`/`version_info` in `pyvenv.cfg`.
  The compiled wheels keep working (same ABI, patched interpreter).
- `~/.cargo/registry` is the crates cache the Nix cargo reuses: keep it.

## Not covered, and not verified

- NixOS: the configuration (`vm`) is **built and booted** by `nix flake check`
  (the `vm` check: a real NixOS under KVM, 17 subtests, 10 minutes), including a
  subtest for the policy of this document (no `mise`, `rustup` with the Nix
  toolchain linked, `uv` Nix-only, `nix-ld` present). What that does not cover: the
  VM has no network (no download is exercised there: the doctor does that on the
  laptop, and the sandbox checks do the rest), no GPU (`with-cuda` was only tried on
  the laptop's), and it is not a real NixOS host: none was tried.
- Puppeteer's Chrome and `canvas` (cairo): documented, not tested.
- Another Python minor than 3.12-3.14, another JDK than the default: add it to
  `python-native-libs/package.nix`, or to the Gradle `paths` in `toolchains.nix`
  (a JDK is ~800 MB, so it is not installed everywhere).
- Ruby, Perl and .NET are not installed; if added, run the probe first.
- CI runs the sandbox checks, not the doctor and not the NixOS build or VM test:
  a nixpkgs bump that breaks a workflow only the real machine sees (the proxy, the
  GPU) is found by running `scripts/doctor.sh`.
