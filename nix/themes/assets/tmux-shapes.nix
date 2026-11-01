# Shapes for tmux's status line segments (`tmuxShape` in catalogue.nix): the
# Nerd Font glyphs that cap the left and right end of a segment. Written as
# code points so no tool can mangle the private-use characters.
# Add a shape: `name = { left = glyph "..."; right = glyph "..."; };`
let
  glyph = code: builtins.fromJSON ''"\u${code}"'';
in
{
  round = {
    left = glyph "e0b6";
    right = glyph "e0b4";
  };
  arrow = {
    left = glyph "e0b2";
    right = glyph "e0b0";
  };
  slant = {
    left = glyph "e0ba";
    right = glyph "e0bc";
  };
  flame = {
    left = glyph "e0c2";
    right = glyph "e0c0";
  };
  square = {
    left = "";
    right = "";
  };
}
