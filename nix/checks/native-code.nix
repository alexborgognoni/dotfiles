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
  native-addons =
    pkgs.runCommand "check-native-addons"
      {
        nativeBuildInputs = [
          cpkgs.bun-native-libs
          cpkgs.pythonNativeLibs.python
          cpkgs.pythonNativeLibs.versions
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

  native-toolchains =
    pkgs.runCommandCC "check-native-toolchains"
      {
        nativeBuildInputs = [
          u.go
          u.rustc
          u.pkg-config
          u.gnumake
          jdk
          php
        ];
        goEnv = hm.xdg.configFile."go/env".source;
        gradleProperties = hm.home.file.".gradle/gradle.properties".text;
      }
      ''
        export HOME=$TMPDIR GOCACHE=$TMPDIR/gocache GOPATH=$TMPDIR/go
        fail() { echo "FAIL: $*"; exit 1; }

        echo "== C: a library that is not Nix's is not found, and pkg-config says so"
        printf '#include <openssl/ssl.h>\nint main(void) { return 0; }\n' > c.c
        if gcc c.c -o c 2>/dev/null; then fail "gcc found a library without being told (a host path leaked in?)"; fi
        if pkg-config --exists openssl; then fail "pkg-config found openssl without a dev shell"; fi

        echo "== Rust: rustc links with Nix's cc and the binary runs"
        printf 'fn main() { println!("rust ok"); }\n' > r.rs
        rustc r.rs -o r && ./r | grep -q 'rust ok' || fail "rustc"

        echo "== Go: builds, and never downloads a toolchain (config: go/env)"
        mkdir -p cfg/go && cp $goEnv cfg/go/env
        export XDG_CONFIG_HOME=$PWD/cfg
        [ "$(go env GOTOOLCHAIN)" = local ] || fail "GOTOOLCHAIN is $(go env GOTOOLCHAIN), not local"
        mkdir g && cd g
        printf 'module probe\n\ngo 1.22\n' > go.mod
        printf 'package main\nimport "fmt"\nfunc main() { fmt.Println("go ok") }\n' > main.go
        go run . | grep -q 'go ok' || fail "go run"
        printf 'module probe\n\ngo 1.99\n\ntoolchain go1.99.0\n' > go.mod
        result="$(go run . 2>&1 || true)"
        grep -q 'GOTOOLCHAIN=local' <<<"$result" || fail "go did not stop at GOTOOLCHAIN=local: $result"
        cd ..

        echo "== Java: javac and java from Nix; Gradle takes the JDKs from Nix and downloads none"
        printf 'public class H { public static void main(String[] a) { System.out.println("java ok"); } }\n' > H.java
        javac H.java && java H | grep -q 'java ok' || fail "javac/java"
        grep -q 'auto-download=false' <<<"$gradleProperties" || fail "gradle auto-download is not off"
        for dir in $(grep installations.paths <<<"$gradleProperties" | cut -d= -f2 | tr , ' '); do
          [ -x "$dir/bin/java" ] || fail "gradle JDK $dir has no bin/java"
        done

        echo "== PHP: what Laravel needs, and phpredis"
        for ext in ctype curl dom fileinfo filter hash mbstring openssl pcre PDO pdo_pgsql pdo_sqlite session tokenizer xml zip intl redis; do
          php -m | grep -qix "$ext" || fail "php extension $ext is missing"
        done
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
