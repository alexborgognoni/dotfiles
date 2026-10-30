"""Add the Latin letters of other keyboard layouts to the emoji picker.

The emoji picker only has emoji and ~360 symbols. This adds the accented and
special letters of Latin-1 Supplement and Latin Extended-A (French, German,
Spanish, Italian, Portuguese, Nordic, Polish, Turkish, ...) and the typographic
marks of those languages to its "chars" category, so that "a umlaut", "e acute",
"sharp s", "german" or "guillemet" find them like any emoji. German and French
come first. Picks land in the picker's own "Frequently Used".

usage: latin-letters.py emoji.json   (rewrites the file)
"""

import json
import sys
import unicodedata as ud

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
have = {entry["e"] for entry in data}

# combining mark -> what people call it
ACCENT = {
    0x0300: ["grave"],
    0x0301: ["acute"],
    0x0302: ["circumflex", "hat"],
    0x0303: ["tilde"],
    0x0304: ["macron"],
    0x0306: ["breve"],
    0x0307: ["dot", "dot above"],
    0x0308: ["diaeresis", "umlaut", "trema"],
    0x030A: ["ring", "ring above"],
    0x030B: ["double acute"],
    0x030C: ["caron", "hacek"],
    0x0327: ["cedilla"],
    0x0328: ["ogonek"],
}

# letters without a decomposition
SPECIAL = {
    "ß": ["sharp s", "eszett", "german s", "double s", "ss"],
    "ẞ": ["capital sharp s", "capital eszett", "sharp s", "eszett"],
    "æ": ["ae", "ae ligature", "ash"],
    "Æ": ["ae", "ae ligature", "ash"],
    "œ": ["oe", "oe ligature"],
    "Œ": ["oe", "oe ligature"],
    "ø": ["o slash", "o stroke"],
    "Ø": ["o slash", "o stroke"],
    "ð": ["eth"],
    "Ð": ["eth"],
    "þ": ["thorn"],
    "Þ": ["thorn"],
    "ł": ["l stroke"],
    "Ł": ["l stroke"],
    "đ": ["d stroke"],
    "Đ": ["d stroke"],
    "ħ": ["h stroke"],
    "Ħ": ["h stroke"],
    "ı": ["dotless i"],
    "ŋ": ["eng"],
    "Ŋ": ["eng"],
    "ĸ": ["kra"],
    "ŧ": ["t stroke"],
    "Ŧ": ["t stroke"],
}

LANGUAGES = {
    "german": "äöüßÄÖÜẞ",
    "french": "àâæçéèêëîïôœùûüÿÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ",
    "spanish": "áéíóúüñÁÉÍÓÚÜÑ",
    "italian": "àèéìíîòóùúÀÈÉÌÍÎÒÓÙÚ",
    "portuguese": "áàâãçéêíóôõúüÁÀÂÃÇÉÊÍÓÔÕÚÜ",
    "nordic": "åäöæøÅÄÖÆØ",
    "polish": "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ",
    "turkish": "çğıöşüÇĞİÖŞÜ",
}

# German spellings without the umlaut
TRANSLITERATION = {"ä": "ae", "ö": "oe", "ü": "ue", "Ä": "ae", "Ö": "oe", "Ü": "ue"}

# what to show first, in this order (lowercase, then capitals)
FIRST = "äöüßéèêëàâçîïôùûÿœæ" + "ÄÖÜẞÉÈÊËÀÂÇÎÏÔÙÛŸŒÆ"

# typographic marks: (char, name, aliases, keywords)
EXTRAS = [
    ("«", "left guillemet", ["guillemet", "guillemets", "left angle quote", "french quote"], ["french", "quote"]),
    ("»", "right guillemet", ["guillemet", "guillemets", "right angle quote", "french quote"], ["french", "quote"]),
    ("‹", "single left guillemet", ["single guillemet", "left single angle quote"], ["french", "quote"]),
    ("›", "single right guillemet", ["single guillemet", "right single angle quote"], ["french", "quote"]),
    ("„", "low double quote", ["german quote", "low quote", "low-9 quote", "gaensefuesschen"], ["german", "quote"]),
    ("“", "left double quote", ["double quote", "curly quote", "smart quote"], ["quote"]),
    ("”", "right double quote", ["double quote", "curly quote", "smart quote"], ["quote"]),
    ("‚", "low single quote", ["german single quote", "low-9 single quote"], ["german", "quote"]),
    ("‘", "left single quote", ["single quote", "curly quote"], ["quote"]),
    ("’", "right single quote", ["apostrophe", "curly apostrophe", "single quote"], ["quote"]),
    ("¿", "inverted question mark", ["spanish question mark"], ["spanish"]),
    ("¡", "inverted exclamation mark", ["spanish exclamation mark"], ["spanish"]),
]


def variants(term):
    return [term, term.replace(" ", "-"), term.replace(" ", "")]


def unique(items):
    seen = []
    for item in items:
        if item and item not in seen:
            seen.append(item)
    return seen


def letter_entry(ch):
    name = ud.name(ch, "")
    for prefix, capital in (
        ("LATIN CAPITAL LETTER ", True),
        ("LATIN SMALL LETTER ", False),
        ("LATIN CAPITAL LIGATURE ", True),
        ("LATIN SMALL LIGATURE ", False),
    ):
        if name.startswith(prefix):
            tail = name[len(prefix):].lower()
            break
    else:
        return None
    label = ("capital " if capital else "") + tail

    aliases = [tail, tail.replace(" with ", " ")]
    keywords = ["letter", "latin"]
    decomposition = ud.decomposition(ch)
    if decomposition and not decomposition.startswith("<"):
        codes = [int(part, 16) for part in decomposition.split()]
        base = chr(codes[0]).lower()
        marks = [ACCENT.get(code) for code in codes[1:]]
        if all(marks):
            keywords.append("accent")
            for term in marks[0]:
                aliases += variants(f"{base} {term}")
            aliases += marks[0]
    aliases += SPECIAL.get(ch, [])
    if ch in SPECIAL:
        keywords.append("ligature" if "ligature" in " ".join(SPECIAL[ch]) else "letter")
    for language, letters in LANGUAGES.items():
        if ch in letters:
            keywords.append(language)
    if ch in TRANSLITERATION:
        keywords.append(TRANSLITERATION[ch])

    return {
        "e": ch,
        "n": label,
        "c": "chars",
        "a": unique(aliases),
        "k": unique(keywords),
        "s": 1,
        "l": label.lower(),
    }


letters = {}
for code in list(range(0x00C0, 0x0180)) + [0x1E9E]:
    entry = letter_entry(chr(code))
    if entry:
        letters[entry["e"]] = entry

first = [letters.pop(ch) for ch in FIRST if ch in letters]
# the rest alphabetically by letter and accent, lowercase before capital
rest = sorted(letters.values(), key=lambda e: (e["n"].removeprefix("capital "), e["n"].startswith("capital ")))

# the plugin already has some of the marks under other names: add ours to them
existing = {entry["e"]: entry for entry in data}
extras = []
for ch, name, aliases, keywords in EXTRAS:
    if ch in existing:
        entry = existing[ch]
        entry["a"] = unique(entry["a"] + [name] + aliases)
        entry["k"] = unique(entry["k"] + keywords)
    else:
        extras.append(
            {
                "e": ch,
                "n": name,
                "c": "chars",
                "a": unique([name] + aliases),
                "k": keywords,
                "s": 1,
                "l": name.lower(),
            }
        )

new = [entry for entry in first + extras + rest if entry["e"] not in have]
at = next(i for i, entry in enumerate(data) if entry["c"] == "chars")
data[at:at] = new

assert len({entry["e"] for entry in data}) == len(data), "duplicate characters"
for ch in "äöüßéèçàÄÖÜœŒ«»„":
    assert any(entry["e"] == ch for entry in data), f"{ch} missing"

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
print(f"latin-letters: added {len(new)} entries ({len(data)} in total)")
