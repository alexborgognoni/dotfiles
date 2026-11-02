# Prebuilt native code and compilers on Nix

Why `import numpy`, `require("sharp")` or `cargo build` can fail on a machine
with Nix although they work everywhere else, what this repository does about it
on **both** hosts (the NixOS machines and the Ubuntu laptop), how to diagnose
and fix a new case, and the tests that keep it working. Read it when a tool
fails with `cannot open shared object file`, `fatal error: ...h: No such file`
or `Could not find ... via pkg-config`, and before adding a runtime or a
compiler.

## The problem in one paragraph

A program built by Nix is linked against Nix's glibc and its dynamic loader,
which looks for libraries **only in the Nix store** (the executable's RUNPATH).
Code that was not built by Nix expects the opposite: a standard loader
(`/lib64/ld-linux-x86-64.so.2`) and libraries in `/usr/lib`. Two things follow,
and a third comes from them:

| Class | What fails | Typical message |
|---|---|---|
| **A. a Nix runtime loads foreign native code** | A Nix-built interpreter (bun, python, lua) loads a prebuilt `.node`/wheel/`.so` that needs `libstdc++` or `libz`. The loader cannot find them, and a library with its own RUNPATH (every wheel) ignores the executable's search path. | `ERR_DLOPEN_FAILED: libstdc++.so.6: cannot open shared object file`, `ImportError: libz.so.1: ...` |
| **B. a Nix compiler builds against the host** | Nix's `gcc` (and so `rustc`, `go` with cgo, `node-gyp`, `pip` building an sdist) sees only Nix's headers and libraries, never `/usr/include` or `/usr/lib`. On Ubuntu `/usr/bin/pkg-config` answers with host paths the compiler cannot use. | `fatal error: openssl/ssl.h: No such file`, `Could not find openssl via pkg-config` |
| **C. a tool downloads an unpatched executable** | rustup toolchains, Go toolchains (`GOTOOLCHAIN=auto`), Gradle JDK provisioning, `mise`/`sdkman` installs, `uv`'s standalone Pythons. They run on Ubuntu (its own loader), but not on NixOS without `nix-ld`. | `Could not start dynamically linked executable`, `stub-ld` |

`nix-ld` only helps class C, and only for **unpatched** executables. A
Nix-built interpreter ignores it (`NIX_LD_LIBRARY_PATH` is read by the stub
loader, which a Nix-built program does not use), and it does not exist on
Ubuntu, where replacing the loader would break the system. So the rule here is:
**make Nix provide it, and use `nix-ld` only as the last resort.**

Do not "fix" any of this with a global `LD_LIBRARY_PATH`: it reaches every
child process. On Ubuntu a Nix `libstdc++` needs a newer glibc than the host's
and crashes the distribution's own programs (the same hazard the `opencode`
wrapper in `nix/packages/default.nix` works around).

## What this repository does, per runtime

Same result on NixOS and Ubuntu: the fixes live in the binaries and the
configuration, not in the host.

| Runtime / tool | Class | Fix | Where |
|---|---|---|---|
| **bun** | A | the executable carries `libstdc++` and `libz` as needed libraries (nixpkgs#573990). Drop it when nixpkgs fixes the issue. | `nix/pkgs/bun-native-libs` |
| **Python** (3.14 with packages, 3.12, 3.13) | A | the interpreter carries them; a virtualenv made from it (venv, uv, poetry) loads wheels. Only the binary is copied and patched, nothing is rebuilt. | `nix/pkgs/python-native-libs` |
| **uv** | A, C | uses the Nix interpreters only, never downloads a standalone Python (`uv.toml`: `python-preference = "only-system"`, `python-downloads = "never"`) | `modules/home/shell/cli.nix` |
| **poetry** | A | takes the first matching `python3.X` on `PATH`, which is the patched one | (nothing to do) |
| **Lua, LuaJIT** | A | same technique; `luarocks` is the one built for the same Lua (nixpkgs' default is for 5.2 and installs rocks 5.5 cannot load) | `nix/pkgs/lua-native-libs` |
| **Node, pnpm** | A | nothing: nixpkgs' node already needs `libstdc++` and `libz` | (guarded by a check) |
| **Java** | A, C | JDK from Nix with `JAVA_HOME` (`programs.java`); the JVM already loads JNI libraries. Gradle gets the Nix JDKs (17, 21) and never downloads one. | `modules/home/toolchains.nix` |
| **PHP** | A, B | extensions from Nix (`php.withExtensions`: phpredis added), not `pecl install` | `nix/packages/default.nix` |
| **Rust** | B, C | `rustc`, `cargo`, `clippy`, `rustfmt`, `rust-analyzer` from nixpkgs, not rustup. A pinned or nightly toolchain, or `-sys` crates: the `rust` template. | `nix/packages/default.nix`, `nix/templates/rust` |
| **Go** | B, C | Go from Nix; `GOTOOLCHAIN=local` (`~/.config/go/env`); cgo libraries: the `go` template | `modules/home/toolchains.nix`, `nix/templates/go` |
| **C / C++** | B | Nix's `gcc` and `pkg-config` (so `/usr/bin/pkg-config` cannot mislead); libraries come from a dev shell: the `c` template | `nix/packages/default.nix`, `nix/templates/c` |
| **mise** | C | only on the Ubuntu laptop (standalone Home Manager), where its downloads run; on NixOS use a dev shell | `modules/home/standalone/mise.nix` |

`nix-ld` stays enabled on NixOS (`modules/nixos/core/nix-ld.nix`) as the safety
net for what cannot be avoided: editors' remote servers, a tool that downloads
its own helper, binaries from npm packages (esbuild, biome, lefthook, ...). If
you reach for it often for the same tool, package that tool instead.

## The shared library list

`nix/pkgs/native-libs.nix` is the one list of libraries the patched runtimes
carry: `libstdc++.so.6` (everything C++) and `libz.so.1` (numpy, pandas, scipy,
OpenCV, onnxruntime, ...). Wheels vendor most of their own libraries (openssl,
libpq, openblas), so the list is short. Add a library only when a prebuilt
module fails with `<name>.so.N: cannot open shared object file` and that name is
a library wheels do **not** vendor; GUI and GPU libraries (`libGL`, `libX11`)
belong in a dev shell instead, because a runtime that loads them eagerly pays
for them at every start.

## Diagnosing a new case

1. Read the message. `cannot open shared object file` is class A (or C on
   NixOS); a missing header or `pkg-config` error is class B; a downloaded
   executable that will not start is class C.
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
   - **A dev shell** for libraries that belong to one project (class B).
   - **`nix-ld`** only when none of that works.
5. Add the runtime to `checks/native-code.nix`, and a line to the table above.

## Projects: dev shells

```sh
nix flake init -t ~/dotfiles/nix#c      # also: #go, #rust
direnv allow                            # the template's .envrc is `use flake`
```

A dev shell names the libraries a build links against (`buildInputs`), and
Nix's `pkg-config` and headers follow from them. Find a name with
`nix search nixpkgs <name>`; `openssl` and `zlib` are in the templates.

For a team repository, keep the shell **out** of it: the global gitignore
already covers `.envrc` and `.direnv/`; put `flake.nix` in a parent folder
(direnv looks upward) or exclude it with `.git/info/exclude`. A flake file that
is not tracked by git is invisible to a flake inside that repository.

A project that pins its tools in `mise.toml` (Daisy) uses `mise install` on the
Ubuntu laptop, which works there because Ubuntu's loader runs the downloads.

## Tests

`nix flake check` runs all of them; each can be run alone with
`nix build path:nix#checks.x86_64-linux.<name>`. The sandbox has no `/usr/lib`
and no distribution headers, like NixOS, so a pass means the fix needs nothing
from the host.

| Check | What it proves |
|---|---|
| `native-addons` | bun, python (and virtualenvs of 3.12, 3.13, 3.14), lua, luajit load a library that needs `libstdc++` and `libz` and has no RPATH; node, php, java do too |
| `native-toolchains` | gcc and pkg-config do **not** find a library without a dev shell (no host path leaks in), rustc links, Go builds and stops at `GOTOOLCHAIN=local`, javac/java work and Gradle downloads no JDK, PHP has Laravel's extensions and phpredis |
| `native-template-c`, `native-template-go` | the dev-shell templates build against Nix's openssl (pkg-config; cgo) |
| `bun-upstream-still-broken` | **fails when nixpkgs' own bun loads the library**: the reminder to drop `pkgs/bun-native-libs` |

When you change `native-libs.nix` or a patched runtime, break it on purpose
once (remove a library) and confirm the check fails: a test that cannot fail
proves nothing. The `rust` template is not in the checks (it needs the
`rust-overlay` input and a network); test it by hand:
`nix flake init -t path:~/dotfiles/nix#rust && nix develop -c cargo --version`.

## Not covered, and not verified

- The NixOS configuration (`vm`) was evaluated, but not built or booted for
  these changes, and no real NixOS host was tried. What was run: the checks in
  a sandbox that matches NixOS (no host libraries), and every runtime on the
  Ubuntu laptop. The full VM test (`nix flake check` boots NixOS) was not run.
- GUI and GPU libraries in wheels (`libGL`, `libX11`): dev shell or `nix-ld`.
- Playwright browsers, Puppeteer's Chrome, `canvas`: use the Nix-packaged
  browsers (`playwright-driver.browsers`) in the project's dev shell.
- Another Python minor than 3.12-3.14, another JDK than 17/21: add it to
  `python-native-libs/package.nix`, or the Gradle list in `toolchains.nix`.
- Ruby, Perl and .NET are not installed; if added, run the probe first.
