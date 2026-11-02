# Prebuilt native code and compilers on Nix (nix/docs/NATIVE-CODE.md). The
# build sandbox has no /usr/lib and no distribution headers, like NixOS, so
# what passes here needs nothing from the host: that is the point.
#
#   native-addons          every runtime loads a library that was not built by
#                          Nix: needs libstdc++ and libz, has no RPATH (what
#                          npm addons and PyPI wheels are)
#   native-toolchains      the compilers see only Nix's libraries, pkg-config
#                          says so honestly, Go and Gradle download nothing,
#                          PHP has what Laravel needs
#   native-with-libs       with-cuda and with-gui-libs expose exactly the
#                          libraries a wheel dlopens, to one command, no leak
#   native-retreat         runtimes.nix `patched = false`: plain runtimes that
#                          run, and NixOS adopts the foreign-binaries policy
#   native-host-policy     what differs per host: NixOS downloads no foreign
#                          binary (uv, Gradle), Ubuntu may; mise only on Ubuntu
#   native-corporate-gating certificate settings exist only with
#                          my.corporate.enable (none on the NixOS VM user, all on
#                          the laptop)
#   native-java-truststore  the generator of Java's corporate trust store keeps
#                          every certificate of a bundle
#   native-template-c|go   the dev-shell templates build against Nix's
#                          libraries (openssl through pkg-config; cgo)
#   bun-upstream-still-broken
#                          fails once nixpkgs' own bun loads the library: drop
#                          pkgs/bun-native-libs (TODO there)
{
  self,
  inputs,
  pkgs,
}:
let
  inherit (pkgs) lib;
  vm = self.nixosConfigurations.vm;
  hm = vm.config.home-manager.users.${vm.config.my.user.name};
  # the package set of the configuration: unstable, the overlay
  cpkgs = vm.pkgs;
  u = cpkgs.unstable;
  system = pkgs.stdenv.hostPlatform.system;
  # runtimes.nix: with `patched = false` (the retreat) the checks of the patching
  # are not run: there is nothing patched to test
  inherit (import ../runtimes.nix) patched;

  # the configured php (the package groups are the user's packages on NixOS)
  php =
    lib.findFirst (p: lib.hasPrefix "php-with-extensions" p.name)
      (throw "native-code check: no php-with-extensions in the user's packages")
      vm.config.users.users.${vm.config.my.user.name}.packages;
  jdk = hm.programs.java.package;

  # A library that needs libstdc++ and libz and has no RPATH to them
  probe =
    pkgs.runCommand "native-probe"
      {
        nativeBuildInputs = [ pkgs.gcc ];
        buildInputs = [ pkgs.zlib ];
      }
      ''
        mkdir -p $out
        cat > probe.cc <<'EOF'
        #include <string>
        #include <zlib.h>
        extern "C" int probe_answer() { return (int)std::string("ok").size() + (zlibVersion()[0] != 0); }
        EOF
        g++ -shared -fPIC -o $out/libprobe.so probe.cc -lz
        ${pkgs.patchelf}/bin/patchelf --remove-rpath $out/libprobe.so
        readelf -d $out/libprobe.so | grep -q 'libz.so.1'
        readelf -d $out/libprobe.so | grep -q 'libstdc++.so.6'
        ! readelf -d $out/libprobe.so | grep -q -E 'RPATH|RUNPATH'
      '';

  # prints "answer N" when bun loads the library, "ERROR ..." when it cannot
  bunProbe = bun: ''
    ${bun}/bin/bun -e "
      import { dlopen } from 'bun:ffi'
      try {
        const lib = dlopen('${probe}/libprobe.so', { probe_answer: { args: [], returns: 'i32' } })
        console.log('answer', lib.symbols.probe_answer())
      } catch (e) {
        console.log('ERROR', e.message)
      }
    "
  '';

  # a template's dev shell: its build inputs, the way `nix develop` sets them up
  shellOf =
    template:
    (import template).outputs {
      nixpkgs = inputs.nixpkgs-unstable;
      self = { };
    };
  shellInputs =
    template:
    let
      shell = (shellOf template).devShells.${system}.default;
    in
    {
      nativeBuildInputs = shell.nativeBuildInputs ++ shell.buildInputs;
    };
in
{
  native-toolchains =
    pkgs.runCommandCC "check-native-toolchains"
      {
        nativeBuildInputs = [
          u.go
          u.rustup
          u.pkg-config
          u.gnumake
          u.uv
          cpkgs.pythonNativeLibs.python
          cpkgs.pythonNativeLibs.versions
          jdk
          php
        ];
        uvConfig = hm.xdg.configFile."uv/uv.toml".source;
        uvDefault = hm.xdg.configFile."uv/.python-version".source;
        gradleProperties = hm.home.file.".gradle/gradle.properties".source;
      }
      ''
        export HOME=$TMPDIR GOCACHE=$TMPDIR/gocache GOPATH=$TMPDIR/go
        fail() { echo "FAIL: $*"; exit 1; }

        echo "== C: a library that is not Nix's is not found, and pkg-config says so"
        printf '#include <openssl/ssl.h>\nint main(void) { return 0; }\n' > c.c
        if gcc c.c -o c 2>/dev/null; then fail "gcc found a library without being told (a host path leaked in?)"; fi
        if pkg-config --exists openssl; then fail "pkg-config found openssl without a dev shell"; fi

        echo "== Rust: rustup with the Nix toolchain linked as the default (what the home module does), offline"
        export RUSTUP_HOME=$TMPDIR/rustup CARGO_HOME=$TMPDIR/cargo
        rustup toolchain link nix ${cpkgs.rustNixToolchain} || fail "rustup toolchain link"
        rustup default nix || fail "rustup default"
        printf 'fn main() { println!("rust ok"); }\n' > r.rs
        rustc r.rs -o r && ./r | grep -q 'rust ok' || fail "rustc through rustup's proxy"
        [ "$(rustc --version)" = "$(${u.rustc}/bin/rustc --version)" ] || fail "the default toolchain is not Nix's"
        cargo --version >/dev/null && cargo clippy --version >/dev/null && rustfmt --version >/dev/null || fail "cargo, clippy or rustfmt"
        cargo new -q app && (cd app && cargo build -q --offline && ./target/debug/app >/dev/null) || fail "cargo build"

        echo "== Go: builds, and a go.mod that needs a newer Go makes Go fetch it (the toolchains are static)"
        [ "$(go env GOTOOLCHAIN)" = auto ] || fail "GOTOOLCHAIN is $(go env GOTOOLCHAIN), not auto"
        mkdir g && cd g
        printf 'module probe\n\ngo 1.22\n' > go.mod
        printf 'package main\nimport "fmt"\nfunc main() { fmt.Println("go ok") }\n' > main.go
        go run . | grep -q 'go ok' || fail "go run"
        printf 'module probe\n\ngo 1.99\n\ntoolchain go1.99.0\n' > go.mod
        result="$(go run . 2>&1 || true)"
        grep -q 'downloading go1.99' <<<"$result" || fail "go did not try to fetch the toolchain go.mod asks for: $result"
        cd ..

        ${lib.optionalString patched ''
            echo "== uv: the Nix interpreters only, 3.13 by default, a project's pin wins, no downloads"
          mkdir -p uvcfg/uv && cp $uvConfig uvcfg/uv/uv.toml && cp $uvDefault uvcfg/uv/.python-version
            export XDG_CONFIG_HOME=$PWD/uvcfg UV_CACHE_DIR=$TMPDIR/uvcache
            found="$(uv python find)"
            case "$found" in *python3.13) ;; *) fail "uv's default is $found, not python3.13" ;; esac
            mkdir uvproject && ( cd uvproject && echo 3.12 > .python-version && case "$(uv python find)" in *python3.12) ;; *) exit 1 ;; esac ) \
              || fail "a project's .python-version does not win"
            if uv python find 3.9 2>/dev/null; then fail "uv found or fetched a Python that is not in the Nix set"; fi
            venv="$(cd uvproject && uv venv -q v && v/bin/python -c 'import sys; print(sys.prefix)')"
            [ -n "$venv" ] || fail "uv venv"
        ''}

        echo "== Java: javac and java from Nix; Gradle uses that JDK (downloads another only where a foreign binary runs)"
        printf 'public class H { public static void main(String[] a) { System.out.println("java ok"); } }\n' > H.java
        javac H.java && java H | grep -q 'java ok' || fail "javac/java"
        grep -q 'auto-download = ${if patched then "false" else "true"}' $gradleProperties \
          || fail "gradle auto-download does not follow the policy of this host"
        dir="$(sed -n 's/^org.gradle.java.installations.paths = //p' $gradleProperties)"
        [ -x "$dir/bin/java" ] || fail "gradle JDK $dir has no bin/java"

        echo "== PHP: what Laravel needs, and phpredis"
        for ext in ctype curl dom fileinfo filter hash mbstring openssl pcre PDO pdo_pgsql pdo_sqlite session tokenizer xml zip intl redis; do
          php -m | grep -qix "$ext" || fail "php extension $ext is missing"
        done
        touch $out
      '';

  # Certificate settings exist only with my.corporate.enable: a configuration
  # without it (the NixOS VM user) has none, the corporate one (the laptop) has
  # all of them. Evaluated, not built: the assertions are the test.
  native-corporate-gating =
    let
      work = self.homeConfigurations."alex@work-laptop".config;
      traces =
        cfg:
        let
          vars = cfg.programs.zsh.sessionVariables;
        in
        {
          javaOptions = vars ? JAVA_TOOL_OPTIONS;
          caVariables = (vars ? REQUESTS_CA_BUNDLE) || (vars ? NODE_EXTRA_CA_CERTS);
          gradleTrust = lib.any (lib.hasPrefix "systemProp.") (lib.attrNames cfg.programs.gradle.settings);
          trustStoreActivation = cfg.home.activation ? javaTrustStore;
        };
    in
    assert lib.assertMsg (
      !(lib.any lib.id (lib.attrValues (traces hm)))
    ) "certificate settings outside my.corporate.enable: ${builtins.toJSON (traces hm)}";
    assert lib.assertMsg (lib.all lib.id (
      lib.attrValues (traces work)
    )) "the corporate configuration lacks certificate settings: ${builtins.toJSON (traces work)}";
    pkgs.runCommand "check-native-corporate-gating" { } "touch $out";

  # What differs per host, and only that (docs/NATIVE-CODE.md): NixOS cannot
  # run a foreign binary, so it downloads none; Ubuntu can, so it may. The
  # Nix interpreters are the baseline on both. Evaluated, not built.
  native-host-policy =
    let
      work = self.homeConfigurations."alex@work-laptop".config;
      policy = cfg: {
        uv = cfg.programs.uv.settings;
        gradleDownloads = cfg.programs.gradle.settings."org.gradle.java.installations.auto-download";
        goOverride = cfg.xdg.configFile ? "go/env";
        miseInstalled = cfg.programs.mise.enable;
        rustup =
          (lib.any (p: lib.hasPrefix "rustup" (p.name or "")) cfg.home.packages)
          && cfg.home.activation ? rustupNix;
      };
    in
    assert lib.assertMsg (
      (policy hm) == {
        uv =
          if patched then
            {
              python-preference = "only-system";
              python-downloads = "never";
            }
          else
            {
              python-preference = "managed";
              python-downloads = "automatic";
            };
        gradleDownloads = if patched then "false" else "true";
        goOverride = false;
        miseInstalled = !patched;
        rustup = true;
      }
    ) "NixOS policy changed: ${builtins.toJSON (policy hm)}";
    assert lib.assertMsg (
      (policy work) == {
        uv = {
          python-preference = "managed";
          python-downloads = "automatic";
        };
        gradleDownloads = "true";
        goOverride = false;
        miseInstalled = true;
        rustup = true;
      }
    ) "Ubuntu policy changed: ${builtins.toJSON (policy work)}";
    pkgs.runCommand "check-native-host-policy" { } "touch $out";

  # The retreat (runtimes.nix): with `patched = false` the runtimes are plain
  # nixpkgs and still run, and a NixOS host adopts the Ubuntu policy (foreign
  # binaries allowed, nix-ld runs them). Both halves, so flipping the switch on
  # a bad day is a tested move.
  native-retreat =
    let
      plain = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ../pkgs {
            inherit inputs;
            patchedRuntimes = false;
          })
        ];
      };
      user = vm.config.my.user.name;
      retreated = vm.extendModules {
        modules = [ { home-manager.users.${user}.my.foreignBinaries = true; } ];
      };
      hmr = retreated.config.home-manager.users.${user};
    in
    assert lib.assertMsg (
      plain.bun-native-libs.outPath == plain.unstable.bun.outPath
    ) "retreat: bun is not nixpkgs' own";
    assert lib.assertMsg (
      !patched || cpkgs.bun-native-libs.outPath != plain.bun-native-libs.outPath
    ) "the patched and the plain bun are the same package";
    assert lib.assertMsg (
      hmr.programs.uv.settings == {
        python-preference = "managed";
        python-downloads = "automatic";
      }
      && hmr.programs.gradle.settings."org.gradle.java.installations.auto-download" == "true"
      && hmr.programs.mise.enable
    ) "retreat: NixOS did not adopt the foreign-binaries policy";
    pkgs.runCommand "check-native-retreat"
      {
        nativeBuildInputs = [
          plain.bun-native-libs
          plain.pythonNativeLibs.python
          plain.pythonNativeLibs.versions
          plain.luaNativeLibs.lua
          plain.luaNativeLibs.luajit
          plain.luaNativeLibs.luarocks
        ];
      }
      ''
        export HOME=$TMPDIR
        bun --version && python3 --version && python3.12 --version && python3.13 --version
        lua -v && luajit -v | head -1 && luarocks --version | head -1
        touch $out
      '';

  # the corporate trust store of Java: built from a PEM bundle (modules/home/
  # corporate/TrustStore.java), read back by the JDK, as many certificates
  native-java-truststore =
    pkgs.runCommand "check-native-java-truststore" { nativeBuildInputs = [ jdk ]; }
      ''
        bundle=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        report="$(java ${../modules/home/corporate/TrustStore.java} $bundle store.p12 2>skipped.log)"
        echo "$report"
        blocks=$(grep -c 'BEGIN CERTIFICATE' $bundle)
        skipped=$(grep -c '^skipped' skipped.log || true)
        cat > Count.java <<'EOF'
        import java.io.*; import java.security.KeyStore;
        public class Count { public static void main(String[] a) throws Exception {
          KeyStore k = KeyStore.getInstance("PKCS12");
          try (InputStream in = new FileInputStream(a[0])) { k.load(in, "changeit".toCharArray()); }
          System.out.println(k.size()); } }
        EOF
        got=$(java Count.java store.p12)
        # every certificate Java can read is in the store, and an unreadable one is not fatal
        [ "$got" = "$((blocks - skipped))" ] || { echo "FAIL: $got in the store, $blocks in the bundle, $skipped skipped"; exit 1; }
        [ "$got" -ge 100 ] || { echo "FAIL: only $got certificates"; exit 1; }
        [ "$skipped" -le 3 ] || { echo "FAIL: $skipped certificates skipped"; exit 1; }
        # a file without a certificate is an error, not an empty store that hides it
        echo "not a certificate" > none.pem
        if java ${../modules/home/corporate/TrustStore.java} none.pem none.p12 2>/dev/null; then echo "FAIL: an empty bundle gave a store"; exit 1; fi
        touch $out
      '';

  # the c template's dev shell: a build links against openssl through pkg-config
  native-template-c =
    pkgs.runCommandCC "check-native-template-c" (shellInputs ../templates/c/flake.nix)
      ''
        printf '#include <openssl/ssl.h>\n#include <stdio.h>\nint main(void) { puts(OpenSSL_version(OPENSSL_VERSION)); return 0; }\n' > o.c
        gcc o.c $(pkg-config --cflags --libs openssl) -o o
        ./o | grep -q OpenSSL
        cmake --version >/dev/null
        touch $out
      '';

  # the go template's dev shell: cgo against openssl
  native-template-go =
    pkgs.runCommandCC "check-native-template-go" (shellInputs ../templates/go/flake.nix)
      ''
        export HOME=$TMPDIR GOCACHE=$TMPDIR/gocache GOPATH=$TMPDIR/go GOTOOLCHAIN=local
        mkdir project && cd project
        printf 'module probe\n\ngo 1.22\n' > go.mod
        cat > main.go <<'EOF'
        package main

        /*
        #cgo pkg-config: openssl
        #include <openssl/ssl.h>
        */
        import "C"
        import "fmt"

        func main() { fmt.Println("cgo", C.GoString(C.OpenSSL_version(C.OPENSSL_VERSION))) }
        EOF
        go run . | grep -q 'cgo OpenSSL'
        touch $out
      '';
}
// lib.optionalAttrs patched {
  native-addons =
    pkgs.runCommand "check-native-addons"
      {
        nativeBuildInputs = [
          cpkgs.bun-native-libs
          cpkgs.pythonNativeLibs.python
          cpkgs.pythonNativeLibs.versions
          cpkgs.pythonNativeLibs.poetry
          cpkgs.luaNativeLibs.lua
          cpkgs.luaNativeLibs.luajit
          u.nodejs
          php
          jdk
        ];
      }
      ''
        export HOME=$TMPDIR
        probe=${probe}/libprobe.so
        fail() { echo "FAIL: $*"; exit 1; }

        echo "== bun (the cause of sharp failing: nixpkgs#573990)"
        result="$(${bunProbe cpkgs.bun-native-libs} 2>&1)"
        grep -q 'answer 3' <<<"$result" || fail "bun: $result"

        echo "== python, python3.12, python3.13: the interpreter and a virtualenv made from it"
        for py in python3 python3.12 python3.13; do
          for python in "$py" "$TMPDIR/venv-$py/bin/python"; do
            [ "$python" = "$py" ] && ! command -v "$py" >/dev/null && fail "$py is missing"
            [ "$python" != "$py" ] && "$py" -m venv "$TMPDIR/venv-$py"
            result="$("$python" -c "import ctypes; print('answer', ctypes.CDLL('$probe').probe_answer())" 2>&1)" \
              || fail "$python: $result"
            grep -q 'answer 3' <<<"$result" || fail "$python: $result"
          done
        done

        echo "== poetry: a project that allows Poetry's own Python gets a virtualenv that loads native code"
        mkdir poetry-project && cd poetry-project
        printf '[project]\nname = "probe"\nversion = "0.1.0"\nrequires-python = ">=3.12"\n\n[tool.poetry]\npackage-mode = false\n\n[build-system]\nrequires = ["poetry-core>=2.0"]\nbuild-backend = "poetry.core.masonry.api"\n' > pyproject.toml
        POETRY_VIRTUALENVS_IN_PROJECT=true poetry install --no-root -q || fail "poetry install"
        result="$(.venv/bin/python -c "import ctypes; print('answer', ctypes.CDLL('$probe').probe_answer())" 2>&1)" \
          || fail "poetry's virtualenv: $result"
        grep -q 'answer 3' <<<"$result" || fail "poetry's virtualenv: $result"
        cd ..

        echo "== lua, luajit"
        result="$(lua -e "local f, e = package.loadlib('$probe', 'probe_answer'); assert(f, e); print('answer', f())" 2>&1)" \
          || fail "lua: $result"
        result="$(luajit -e "local ffi = require('ffi'); ffi.cdef('int probe_answer();'); print('answer', ffi.load('$probe').probe_answer())" 2>&1)" \
          || fail "luajit: $result"

        echo "== node, php, java: load it without help; a regression in nixpkgs would show here"
        result="$(node -e "try { process.dlopen({ exports: {} }, '$probe') } catch (e) { console.log(e.message) }" 2>&1)"
        grep -q 'did not self-register' <<<"$result" || fail "node: $result"
        mkdir -p php-ext && cp $probe php-ext/
        result="$(php -d enable_dl=1 -d extension_dir=$PWD/php-ext -r "dl('libprobe.so');" 2>&1 || true)"
        grep -q 'Invalid library' <<<"$result" || fail "php: $result"
        cat > P.java <<'EOF'
        public class P { public static void main(String[] a) { System.load(a[0]); System.out.println("loaded"); } }
        EOF
        result="$(java P.java $probe 2>&1)" || fail "java: $result"
        grep -q loaded <<<"$result" || fail "java: $result"
        touch $out
      '';

  # with-cuda / with-gui-libs: a library the runtime dlopens by name is found
  # under the wrapper and not without it, and nothing else is exposed or leaks
  native-with-libs =
    pkgs.runCommandCC "check-native-with-libs"
      {
        nativeBuildInputs = [
          cpkgs.pythonNativeLibs.python
          cpkgs.withLibs.with-cuda
          cpkgs.withLibs.with-gui-libs
        ];
        buildInputs = [
          u.libglvnd
          u.libx11
        ];
      }
      ''
        export HOME=$TMPDIR
        fail() { echo "FAIL: $*"; exit 1; }
        load() { python3 -c "import ctypes; ctypes.CDLL('$1')" 2>&1; }

        echo "== with-cuda: libcuda.so.1 from the driver directory, only that"
        mkdir driver && cp ${probe}/libprobe.so driver/libcuda.so.1
        cp ${probe}/libprobe.so driver/libvulkan_unrelated.so.1
        load libcuda.so.1 >/dev/null && fail "libcuda.so.1 was found without the wrapper"
        export WITH_LIBS_DRIVER_DIR=$PWD/driver XDG_CACHE_HOME=$PWD/cache
        with-cuda python3 -c "import ctypes; ctypes.CDLL('libcuda.so.1')" || fail "with-cuda did not expose libcuda.so.1"
        [ "$(ls $XDG_CACHE_HOME/with-cuda)" = libcuda.so.1 ] || fail "with-cuda exposed: $(ls $XDG_CACHE_HOME/with-cuda)"
        with-cuda python3 -c "import ctypes; ctypes.CDLL('libvulkan_unrelated.so.1')" 2>/dev/null && fail "with-cuda exposed an unrelated library"
        [ -z "''${LD_LIBRARY_PATH:-}" ] || fail "LD_LIBRARY_PATH leaked into the calling shell"
        [ "$(with-cuda sh -c 'echo "$LD_LIBRARY_PATH"')" = "$XDG_CACHE_HOME/with-cuda" ] || fail "unexpected LD_LIBRARY_PATH"
        result="$(WITH_LIBS_DRIVER_DIR=$PWD/none with-cuda echo ran 2>&1)"
        grep -q "no NVIDIA driver" <<<"$result" && grep -q "^ran$" <<<"$result" || fail "without a driver: $result"
        with-cuda 2>/dev/null && fail "with-cuda without a command succeeded"

        echo "== with-gui-libs: a library that needs libGL and libX11"
        cat > gui.c <<'EOF'
        extern int glGetError(void);
        extern void *XOpenDisplay(const char *);
        int gui_probe(void) { return glGetError() + (XOpenDisplay(0) != 0); }
        EOF
        gcc -shared -fPIC -o libgui.so gui.c -lGL -lX11
        ${pkgs.patchelf}/bin/patchelf --remove-rpath libgui.so
        readelf -d libgui.so | grep -q 'libGL.so.1' || fail "the GUI probe does not need libGL"
        load $PWD/libgui.so >/dev/null && fail "libGL was found without the wrapper"
        with-gui-libs python3 -c "import ctypes; ctypes.CDLL('$PWD/libgui.so')" || fail "with-gui-libs did not expose libGL/libX11"
        touch $out
      '';

  # An upstream fix: the reminder to drop pkgs/bun-native-libs
  bun-upstream-still-broken =
    pkgs.runCommand "check-bun-upstream-still-broken" { nativeBuildInputs = [ ]; }
      ''
        export HOME=$TMPDIR
        result="$(${bunProbe inputs.nixpkgs-unstable.legacyPackages.${system}.bun} 2>&1)"
        if grep -q 'answer 3' <<<"$result"; then
          echo "nixpkgs' own bun now loads libraries that need libstdc++ and libz:"
          echo "https://github.com/NixOS/nixpkgs/issues/573990 is fixed."
          echo "Drop pkgs/bun-native-libs (the TODO in its package.nix) and this check."
          exit 1
        fi
        grep -q 'cannot open shared object file' <<<"$result" || { echo "unexpected: $result"; exit 1; }
        touch $out
      '';
}
