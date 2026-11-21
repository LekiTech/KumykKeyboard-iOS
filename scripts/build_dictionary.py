#!/usr/bin/env python3
"""Build the Kumyk keyboard dictionary from the v0 data (cleanup version 1).

Deterministic, Python 3 standard library only. Reads (never writes) the five
v0 Kumyk files from keyboard_data_v0.zip, checked against pinned SHA-256
sums:

    kum_words.sqlite  kum_bigrams.sqlite  kum_words.tsv  kum_bigrams.tsv  kum_stats.json

Writes:

    <out>/kumyk_words.sqlite       words(word, base_score) + meta   (General Keyboard artifact)
    <out>/kumyk_bigrams.sqlite     bigrams(prev, word, weight) + meta
    <review>/corrections.csv       every merge the build made
    <review>/flagged.csv           entries kept unchanged but listed for a linguistic review
    <review>/summary.json          counts of the audit, the merges and the flags

Usage, from the repository root (General Keyboard layout: the v0 files sit in
../kumyk-dictionary/original-v0 next to this repository):

    python3 -I scripts/build_dictionary.py               # build + validate
    python3 -I scripts/build_dictionary.py --validate    # validate the shipped artifacts only
    python3 -I scripts/build_dictionary.py --source DIR --out DIR --review DIR

Set SOURCE_DATE_EPOCH to make meta.generated_at (and so the sqlite bytes)
reproducible; the rows are identical on every run regardless.

The rules are documented in docs/DICTIONARY.md. In short:

  * The words are already in the canonical form of the keyboard's
    normalization profile `kumyk-cyrillic` v1 (NFC, lowercase, Latin
    homoglyphs repaired, no palochka); the build re-checks it with a mirror
    of General Keyboard's Normalization.swift and refuses anything else.
  * Three mechanical artifacts are merged into the attested word they stand
    for, never into a new spelling:
      S1  «кь» for «къ»: Kumyk has no «кь»; the magazine OCR read ъ as ь
          ("халкь" → "халкъ");
      S2  two signs in a row ("кьъаршы" → "къаршы"), which no Kumyk spelling has;
      H1  a hyphen stripped by the LingConLab frequency list, which never
          keeps hyphens ("айрыайры" → "айры-айры").
    A merge needs a source row that no word list knows and a repaired form
    that is itself a row of the v0 data; S1/S2 also need the repaired form
    to be at least as frequent, H1 needs the hyphenated spelling to be at
    least five times as common in the running text (the OCR corpus) as the
    joined one. Counts and bigram weights are added; nothing else moves.
  * Nothing is deleted and nothing else is respelled. Every other doubtful
    entry stays as it is and is written to flagged.csv for a Kumyk speaker.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCE = os.path.join(os.path.dirname(REPO), "kumyk-dictionary", "original-v0")
DEFAULT_OUT = os.path.join(REPO, "KumykKeyboard", "KumykKeyboardExtension")
DEFAULT_REVIEW = os.path.join(REPO, "docs", "dictionary", "review")

# keyboard_data_v0.zip (sha256 8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31),
# folder keyboard_data/, built 2026-10-11.
V0_SHA256 = {
    "kum_words.sqlite": "e9f0495dac7a6f857a8049ad05cb5e3924e7908fd7448ee8a31c33fe53addc5a",
    "kum_bigrams.sqlite": "b924c0c1696da39ff28ed15f1d7d232f73ab25cec020eabc79ece02524409c2f",
    "kum_words.tsv": "39474e97a5e7de4dfcbca0b0fb0604140f203aed13fd6c3f52c3629e6db84582",
    "kum_bigrams.tsv": "b8b5ae420399c976ef369e0c566b948871c04d35c598b797f787dede36d016bf",
    "kum_stats.json": "0b274275d88b37b80ef8bd4d55ca3b94c1d175698f9ae68994d6d5389693df77",
}

WORDS_ARTIFACT = "kumyk_words"
BIGRAMS_ARTIFACT = "kumyk_bigrams"
SCHEMA_VERSION = 1
CONTENT_VERSION = 1
NORMALIZATION_PROFILE = "kumyk-cyrillic"   # KumykDefinition.swift, NormalizationProfile.id
NORMALIZATION_VERSION = 1
MIN_READER_SCHEMA = 1
CLEANUP_VERSION = 1

# The CREATE statements of the v0 files, which are the General Keyboard
# artifact shape (docs/engine/ARTIFACT_CONTRACT.md §1). The build checks that
# the v0 files carry exactly these and writes them unchanged.
WORDS_SQL = "CREATE TABLE words(word TEXT PRIMARY KEY, base_score INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID"
BIGRAMS_SQL = ("CREATE TABLE bigrams(prev TEXT NOT NULL, word TEXT NOT NULL, weight INTEGER NOT NULL, "
               "PRIMARY KEY(prev, word)) WITHOUT ROWID")
META_SQL = "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)"

# v0 recorded only the two corpora in meta.sources although its builder also
# counted two word lists (build_kb_data.py, build_lang("kum")); all four are
# named here.
SOURCES = {
    "zhd_ocr_kumyk": "Женщина Дагестана 2016–2023, Kumyk edition, OCR (LingConLab parallel corpus); "
                     "the only running text: every bigram comes from it",
    "lingconlab_freq": "LingConLab frequency list, Kumyk rows (newspaper Ёлдаш, yoldash.ru, and Тангчолпан 2013); "
                       "word counts only, hyphens not kept",
    "apertium_kum": "Apertium Kumyk lexicon kum.lexc (word list)",
    "ids": "Intercontinental Dictionary Series, CLDF, Kumyk (word list)",
}

VOWELS = "аеёиоуыэюя"
CONSONANTS = "бвгджзйклмнпрстфхцчшщ"
SIGNS = "ъь"
ALPHABET_RE = re.compile(r"[а-яё]+(?:-[а-яё]+)*")
HIGH_PRIORITY_COUNT = 20     # a flagged word this frequent shows up in everyday suggestions
HYPHEN_RATIO = 5             # H1: hyphenated spelling this many times as common in running text
SUSPECT_RATIO = 10           # flags: the attested alternative is this many times as frequent

# ----------------------------------------------------------------- the GK contract
# Mirror of GeneralKeyboard's Normalization.swift with the Kumyk profile of
# KumykDefinition.swift (no palochka, the twelve Latin homoglyphs, digraph
# tails ъ ь). Used only to CHECK the rows.
_SWIFT_WHITESPACE = "\t\n\x0b\x0c\r\x85" + "".join(
    chr(cp) for cp in range(0x110000) if unicodedata.category(chr(cp)) in ("Zs", "Zl", "Zp"))
_HOMOGLYPHS = {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
               "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н"}
_TAILS = {"ь", "ъ"}
_PALOCHKAS = {"Ӏ", "ӏ"}   # never part of Kumyk


def canonical(token):
    t = unicodedata.normalize("NFC", token).strip(_SWIFT_WHITESPACE).lower()
    if any(0x0400 <= ord(ch) <= 0x04FF for ch in t):
        t = "".join(_HOMOGLYPHS.get(ch, ch) for ch in t)
    return unicodedata.normalize("NFC", t)


def letter_count(token):
    return sum(0 if ch in _TAILS else 1 for ch in token)


def is_valid_token(token):
    """Normalization.isValidToken for a canonical token."""
    if not token or len(token) > 64:
        return False
    if any(ch.isspace() or ch.isdigit() for ch in token) or any(ch in token for ch in "@/."):
        return False
    if any(ch.isascii() and ch.isalpha() for ch in token):
        return False
    if any(unicodedata.category(ch) in ("Cc", "Cf") for ch in token):
        return False
    return letter_count(token) >= 2


# ----------------------------------------------------------------- input
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def ro(path):
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def table_sql(con):
    return {name: sql for name, sql in con.execute("SELECT name, sql FROM sqlite_master WHERE type='table'")}


class Fail(Exception):
    pass


def load(source):
    for name, digest in V0_SHA256.items():
        path = os.path.join(source, name)
        if not os.path.exists(path):
            raise Fail(f"missing v0 file {path}")
        if sha256(path) != digest:
            raise Fail(f"{name}: SHA-256 differs from the pinned v0 file")

    wc, bc = ro(os.path.join(source, "kum_words.sqlite")), ro(os.path.join(source, "kum_bigrams.sqlite"))
    if table_sql(wc) != {"words": WORDS_SQL, "meta": META_SQL}:
        raise Fail("kum_words.sqlite: unexpected schema")
    if table_sql(bc) != {"bigrams": BIGRAMS_SQL, "meta": META_SQL}:
        raise Fail("kum_bigrams.sqlite: unexpected schema")
    sqlite_words = dict(wc.execute("SELECT word, base_score FROM words"))
    sqlite_pairs = {(a, b): w for a, b, w in bc.execute("SELECT prev, word, weight FROM bigrams")}
    v0_meta = dict(wc.execute("SELECT key, value FROM meta"))
    wc.close()
    bc.close()

    words = {}
    with open(os.path.join(source, "kum_words.tsv"), encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            words[r["word"]] = {
                "score": int(r["base_score"]), "count": int(r["count"]), "clean": int(r["clean_count"]),
                "ocr": int(r["ocr_count"]), "extra": int(r["extra_count"]), "lex": int(r["lexicon_sources"]),
            }
    if {w: r["score"] for w, r in words.items()} != sqlite_words:
        raise Fail("kum_words.tsv and kum_words.sqlite disagree")
    with open(os.path.join(source, "kum_bigrams.tsv"), encoding="utf-8", newline="") as f:
        tsv_pairs = {(r["prev"], r["word"]): int(r["weight"]) for r in csv.DictReader(f, delimiter="\t")}
    if tsv_pairs != sqlite_pairs:
        raise Fail("kum_bigrams.tsv and kum_bigrams.sqlite disagree")
    with open(os.path.join(source, "kum_stats.json"), encoding="utf-8") as f:
        stats = json.load(f)
    return words, sqlite_pairs, v0_meta, stats


def v0_score(rec):
    """base_score of the v0 builder: 10 × corpus count + min(9, word lists)."""
    return 10 * rec["count"] + min(9, rec["lex"])


# ----------------------------------------------------------------- audit
def audit(words, pairs):
    inventory = Counter()
    for w in words:
        inventory.update(w)
    canon_groups = defaultdict(list)
    for w in words:
        canon_groups[canonical(w)].append(w)
    mix = Counter()
    for r in words.values():
        mix[" + ".join(k for k, on in (("word list", r["lex"]), ("ocr", r["ocr"]), ("frequency list", r["extra"]))
                       if on)] += 1
    return {
        "words": len(words),
        "bigrams": len(pairs),
        "character_inventory": {f"{ch} U+{ord(ch):04X}": n for ch, n in
                                sorted(inventory.items(), key=lambda kv: (-kv[1], kv[0]))},
        "not_nfc": sorted(w for w in words if unicodedata.normalize("NFC", w) != w),
        "not_lowercase": sorted(w for w in words if w != w.lower()),
        "not_canonical": sorted(w for w in words if canonical(w) != w),
        "canonical_collisions": sorted(ws for ws in canon_groups.values() if len(ws) > 1),
        "contract_invalid": sorted(w for w in words if not is_valid_token(w)),
        "outside_alphabet": sorted(w for w in words if not ALPHABET_RE.fullmatch(w)),
        "latin_letters": sorted(w for w in words if any(ch.isascii() and ch.isalpha() for ch in w)),
        "palochka": sorted(w for w in words if any(ch in _PALOCHKAS for ch in w)),
        "replacement_or_control_chars": sorted(
            w for w in words if any(ch == "�" or unicodedata.category(ch) in ("Cc", "Cf", "Co", "Cs")
                                    for ch in w)),
        "hyphenated": sum(1 for w in words if "-" in w),
        "hyphenated_with_a_frequency_list_count": sum(1 for w, r in words.items() if "-" in w and r["extra"]),
        "score_formula_mismatch": sorted(w for w, r in words.items() if r["score"] != v0_score(r)),
        "count_mismatch": sorted(w for w, r in words.items()
                                 if r["count"] != r["clean"] + r["ocr"] + r["extra"]),
        "source_mix": dict(sorted(mix.items(), key=lambda kv: -kv[1])),
        "in_word_lists": sum(1 for r in words.values() if r["lex"] > 0),
        "word_lists_only": sum(1 for r in words.values() if r["lex"] > 0 and r["count"] == 0),
        "ocr_only": sum(1 for r in words.values() if r["lex"] == 0 and r["extra"] == 0),
        "ocr_only_count_3_or_4": sum(1 for r in words.values()
                                     if r["lex"] == 0 and r["extra"] == 0 and 3 <= r["ocr"] <= 4),
        "corpus_tokens": {"ocr": sum(r["ocr"] for r in words.values()),
                          "frequency_list": sum(r["extra"] for r in words.values())},
        "bigram_orphans": sum(1 for a, b in pairs if a not in words or b not in words),
        "bigram_weight_below_2": sum(1 for v in pairs.values() if v < 2),
        "bigram_self_pairs": sorted(f"{a} {b}" for a, b in pairs if a == b),
    }


# ----------------------------------------------------------------- merges
SIGN_RUN = re.compile(f"[{SIGNS}]{{2,}}")


def sign_repairs(word):
    """(rule, [repaired forms]) for the two OCR sign artifacts, or None.

    S2: a run of two or more signs is one sign: ъ after к (Kumyk has no «кь»),
    otherwise ъ or ь, whichever the data attests. S1: «кь» is «къ».
    """
    runs = list(SIGN_RUN.finditer(word))
    if len(runs) > 1:
        return "S2 two signs in a row", []
    if runs:
        m = runs[0]
        after_k = m.start() > 0 and word[m.start() - 1] == "к"
        forms = [word[:m.start()] + s + word[m.end():] for s in ("ъ" if after_k else SIGNS)]
        return "S2 two signs in a row", sorted({f.replace("кь", "къ") for f in forms})
    if "кь" in word:
        return "S1 «кь» for «къ»", [word.replace("кь", "къ")]
    return None


def plan_merges(words):
    merges, blocked = {}, {}

    # S1, S2: OCR sign artifacts
    for w, r in sorted(words.items()):
        hit = sign_repairs(w)
        if not hit:
            continue
        rule, forms = hit
        attested = [f for f in forms if f in words and not sign_repairs(f)]
        shown = " / ".join(forms) or "?"
        if r["lex"]:
            blocked[w] = (rule, shown, "source is in a word list")
        elif not attested:
            blocked[w] = (rule, shown, "repaired form is not attested in the data")
        elif len(attested) > 1:
            blocked[w] = (rule, shown, "two attested readings: " + ", ".join(
                f"{f} ({words[f]['count']})" for f in attested))
        elif words[attested[0]]["count"] < r["count"]:
            blocked[w] = (rule, shown, "repaired form is less frequent")
        else:
            merges[w] = (rule, attested[0])

    # H1: the frequency list strips hyphens
    rule = "H1 hyphen stripped by the frequency list"
    joined = defaultdict(list)
    for w in words:
        if "-" in w:
            joined[w.replace("-", "")].append(w)
    for j, hyphenated in sorted(joined.items()):
        if j not in words or j in merges or j in blocked:
            continue
        r = words[j]
        shown = " / ".join(sorted(hyphenated))
        if r["lex"]:
            blocked[j] = (rule, shown, "joined form is in a word list")
        elif len(hyphenated) > 1:
            blocked[j] = (rule, shown, "two hyphenated spellings")
        elif hyphenated[0] in merges or hyphenated[0] in blocked:
            blocked[j] = (rule, shown, "hyphenated form carries an artifact itself")
        elif words[hyphenated[0]]["ocr"] < HYPHEN_RATIO * r["ocr"]:
            h = words[hyphenated[0]]
            blocked[j] = (rule, shown, f"running text: joined {r['ocr']}, hyphenated {h['ocr']} "
                                       f"(needs {HYPHEN_RATIO}×)")
        else:
            merges[j] = (rule, hyphenated[0])
    return merges, blocked


def apply_merges(words, pairs, merges):
    final = {w: dict(r) for w, r in words.items() if w not in merges}
    for src, (_, dst) in merges.items():
        s, t = words[src], final[dst]
        for k in ("count", "clean", "ocr", "extra"):
            t[k] += s[k]
    for w in {dst for _, dst in merges.values()}:
        final[w]["score"] = v0_score(final[w])
    out = Counter()
    remapped = 0
    for (a, b), v in pairs.items():
        na, nb = merges.get(a, (None, a))[1], merges.get(b, (None, b))[1]
        remapped += (na, nb) != (a, b)
        out[(na, nb)] += v
    return final, dict(out), remapped


# ----------------------------------------------------------------- flags
def flag_entries(final, pairs, blocked):
    """Entries kept unchanged and listed for review: {word: [(category, note)]}."""
    flags = defaultdict(list)

    def count(w):
        return final[w]["count"] if w in final else 0

    def attested(form):
        return f"{form} ({count(form)})"

    def much_more_frequent(alt, w):
        return alt in final and count(alt) >= SUSPECT_RATIO * max(1, count(w))

    # A token that spells an attested word pair without the space. Short
    # second words are left out: the particles да, де are also the locative
    # suffixes -да, -де («менде», «яшларда» are ordinary word forms).
    glued = {}
    for (a, b), weight in pairs.items():
        if weight >= 10 and letter_count(a) >= 3 and letter_count(b) >= 3:
            glued.setdefault(a + b, (a, b, weight))

    for w, r in final.items():
        unlisted = r["lex"] == 0
        if unlisted:
            # ъ and ь confused after г: both «гъ» and «гь» are letters, so this
            # is a question for a speaker, not a mechanical repair.
            for a, b in (("гь", "гъ"), ("гъ", "гь")):
                alts = [w[:m.start()] + b + w[m.end():] for m in re.finditer(a, w)]
                alts = [alt for alt in alts if much_more_frequent(alt, w)]
                if alts:
                    flags[w].append((f"«{a}» where «{b}» is far more frequent",
                                     "possibly ъ and ь confused; attested: " + attested(alts[0])))
                    break
            for i, ch in enumerate(w):
                if ch in "гк" and (i + 1 == len(w) or w[i + 1] not in SIGNS):
                    alt = w[:i + 1] + "ъ" + w[i + 1:]
                    if much_more_frequent(alt, w):
                        flags[w].append(("possibly lost ъ", "attested with ъ: " + attested(alt)))
                        break
            if "е" in w:
                alts = [w[:m.start()] + "ё" + w[m.end():] for m in re.finditer("е", w)]
                alts = [alt for alt in alts if much_more_frequent(alt, w)]
                if alts:
                    flags[w].append(("possibly ё written as е", "attested with ё: " + attested(alts[0])))
            if "ть" in w:
                alt = w.replace("ть", "гь")
                if much_more_frequent(alt, w):
                    flags[w].append(("possibly «гь» read as «ть»", "attested with гь: " + attested(alt)))
            if w in glued and count(w) <= glued[w][2]:
                a, b, weight = glued[w]
                flags[w].append(("possibly two words glued", f"attested word pair: {a} {b} ({weight})"))
            if len(w) == 2:
                flags[w].append(("two-letter token outside the word lists",
                                 "suffix written after a numeral or an abbreviation, interjection or noise"))
        if re.search(f"[{CONSONANTS}{SIGNS}]э", w):
            flags[w].append(("э after a consonant", "Kumyk writes э word-initially: glued words, an "
                                                    "abbreviation or a loan"))
        if re.search(r"(?<!^)(?<!-)[оу]ь", w):
            flags[w].append(("оь or уь inside a word", "Kumyk writes оь and уь word-initially: possibly glued words"))
        if not any(ch in VOWELS for ch in w):
            flags[w].append(("no vowel", "abbreviation or noise"))
        if re.search(r"(.)\1\1", w):
            flags[w].append(("same letter three times", "abbreviation, interjection or noise"))
        if len(w) >= 20:
            flags[w].append(("very long token", "possibly glued words"))
        if "-" in w and any(letter_count(p) < 2 for p in w.split("-")):
            flags[w].append(("hyphen part shorter than 2 letters", "abbreviation or broken hyphenation"))
        if w[0] in SIGNS:
            flags[w].append(("word starts with ь or ъ", "possibly OCR"))
        if w.startswith("гъ") and unlisted:
            flags[w].append(("word starts with гъ", "Kumyk words do not begin with гъ: a suffix written apart "
                                                    "(-гъа, -гъан), a name or гь read as гъ"))
    for w, (rule, repaired, why) in blocked.items():
        if w in final:
            flags[w].append((f"not merged ({rule.split()[0]})", f"{why}; repaired form would be {repaired}"))
    return flags


# ----------------------------------------------------------------- output
def generated_at():
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    t = datetime.fromtimestamp(int(epoch), timezone.utc) if epoch else datetime.now(timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def write_artifacts(out, final, pairs):
    os.makedirs(out, exist_ok=True)
    common = [
        ("schema_version", str(SCHEMA_VERSION)), ("content_version", str(CONTENT_VERSION)),
        ("normalization_version", str(NORMALIZATION_VERSION)), ("normalization_profile", NORMALIZATION_PROFILE),
        ("min_reader_schema", str(MIN_READER_SCHEMA)), ("cleanup_version", str(CLEANUP_VERSION)),
        ("generated_at", generated_at()), ("language", "kum"),
        ("sources", json.dumps(SOURCES, ensure_ascii=False, sort_keys=True)),
    ]
    specs = [
        (WORDS_ARTIFACT, WORDS_SQL, "INSERT INTO words(word, base_score) VALUES(?, ?)",
         sorted((w, r["score"]) for w, r in final.items()), ["kum_words.sqlite", "kum_words.tsv"]),
        (BIGRAMS_ARTIFACT, BIGRAMS_SQL, "INSERT INTO bigrams(prev, word, weight) VALUES(?, ?, ?)",
         sorted((a, b, v) for (a, b), v in pairs.items()), ["kum_bigrams.sqlite", "kum_bigrams.tsv", "kum_words.tsv"]),
    ]
    for artifact, create, insert, rows, inputs in specs:
        path = os.path.join(out, artifact + ".sqlite")
        tmp = path + ".tmp"
        if os.path.exists(tmp):
            os.remove(tmp)
        con = sqlite3.connect(tmp)
        con.execute("PRAGMA page_size = 4096")
        con.execute(create)
        con.execute(META_SQL)
        con.executemany(insert, rows)
        derived = json.dumps({n: V0_SHA256[n] for n in inputs}, sort_keys=True)
        meta = [("artifact", artifact)] + common + [("row_count", str(len(rows))), ("derived_from", derived)]
        con.executemany("INSERT INTO meta(key, value) VALUES(?, ?)", sorted(meta))
        con.commit()
        con.execute("VACUUM")
        con.close()
        os.replace(tmp, path)


def write_reviews(review, words, final, merges, flags, summary):
    os.makedirs(review, exist_ok=True)
    with open(os.path.join(review, "corrections.csv"), "w", encoding="utf-8", newline="") as f:
        wr = csv.writer(f, lineterminator="\n")
        wr.writerow(["source", "target", "rule", "source_ocr_count", "source_frequency_list_count",
                     "target_count_before", "target_count_after"])
        for src, (rule, dst) in sorted(merges.items(), key=lambda kv: (kv[1][0], kv[0])):
            wr.writerow([src, dst, rule, words[src]["ocr"], words[src]["extra"],
                         words[dst]["count"], final[dst]["count"]])
    with open(os.path.join(review, "flagged.csv"), "w", encoding="utf-8", newline="") as f:
        wr = csv.writer(f, lineterminator="\n")
        wr.writerow(["priority", "word", "count", "ocr_count", "frequency_list_count", "word_lists",
                     "base_score", "categories", "notes"])
        rows = []
        for w, items in flags.items():
            r = final[w]
            prio = "high" if r["count"] >= HIGH_PRIORITY_COUNT else "normal"
            rows.append((prio != "high", -r["count"], w, [prio, w, r["count"], r["ocr"], r["extra"], r["lex"],
                                                           r["score"], "; ".join(c for c, _ in items),
                                                           "; ".join(n for _, n in items)]))
        for *_, row in sorted(rows):
            wr.writerow(row)
    with open(os.path.join(review, "summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")


# ----------------------------------------------------------------- validation
# Rows cleanup version 1 leaves in place because their repaired form is not
# attested or has two attested readings (flagged.csv, "not merged").
KEPT_WITH_KB_SIGN = 2        # «кь»
KEPT_WITH_TWO_SIGNS = 5      # two signs in a row


def validate(out):
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    wp, bp = os.path.join(out, WORDS_ARTIFACT + ".sqlite"), os.path.join(out, BIGRAMS_ARTIFACT + ".sqlite")
    wc, bc = ro(wp), ro(bp)
    for con, table, artifact, create in ((wc, "words", WORDS_ARTIFACT, WORDS_SQL),
                                         (bc, "bigrams", BIGRAMS_ARTIFACT, BIGRAMS_SQL)):
        meta = dict(con.execute("SELECT key, value FROM meta"))
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        check(f"{artifact}: meta.artifact", meta.get("artifact") == artifact, meta.get("artifact"))
        check(f"{artifact}: meta.row_count == COUNT(*) ({n})", meta.get("row_count") == str(n), meta.get("row_count"))
        for k, v in (("schema_version", SCHEMA_VERSION), ("content_version", CONTENT_VERSION),
                     ("normalization_version", NORMALIZATION_VERSION),
                     ("normalization_profile", NORMALIZATION_PROFILE), ("min_reader_schema", MIN_READER_SCHEMA),
                     ("cleanup_version", CLEANUP_VERSION), ("language", "kum")):
            check(f"{artifact}: meta.{k} == {v}", meta.get(k) == str(v), meta.get(k))
        for k in ("generated_at", "sources", "derived_from"):
            check(f"{artifact}: meta.{k} present", bool(meta.get(k)))
        check(f"{artifact}: schema is the General Keyboard artifact shape",
              table_sql(con) == {table: create, "meta": META_SQL})
        check(f"{artifact}: page_size 4096", con.execute("PRAGMA page_size").fetchone()[0] == 4096)
        check(f"{artifact}: vacuumed", con.execute("PRAGMA freelist_count").fetchone()[0] == 0)
        check(f"{artifact}: integrity_check", con.execute("PRAGMA integrity_check").fetchone()[0] == "ok")
    words = dict(wc.execute("SELECT word, base_score FROM words"))
    pairs = list(bc.execute("SELECT prev, word, weight FROM bigrams"))
    bad = [w for w in words if canonical(w) != w]
    check("every word is canonical under the kumyk-cyrillic profile", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not is_valid_token(w)]
    check("every word passes the token contract", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not ALPHABET_RE.fullmatch(w)]
    check("every word uses only а–я, ё and inner hyphens", not bad, ", ".join(bad[:5]))
    check("no palochka (U+04C0, U+04CF) anywhere", not any(ch in _PALOCHKAS for w in words for ch in w))
    left = sorted(w for w in words if "кь" in w and not SIGN_RUN.search(w))
    check(f"«кь» is left only in the {KEPT_WITH_KB_SIGN} flagged rows", len(left) == KEPT_WITH_KB_SIGN, ", ".join(left))
    left = sorted(w for w in words if SIGN_RUN.search(w))
    check(f"two signs in a row are left only in the {KEPT_WITH_TWO_SIGNS} flagged rows",
          len(left) == KEPT_WITH_TWO_SIGNS, ", ".join(left))
    check("every base_score >= 1", all(s >= 1 for s in words.values()))
    bad = [(a, b) for a, b, _ in pairs if a not in words or b not in words]
    check("both words of every bigram are rows of the words artifact", not bad, str(bad[:3]))
    check("every bigram weight >= 2", all(v >= 2 for _, _, v in pairs))
    wc.close()
    bc.close()
    return results


# ----------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=DEFAULT_SOURCE, help="folder with the five v0 kum_* files")
    ap.add_argument("--out", default=DEFAULT_OUT, help="where the two artifacts are written")
    ap.add_argument("--review", default=DEFAULT_REVIEW, help="where the review files are written")
    ap.add_argument("--validate", action="store_true", help="only validate the artifacts in --out")
    args = ap.parse_args()

    def report(results):
        for name, ok, detail in results:
            print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
        return 0 if all(ok for _, ok, _ in results) else 1

    if args.validate:
        return report(validate(args.out))
    try:
        words, pairs, v0_meta, stats = load(args.source)
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    a = audit(words, pairs)
    hard = {k: a[k] for k in ("not_nfc", "not_lowercase", "not_canonical", "canonical_collisions",
                              "contract_invalid", "outside_alphabet", "latin_letters", "palochka",
                              "replacement_or_control_chars", "score_formula_mismatch", "count_mismatch")
            if a[k]}
    if hard or a["bigram_orphans"] or a["bigram_weight_below_2"] or a["hyphenated_with_a_frequency_list_count"]:
        print("error: the v0 data breaks an assumption of this build:",
              json.dumps(hard, ensure_ascii=False)[:2000], file=sys.stderr)
        return 2

    merges, blocked = plan_merges(words)
    final, final_pairs, remapped = apply_merges(words, pairs, merges)
    flags = flag_entries(final, final_pairs, blocked)

    by_cat = Counter(c for items in flags.values() for c, _ in items)
    summary = {
        "input": {"archive": "keyboard_data_v0.zip / keyboard_data/", "files": V0_SHA256,
                  "v0_generated_at": v0_meta.get("generated_at"), "v0_sources": stats.get("sources")},
        "audit": a,
        "merges": {"total": len(merges), "by_rule": dict(sorted(Counter(r for r, _ in merges.values()).items())),
                   "targets": len({t for _, t in merges.values()}),
                   "tokens_moved": sum(words[s]["count"] for s in merges),
                   "not_merged": len(blocked),
                   "not_merged_by_rule": dict(sorted(Counter(r for r, _, _ in blocked.values()).items()))},
        "removed": 0,
        "flags": {"words": len(flags),
                  "high_priority": sum(1 for w in flags if final[w]["count"] >= HIGH_PRIORITY_COUNT),
                  "by_category": dict(sorted(by_cat.items(), key=lambda kv: (-kv[1], kv[0])))},
        "output": {"words": len(final), "bigrams": len(final_pairs),
                   "bigram_pairs_remapped": remapped, "bigram_pairs_combined": len(pairs) - len(final_pairs),
                   "words_unchanged_from_v0": sum(1 for w, r in final.items() if words.get(w) == r),
                   "corpus_tokens_kept": sum(r["count"] for r in final.values()),
                   "corpus_tokens_v0": sum(r["count"] for r in words.values()),
                   "bigram_weight_total": sum(final_pairs.values()),
                   "bigram_weight_total_v0": sum(pairs.values())},
    }
    write_artifacts(args.out, final, final_pairs)
    write_reviews(args.review, words, final, merges, flags, summary)
    results = validate(args.out)
    print(json.dumps({k: summary[k] for k in ("merges", "flags", "output")}, ensure_ascii=False, indent=1)[:4000])
    return report(results)


if __name__ == "__main__":
    sys.exit(main())
