# Accent colors: every theme's base16 slots named by hue, and the named
# palettes of the catppuccin flavours.
{ lib }:
let
  # Every theme can use its base16 accent slots (base08-base0F). Slots are
  # semantic, not hues (base0E is "keywords", whatever its color), so they are
  # named by their actual hue; on a clash the lighter one is "light-<hue>".
  hsl =
    hex:
    let
      ch = i: (lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex))) / 255.0;
      r = ch 0;
      g = ch 2;
      b = ch 4;
      mx = lib.max r (lib.max g b);
      mn = lib.min r (lib.min g b);
      d = mx - mn;
      l = (mx + mn) / 2;
      h0 =
        if d == 0 then
          0.0
        else if mx == r then
          60 * ((g - b) / d)
        else if mx == g then
          60 * ((b - r) / d + 2)
        else
          60 * ((r - g) / d + 4);
      h = if h0 < 0 then h0 + 360 else h0;
      s = if d == 0 then 0.0 else d / (1 - (if 2 * l - 1 < 0 then 1 - 2 * l else 2 * l - 1));
    in
    {
      inherit h s l;
    };

  hueName =
    hex:
    let
      c = hsl hex;
    in
    if c.s < 0.15 then
      "gray"
    else if c.h < 12 || c.h >= 345 then
      "red"
    else if c.h < 35 then
      "orange"
    else if c.h < 58 then
      "yellow"
    else if c.h < 80 then
      (if c.l > 0.65 then "yellow" else "lime")
    else if c.h < 150 then
      "green"
    else if c.h < 200 then
      "cyan"
    else if c.h < 232 then
      "blue"
    else if c.h < 300 then
      "purple"
    else
      "pink";

  base16Accents =
    c:
    let
      slots = map (n: c."base0${n}") [
        "8"
        "9"
        "A"
        "B"
        "C"
        "D"
        "E"
        "F"
      ];
      # The first slot of a hue gets the plain name; later ones become
      # light-<hue> / deep-<hue> (relative to it), or <hue>-2 as a last resort.
      add =
        acc: hex:
        let
          name = hueName hex;
          variant = if (hsl hex).l > (hsl acc.${name}).l then "light-${name}" else "deep-${name}";
          free = n: !(acc ? ${n});
          chosen =
            if free name then
              name
            else if free variant then
              variant
            else
              lib.findFirst free "${name}-x" (map (i: "${name}-${toString i}") (lib.range 2 9));
        in
        acc // { ${chosen} = hex; };
    in
    lib.foldl' add { } (lib.unique slots);
in
{
  inherit base16Accents;

  catppuccin = {
    macchiato = {
      rosewater = "#f4dbd6";
      flamingo = "#f0c6c6";
      pink = "#f5bde6";
      mauve = "#c6a0f6";
      red = "#ed8796";
      maroon = "#ee99a0";
      peach = "#f5a97f";
      yellow = "#eed49f";
      green = "#a6da95";
      teal = "#8bd5ca";
      sky = "#91d7e3";
      sapphire = "#7dc4e4";
      blue = "#8aadf4";
      lavender = "#b7bdf8";
    };
    mocha = {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
    };
    latte = {
      rosewater = "#dc8a78";
      flamingo = "#dd7878";
      pink = "#ea76cb";
      mauve = "#8839ef";
      red = "#d20f39";
      maroon = "#e64553";
      peach = "#fe640b";
      yellow = "#df8e1d";
      green = "#40a02b";
      teal = "#179299";
      sky = "#04a5e5";
      sapphire = "#209fb5";
      blue = "#1e66f5";
      lavender = "#7287fd";
    };
  };
}
