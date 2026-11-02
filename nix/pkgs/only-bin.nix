# Only the named executables of `pkg`, ahead of any other package that provides
# the same ones: a profile that holds both Lua and LuaJIT, or luarocks (which
# pulls its own Lua in), would otherwise collide on bin/lua and include/*.
{ lib, runCommand }:
pkg: names:
lib.hiPrio (
  runCommand "${pkg.name}-bin" { } ''
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (n: "ln -s ${pkg}/bin/${n} $out/bin/${n}") names}
  ''
)
