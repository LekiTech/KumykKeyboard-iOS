#!/usr/bin/env python3
"""Letter statistics of Kumyk and a model comparison of layout candidates.

Python 3 standard library only. Reads the shipped words artifact
(KumykKeyboardExtension/kumyk_words.sqlite); the corpus count of a word is
its base_score // 10 (the v0 score is 10 × count + word lists). Writes
docs/layout/analysis.json and prints the same numbers.

    python3 -I scripts/analyze_layout.py [--v0 ../kumyk-dictionary/original-v0]

With --v0 (the folder of the v0 kum_words.tsv) the report also compares the
two corpora behind the counts, the magazine OCR and the newspaper frequency
list, letter by letter.

Everything here is a MODEL of typing, not a measurement of people:

  * a word is typed letter by letter, no suggestion is picked;
  * a letter with its own key costs one tap; a letter without one costs one
    long press on its base key; a long-press option that yields two letters
    («къ») counts as one long press;
  * time = taps × t + long presses × (t + delay), with the keyboard's default
    long-press delay of 0.3 s and two tap rates t (0.25 s and 0.18 s);
  * two thumbs: a key belongs to the thumb of its half of the keyboard, and a
    thumb travels in a straight line from the previous key it pressed in the
    same word. Key centres are those of General Keyboard's native grid on a
    402 pt wide iPhone (content width 395 pt, row pitch 54 pt).
"""

import argparse
import csv
import json
import os
import sqlite3
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORDS = os.path.join(REPO, "KumykKeyboard", "KumykKeyboardExtension", "kumyk_words.sqlite")
OUT = os.path.join(REPO, "docs", "layout", "analysis.json")

DIGRAPHS = ["гъ", "гь", "къ", "нг", "оь", "уь"]
VOWELS = "аеёиоуыэюя"
SCREEN = 402.0            # pt, iPhone 18 Pro and the other 6.3" iPhones
SMALL_SCREEN = 375.0      # pt, the narrowest supported iPhones
PAD, INSET, PITCH = 3.5, 3.0, 54.0
LONG_PRESS_DELAY = 0.3    # s, KeyboardSettings.CalloutDelay.normal
TAP_RATES = {"0.25 s per tap": 0.25, "0.18 s per tap": 0.18}

RUSSIAN = ["йцукенгшщзх", "фывапролджэ", "ячсмитьбю"]

# name → (letter rows, {letter: base key} for letters reached by long press,
#         {two-letter long-press option: base key} used by the model typist)
CANDIDATES = {
    "A0": {
        "title": "Russian iOS keyboard as it is (ъ under ь only)",
        "rows": RUSSIAN,
        "long_press": {"ё": "е", "ъ": "ь"},
        "digraph_options": {},
    },
    "A": {
        "title": "Russian iOS layout, digraphs on long press",
        "rows": RUSSIAN,
        "long_press": {"ё": "е", "ъ": "ь"},
        "digraph_options": {"къ": "к", "гъ": "г"},
    },
    "B": {
        "title": "ъ on щ's key, щ under ш (chosen)",
        "rows": ["йцукенгшъзх", "фывапролджэ", "ячсмитьбю"],
        "long_press": {"ё": "е", "щ": "ш"},
        "digraph_options": {},
    },
    "C1": {
        "title": "Russian layout plus ъ as a 12th top-row key",
        "rows": ["йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю"],
        "long_press": {"ё": "е"},
        "digraph_options": {},
    },
    "C2": {
        "title": "B with ё on ц's key, ц under ч",
        "rows": ["йёукенгшъзх", "фывапролджэ", "ячсмитьбю"],
        "long_press": {"ц": "ч", "щ": "ш"},
        "digraph_options": {},
    },
}


def load():
    con = sqlite3.connect(f"file:{WORDS}?mode=ro", uri=True)
    rows = [(w, s // 10) for w, s in con.execute("SELECT word, base_score FROM words") if s >= 10]
    meta = dict(con.execute("SELECT key, value FROM meta"))
    con.close()
    return rows, meta


def units(word):
    """The word as alphabet letters: the six digraphs are one letter each."""
    out, i = [], 0
    while i < len(word):
        if word[i:i + 2] in DIGRAPHS:
            out.append(word[i:i + 2])
            i += 2
        else:
            out.append(word[i])
            i += 1
    return out


def pct(n, total):
    return round(100.0 * n / total, 3)


# ----------------------------------------------------------------- statistics
def statistics(rows):
    chars, letters, pairs, lengths = Counter(), Counter(), Counter(), Counter()
    before_hard, before_soft = Counter(), Counter()
    position = {d: Counter() for d in ("оь", "уь", "ё", "ю", "э")}
    tokens = 0
    for word, n in rows:
        tokens += n
        lengths[len(word)] += n
        for ch in word:
            if ch != "-":
                chars[ch] += n
        for u in units(word):
            if u != "-":
                letters[u] += n
        for a, b in zip(word, word[1:]):
            if a != "-" and b != "-":
                pairs[a + b] += n
        for i, ch in enumerate(word):
            if ch == "ъ":
                before_hard[word[i - 1] if i else "^"] += n
            if ch == "ь":
                before_soft[word[i - 1] if i else "^"] += n
        for d, c in position.items():
            start = word.find(d)
            while start != -1:
                prev = word[start - 1] if start else ""
                c["word-initial" if not prev or prev == "-" else
                  "after a vowel" if prev in VOWELS else "after a consonant or sign"] += n
                start = word.find(d, start + 1)
    total_chars, total_letters = sum(chars.values()), sum(letters.values())
    hard, soft = chars["ъ"], chars["ь"]
    return {
        "word_types": len(rows),
        "word_tokens": tokens,
        "characters": total_chars,
        "mean_word_length": round(sum(k * v for k, v in lengths.items()) / tokens, 2),
        "word_length_percent": {str(k): pct(lengths[k], tokens) for k in sorted(lengths) if k <= 16},
        "character_percent": {ch: pct(n, total_chars) for ch, n in chars.most_common()},
        "alphabet_letter_percent": {u: pct(n, total_letters) for u, n in letters.most_common()},
        "digraph_percent_of_letters": {d: pct(letters[d], total_letters) for d in DIGRAPHS},
        "digraphs_together_percent_of_letters": pct(sum(letters[d] for d in DIGRAPHS), total_letters),
        "hard_sign": {
            "percent_of_characters": pct(hard, total_chars),
            "rank_among_characters": [ch for ch, _ in chars.most_common()].index("ъ") + 1,
            "after_percent": {k: pct(v, hard) for k, v in before_hard.most_common(6)},
            "share_of_к_followed_by_ъ": pct(before_hard["к"], chars["к"]),
            "share_of_г_followed_by_ъ": pct(before_hard["г"], chars["г"]),
        },
        "soft_sign": {
            "percent_of_characters": pct(soft, total_chars),
            "after_percent": {k: pct(v, soft) for k, v in before_soft.most_common(8)},
            "share_of_г_followed_by_ь": pct(before_soft["г"], chars["г"]),
        },
        "front_vowel_spelling_tokens": {d: dict(c.most_common()) for d, c in position.items()},
        "rare_letters_percent_of_characters": {ch: pct(chars[ch], total_chars) for ch in "щфцжхёэ"},
        "top_character_pairs_percent": {p: pct(n, sum(pairs.values())) for p, n in pairs.most_common(30)},
    }


def per_source(v0):
    """Character shares in each of the two corpora, from the v0 TSV."""
    counts = {"magazine_ocr": Counter(), "newspaper_frequency_list": Counter()}
    with open(os.path.join(v0, "kum_words.tsv"), encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            for name, column in (("magazine_ocr", "ocr_count"), ("newspaper_frequency_list", "extra_count")):
                n = int(r[column])
                if n:
                    for ch in r["word"]:
                        if ch != "-":
                            counts[name][ch] += n
    out = {}
    for name, c in counts.items():
        total = sum(c.values())
        out[name] = {"characters": total,
                     "top_12": "".join(ch for ch, _ in c.most_common(12)),
                     "percent": {ch: pct(c[ch], total) for ch in "ъьёюыэхжцфщ"}}
    return out


# ----------------------------------------------------------------- the typing model
def geometry(rows, screen):
    """Key centres (pt) of the native grid: equal cells in every row; the
    third row has shift and backspace cells around its letters."""
    content = screen - 2 * PAD
    centres = {}
    for r, row in enumerate(rows):
        cells = len(row) + (2 if r == 2 else 0)
        for i, ch in enumerate(row):
            column = i + (1 if r == 2 else 0)
            centres[ch] = (PAD + (column + 0.5) * content / cells, r * PITCH)
    return centres


def key_width(row_length, screen):
    return round((screen - 2 * PAD) / row_length - 2 * INSET, 2)


def keystrokes(word, cand):
    """[(key, is_long_press)] for one word; hyphens are skipped."""
    on_keys = set("".join(cand["rows"]))
    out, i = [], 0
    while i < len(word):
        ch = word[i]
        if ch == "-":
            i += 1
            continue
        pair = word[i:i + 2]
        # A letter without a key that a two-letter option produces together
        # with its base letter: one long press for both.
        if pair in cand["digraph_options"] and pair[1] not in on_keys:
            out.append((cand["digraph_options"][pair], True))
            i += 2
            continue
        if ch in on_keys:
            out.append((ch, False))
        else:
            out.append((cand["long_press"][ch], True))
        i += 1
    return out


def evaluate(rows, cand):
    centres = geometry(cand["rows"], SCREEN)
    taps = long_presses = tokens = chars = words_with_lp = 0
    travel = same_thumb = transitions = 0.0
    for word, n in rows:
        strokes = keystrokes(word, cand)
        lp = sum(1 for _, held in strokes if held)
        tokens += n
        chars += n * sum(1 for ch in word if ch != "-")
        taps += n * (len(strokes) - lp)
        long_presses += n * lp
        words_with_lp += n if lp else 0
        last = {}
        previous_thumb = None
        for key, _ in strokes:
            x, y = centres[key]
            thumb = "left" if x < SCREEN / 2 else "right"
            if thumb in last:
                px, py = last[thumb]
                travel += n * ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            if previous_thumb is not None:
                transitions += n
                same_thumb += n if previous_thumb == thumb else 0
            last[thumb] = (x, y)
            previous_thumb = thumb
    result = {
        "title": cand["title"],
        "rows": cand["rows"],
        "keys_per_row": [len(r) for r in cand["rows"]],
        "narrowest_letter_key_pt": {f"{int(SCREEN)} pt screen": key_width(max(map(len, cand["rows"][:2])), SCREEN),
                                    f"{int(SMALL_SCREEN)} pt screen": key_width(max(map(len, cand["rows"][:2])),
                                                                                SMALL_SCREEN)},
        "key_presses_per_word": round((taps + long_presses) / tokens, 3),
        "taps_per_word": round(taps / tokens, 3),
        "long_presses_per_100_words": round(100.0 * long_presses / tokens, 2),
        "long_presses_per_100_characters": round(100.0 * long_presses / chars, 3),
        "words_needing_a_long_press_percent": pct(words_with_lp, tokens),
        "thumb_travel_pt_per_character": round(travel / chars, 2),
        "same_thumb_transitions_percent": pct(same_thumb, transitions),
        "seconds_per_100_words": {
            name: round(100.0 * (taps * t + long_presses * (t + LONG_PRESS_DELAY)) / tokens, 1)
            for name, t in TAP_RATES.items()},
        "letters_moved_from_the_russian_layout": sorted(
            ch for ch in "".join(RUSSIAN)
            if geometry(RUSSIAN, SCREEN)[ch] != centres.get(ch)),
        "letters_without_a_key": sorted(cand["long_press"]),
    }
    return result


def digraph_paths(cand):
    on_keys = set("".join(cand["rows"]))
    centres = geometry(cand["rows"], SCREEN)
    out = {}
    for d in DIGRAPHS:
        if all(ch in on_keys for ch in d):
            (x1, y1), (x2, y2) = centres[d[0]], centres[d[1]]
            thumbs = ["left" if x < SCREEN / 2 else "right" for x in (x1, x2)]
            out[d] = (f"2 taps, {'alternating thumbs' if thumbs[0] != thumbs[1] else 'same thumb'}, "
                      f"{round(((x1 - x2) ** 2 + (y1 - y2) ** 2) ** 0.5)} pt apart")
        else:
            out[d] = f"long press on {d[0]}"
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--v0", help="folder with the v0 kum_words.tsv, for the per-corpus comparison")
    args = ap.parse_args()
    rows, meta = load()
    stats = statistics(rows)
    if args.v0:
        stats["per_corpus"] = per_source(args.v0)
    report = {
        "source": {"artifact": "kumyk_words.sqlite", "content_version": meta.get("content_version"),
                   "cleanup_version": meta.get("cleanup_version"),
                   "note": "token-weighted; corpus count of a word = base_score // 10; "
                           "words known only from a word list (count 0) are left out"},
        "statistics": stats,
        "model": {"screen_pt": SCREEN, "long_press_delay_s": LONG_PRESS_DELAY, "tap_rates_s": TAP_RATES,
                  "note": "model-based estimates, not measured typing speed"},
        "candidates": {},
    }
    for name, cand in CANDIDATES.items():
        result = evaluate(rows, cand)
        result["digraph_entry"] = digraph_paths(cand)
        report["candidates"][name] = result
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
