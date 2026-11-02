# shellcheck shell=bash
# The shipped workflows of scripts/doctor.sh: one per runtime or toolchain, each
# a thing that has broken or could break on Nix (docs/NATIVE-CODE.md). Sourced
# by doctor.sh, which defines `check`.

# --- JavaScript ------------------------------------------------------------------
check "bun: install a package with a native addon and load it (sharp)" "net" '
  bun add --silent sharp && bun -e "console.log(require(\"sharp\").versions.vips)"'
check "node: install a package that ships a platform binary and run it (esbuild)" "net" '
  npm init -y >/dev/null && npm install --silent esbuild && npx --no-install esbuild --version'

# --- Python ----------------------------------------------------------------------
check "python: uv virtualenv with wheels (numpy, pandas, pydantic)" "net" '
  uv venv -q v && uv pip install -q --python v/bin/python numpy pandas pydantic &&
  v/bin/python -c "import numpy, pandas, pydantic_core"'
check "python: venv and pip with a wheel" "net" '
  python3 -m venv v && v/bin/pip install -q numpy && v/bin/python -c "import numpy"'
check "python: poetry installs a project with a wheel" "net" '
  cat > pyproject.toml <<TOML
[project]
name = "probe"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["numpy"]

[tool.poetry]
package-mode = false

[build-system]
requires = ["poetry-core>=2.0"]
build-backend = "poetry.core.masonry.api"
TOML
  POETRY_VIRTUALENVS_IN_PROJECT=true poetry install --no-root -q && .venv/bin/python -c "import numpy"'
check "python: a version the Nix set lacks (3.11) follows the host policy" "net" '
  if grep -q "python-downloads = \"automatic\"" ~/.config/uv/uv.toml; then
    uv venv -q --python 3.11 v && v/bin/python -c "import sys; assert sys.version_info[:2] == (3, 11)"
  else
    ! uv venv -q --python 3.11 v 2>/dev/null
  fi'

# --- Rust, Go, C ---------------------------------------------------------------------
check "rust: build a crate with a dependency, clippy and rustfmt" "net" '
  cargo new -q app && cd app && cargo add -q anyhow && cargo build -q && ./target/debug/app &&
  cargo clippy -q && cargo fmt --check'
check "go: fetch a module over HTTPS and run" "net" '
  go mod init probe >/dev/null 2>&1 && go get github.com/google/uuid@v1.6.0 >/dev/null 2>&1
  cat > main.go <<GO
package main

import (
	"fmt"

	"github.com/google/uuid"
)

func main() { fmt.Println(uuid.NewString()) }
GO
  go run .'
check "go: go.mod can pin a toolchain (the official ones are static binaries)" "net" '
  GOTOOLCHAIN=go1.23.4 go version | grep -q go1.23.4'
check "c, c++ and cmake build and run" "" '
  cat > a.c <<C
#include <stdio.h>
int main(void) { puts("c"); return 0; }
C
  cat > b.cc <<CPP
#include <iostream>
int main() { std::cout << "c++" << std::endl; }
CPP
  cat > CMakeLists.txt <<CMAKE
cmake_minimum_required(VERSION 3.10)
project(probe C)
add_executable(probe a.c)
CMAKE
  gcc a.c -o a && ./a && g++ b.cc -o b && ./b && cmake -S . -B build >/dev/null && cmake --build build >/dev/null'

# --- JVM, PHP, Lua -------------------------------------------------------------------
check "java: compile and run, and trust the proxy: HTTPS to Maven Central" "net" '
  printf "public class H { public static void main(String[] a) { System.out.println(\"java\"); } }\n" > H.java &&
  javac H.java && java H && java "$DOCTOR_PROBES/Https.java" https://repo.maven.apache.org/maven2/'
check "php: composer installs a package, and phpredis is there" "net" '
  php -m | grep -qix redis && composer init -n --name=probe/probe >/dev/null 2>&1 &&
  composer require -q --no-interaction psr/log && php -r "require \"vendor/autoload.php\"; echo \"ok\n\";"'
check "lua: luarocks builds a C rock and lua loads it" "net" '
  luarocks --tree tree install lpeg >/dev/null && eval "$(luarocks --tree tree path)" &&
  lua -e "assert(require(\"lpeg\"))"'

# --- Containers, GPU, mise ---------------------------------------------------------------
check "docker: the daemon is up, compose works, an image runs (through the mirror)" "net" '
  docker info >/dev/null && docker compose version >/dev/null && docker run --rm hello-world | grep -q "Hello from Docker"'
check "gpu: with-cuda exposes the driver library to one command" "gpu" '
  with-cuda python3 -c "import ctypes; ctypes.CDLL(\"libcuda.so.1\")"'
check "mise: installed where a foreign binary runs, absent where it does not" "" '
  if grep -q "python-downloads = \"automatic\"" ~/.config/uv/uv.toml; then command -v mise >/dev/null; else ! command -v mise >/dev/null; fi'
