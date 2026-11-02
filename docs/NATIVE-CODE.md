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
| **C. a tool downloads an unpatched executable** | rustup toolchains, Go toolchains (`GOTOOLCHAIN=auto`), Gradle JDK provisioning, `mise`/`sdkman` installs, `uv`'s standalone Pythons, a Playwright browser. They run on Ubuntu (its own loader), but not on NixOS without `nix-ld`. | `Could not start dynamically linked executable`, `stub-ld` |
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

## What this repository does, per runtime

Same result on NixOS and Ubuntu: the fixes live in the binaries and the
configuration, not in the host.

| Runtime / tool | Class | Fix | Where |
|---|---|---|---|
| **bun** | A | the executable carries `libstdc++` and `libz` as needed libraries (nixpkgs#573990). Drop it when nixpkgs fixes the issue. | `nix/pkgs/bun-native-libs` |
| **Python** (3.14 with packages, 3.12, 3.13) | A | the interpreter carries them; a virtualenv made from it (venv, uv, poetry) loads wheels. Only the binary is copied and patched, nothing is rebuilt. | `nix/pkgs/python-native-libs` |
| **uv** | A, C | uses the Nix interpreters only, never downloads a standalone Python (`uv.toml`: `python-preference = "only-system"`, `python-downloads = "never"`). Default **3.13** where a project pins nothing (`~/.config/uv/.python-version`), because the wheel ecosystem lags the newest Python and a bare `python3` is 3.14. A project's own pin wins. | `modules/home/shell/cli.nix` |
| **poetry** | A | takes the first matching `python3.X` on `PATH`, which is a patched one | (nothing to do) |
| **Lua, LuaJIT** | A | same technique; `luarocks` is the one built for the same Lua (nixpkgs' default is for 5.2 and installs rocks 5.5 cannot load) | `nix/pkgs/lua-native-libs` |
| **Node, pnpm** | A | nothing: nixpkgs' node already needs `libstdc++` and `libz` | (guarded by a check) |
| **Java** | A, C, D | JDK from Nix with `JAVA_HOME` (`programs.java`); the JVM already loads JNI libraries. Gradle takes that JDK and never downloads one. The corporate roots: see below. | `modules/home/toolchains.nix`, `modules/home/corporate/java-truststore.nix` |
| **PHP** | A, B | extensions from Nix (`php.withExtensions`: phpredis added), not `pecl install` | `nix/packages/default.nix` |
| **Rust** | B, C | `rustc`, `cargo`, `clippy`, `rustfmt`, `rust-analyzer` from nixpkgs, not rustup. A pinned or nightly toolchain, or `-sys` crates: the `rust` template. | `nix/packages/default.nix`, `nix/templates/rust` |
| **Go** | B, C | Go from Nix; `GOTOOLCHAIN=local` (`~/.config/go/env`); cgo libraries: the `go` template | `modules/home/toolchains.nix`, `nix/templates/go` |
| **C / C++** | B | Nix's `gcc` and `pkg-config` (so `/usr/bin/pkg-config` cannot mislead); libraries come from a dev shell: the `c` template | `nix/packages/default.nix`, `nix/templates/c` |
| **GPU / GUI wheels** | A | `with-cuda`, `with-gui-libs`, see below. Prefer headless wheels (`opencv-python-headless`; Daisy's `daisy-rag` forces it). | `nix/pkgs/with-libs` |
| **Playwright** | C | the Nix-built browsers of the project's exact Playwright version: the `node` template | `nix/templates/node` |
| **mise** | C | only on the Ubuntu laptop (standalone Home Manager), where its downloads run; on NixOS use a dev shell | `modules/home/standalone/mise.nix` |

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
nix flake init -t ~/dotfiles/nix#c      # also: #go, #rust, #node
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

A project that pins its tools in `mise.toml` (Daisy) uses `mise install` on the
Ubuntu laptop, which works there because Ubuntu's loader runs the downloads.
Daisy's doctor requires **exactly** its pinned Bun (`Bun.version`): the Bun from
Nix drifts with `nix flake update`, and NixOS has no `mise`. On NixOS give the
project a dev shell with that Bun.

## Tests

`nix flake check` runs all of them; each can be run alone with
`nix build path:nix#checks.x86_64-linux.<name>`. The sandbox has no `/usr/lib`
and no distribution headers, like NixOS, so a pass means the fix needs nothing
from the host.

| Check | What it proves |
|---|---|
| `native-addons` | bun, python (and virtualenvs of 3.12, 3.13, 3.14), lua, luajit load a library that needs `libstdc++` and `libz` and has no RPATH; node, php, java do too |
| `native-toolchains` | gcc and pkg-config do **not** find a library without a dev shell (no host path leaks in), rustc links, Go builds and stops at `GOTOOLCHAIN=local`, `uv` uses the Nix interpreters (3.13 by default, a project's pin wins, no downloads), javac/java work and Gradle downloads no JDK, PHP has Laravel's extensions and phpredis |
| `native-with-libs` | `with-cuda` exposes exactly `libcuda.so.1` (not an unrelated library), `with-gui-libs` finds `libGL`/`libX11`, neither leaks into the calling shell, and `with-cuda` still runs without a driver |
| `native-corporate-gating` | certificate settings exist only with `my.corporate.enable`: none on the NixOS VM user, all on the laptop (an evaluation test; mutation-tested) |
| `native-java-truststore` | the generator keeps every certificate Java can read, skips the unreadable, and refuses a file with none |
| `native-template-c`, `native-template-go` | the dev-shell templates build against Nix's openssl (pkg-config; cgo) |
| `bun-upstream-still-broken` | **fails when nixpkgs' own bun loads the library**: the reminder to drop `pkgs/bun-native-libs` |

`tests/ubuntu-vm/verify.sh` asserts the same on a fresh Ubuntu install (the
real wheels, sharp, the trust store, the toolchains).

When you change `native-libs.nix` or a patched runtime, break it on purpose
once (remove a library) and confirm the check fails: a test that cannot fail
proves nothing. In a check script do not call a variable `out`: it is Nix's
output path (it bit this file twice). The `rust` and `node` templates are not in
the checks (they need a network and flake inputs); test them by hand:
`nix flake init -t path:~/dotfiles/nix#rust && nix develop -c cargo --version`.

## Cleaning up what this replaces

After the switch, `~/.rustup` (rustup's toolchains) and `~/.local/share/uv/python`
(uv's standalone Pythons) are unused (`scripts/cleanup.d/home-leftovers.list`).
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

- The NixOS configuration (`vm`) was evaluated, and its user package profile
  built without collisions, but it was not built or booted for these changes
  (470 derivations), and no real NixOS host was tried. What was run: the
  checks in a sandbox that matches NixOS (no host libraries), and every
  runtime on the Ubuntu laptop. The full VM test (`nix flake check` boots
  NixOS) was not run, and `with-cuda` was only tried on the laptop's GPU.
- Puppeteer's Chrome and `canvas` (cairo): documented, not tested.
- Another Python minor than 3.12-3.14, another JDK than the default: add it to
  `python-native-libs/package.nix`, or to the Gradle `paths` in `toolchains.nix`
  (a JDK is ~800 MB, so it is not installed everywhere).
- Ruby, Perl and .NET are not installed; if added, run the probe first.
- There is no CI: the checks run when you run `nix flake check`, so the Bun
  reminder only fires then.
