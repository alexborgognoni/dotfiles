#!/usr/bin/env bash
# The committed wallpapers (nix/assets/wallpapers): every image is documented in
# SOURCES.md, a real jpg/png (not an error page saved under an image name), and
# in a folder named after a theme of the catalogue (a typo would silently drop
# the pictures). Sizes are not limited.
# shellcheck source=framework.sh
. "$(dirname "$0")/framework.sh"

dir="$repo/nix/assets/wallpapers"
sources="$dir/SOURCES.md"
catalogue="$repo/nix/themes/catalogue.nix"
legacy="artificial-valley.jpg astronaut.png catppuccin-spiderman.png" # predate SOURCES.md

[ -f "$sources" ] && ok || fail "SOURCES.md is missing"

themes="$(grep -oE '^  [a-z][a-z0-9-]*' "$catalogue" | tr -d ' ' | sort -u)"
assert_match "$(echo "$themes" | paste -sd' ')" "catppuccin-macchiato" "found the theme names in the catalogue"

# --- every image: format, size, location ---------------------------------
count=0
while IFS= read -r f; do
  rel="${f#"$dir"/}"
  count=$((count + 1))
  size="$(stat -c %s "$f")"

  case "$rel" in
    *.jpg | *.png) ok ;;
    *) fail "$rel: only .jpg and .png are allowed (convert it)" ;;
  esac

  magic="$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')"
  case "$rel" in
    *.jpg) assert_match "$magic" "^ffd8ff" "$rel is a JPEG" ;;
    *.png) assert_eq "$magic" "89504e47" "$rel is a PNG" ;;
  esac

  # (flat graphics and gradients are legitimately small; an error page is a few bytes)
  [ "$size" -gt 2000 ] && ok || fail "$rel: suspiciously small ($size bytes): a failed download?"

  case "$rel" in
    themes/*/*)
      theme="${rel#themes/}"
      theme="${theme%%/*}"
      if echo "$themes" | grep -qx -- "$theme"; then ok; else fail "$rel: '$theme' is not a theme in catalogue.nix"; fi
      ;;
    */*) fail "$rel: images go in assets/wallpapers/ or assets/wallpapers/themes/<theme>/" ;;
  esac

  if command -v identify >/dev/null 2>&1; then
    dims="$(identify -format '%w %h' "${f}[0]" 2>/dev/null || echo "0 0")"
    w="${dims% *}"
    h="${dims#* }"
    if [ "$w" -ge 1280 ] && [ "$h" -ge 720 ]; then ok; else fail "$rel: ${w}x${h} is not a readable image of at least 1280x720"; fi
  fi

  # documented, unless it predates SOURCES.md
  name="$(basename "$f")"
  folder="${rel%/*}"
  [ "$folder" = "$rel" ] && folder="shared (recolored per theme)"
  case " $legacy " in
    *" $name "*) [ "$folder" = "shared (recolored per theme)" ] && continue ;;
  esac
  if grep -qF "| $folder | $name |" "$sources"; then ok; else fail "$rel: not listed in SOURCES.md"; fi
done < <(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' \) | sort)

[ "$count" -gt 40 ] && ok || fail "only $count images found"

# --- nothing else is hiding in the folder ---------------------------------
stray="$(find "$dir" -type f ! -iname '*.jpg' ! -iname '*.png' ! -name 'SOURCES.md' | head -5)"
assert_eq "$stray" "" "only images and SOURCES.md live in assets/wallpapers"

# --- SOURCES.md: every row points at a file, and states source and licence ----
rows=0
while IFS='|' read -r _ folder file source upstream _; do
  folder="$(echo "$folder" | sed 's/^ *//; s/ *$//')"
  file="$(echo "$file" | sed 's/^ *//; s/ *$//')"
  source="$(echo "$source" | sed 's/^ *//; s/ *$//')"
  upstream="$(echo "$upstream" | sed 's/^ *//; s/ *$//')"
  case "$folder" in "Theme folder" | ---*) continue ;; esac
  [ -n "$file" ] || continue
  rows=$((rows + 1))
  if [ "$folder" = "shared (recolored per theme)" ]; then path="$dir/$file"; else path="$dir/$folder/$file"; fi
  if [ -f "$path" ]; then ok; else fail "SOURCES.md lists $folder/$file, which does not exist"; fi
  assert_match "$source" "\(([A-Za-z0-9. -]*(MIT|CC0|Unlicense|BSD|Apache|CC BY)[A-Za-z0-9. -]*)\)" "$file: the source states a licence"
  [ -n "$upstream" ] && ok || fail "$file: no upstream path"
done <"$sources"
[ "$rows" -gt 40 ] && ok || fail "SOURCES.md has only $rows rows"

# --- the same picture twice under different names in one folder -------------
for d in "$dir" "$dir"/themes/*/; do
  dups="$(find "$d" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' \) -exec sha256sum {} + | sort | uniq -w64 -d | head -3)"
  assert_eq "$dups" "" "no duplicate images in ${d#"$dir"}"
done

finish
