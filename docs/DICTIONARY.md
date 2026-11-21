# The Kumyk dictionary (cleanup version 1)

The keyboard ships two read-only SQLite artifacts in the extension,
`kumyk_words.sqlite` (38,956 words, 968 KB) and `kumyk_bigrams.sqlite`
(43,995 word pairs, 1,388 KB), built by `scripts/build_dictionary.py` from
the v0 Kumyk data. The same files are bundled in Debug and Release. The
schema is General Keyboard's artifact contract
(`GeneralKeyboard-iOS/docs/engine/ARTIFACT_CONTRACT.md`): no extra columns,
no duplicate representations.

## Source data

`keyboard_data_v0.zip` (SHA-256
`8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31`, folder
`keyboard_data/`, built 2026-10-11 by `build_kb_data.py`), language code
`kum`. The five Kumyk files are kept **outside this repository**,
unmodified, with checksums, in `../kumyk-dictionary/original-v0/`
(`SHA256SUMS` there; the same hashes are pinned in the build script and in
each artifact's `meta.derived_from`):

| File | SHA-256 |
|---|---|
| `kum_words.sqlite` | `e9f0495d…dc5a` |
| `kum_bigrams.sqlite` | `b924c0c1…9c2f` |
| `kum_words.tsv` | `39474e97…4582` |
| `kum_bigrams.tsv` | `b8b5ae42…16bf` |
| `kum_stats.json` | `0b274275…df77` |

v0 sources (`kum_stats.json`; the v0 `meta.sources` named only the first
two, the artifacts here name all four):

- `lingconlab_freq`: the Kumyk rows of the LingConLab frequency list
  (newspaper «Ёлдаш», yoldash.ru, and «Тангчолпан» 2013): 88,504 word
  forms, 1,530,623 tokens. **Word counts only, no running text, and no
  hyphens**: it supplies 75 % of the counts and no bigrams.
- `zhd_ocr_kumyk`: the Kumyk edition of «Женщина Дагестана» 2016–2023, OCR
  from the LingConLab parallel corpus; 59,720 sentences, 529,540 tokens,
  9,397 sentences dropped as Russian. **The only running text**: every
  bigram comes from this OCR.
- `apertium_kum`: the Apertium Kumyk lexicon (`kum.lexc`), 4,860 words.
- `ids`: Intercontinental Dictionary Series word list, 1,557 words.

v0 scoring: `base_score = 10 × corpus count + min(9, number of word lists)`;
bigram `weight` = adjacent occurrences in one sentence, kept when ≥ 2 and
both words are rows. Thresholds: a word seen only in OCR or only in the
frequency list needs ≥ 3 occurrences. v0 normalized with NFC, lowercase and
the twelve Latin → Cyrillic twins; ё and э were kept apart from е (they are
separate Kumyk letters).

## Audit of the v0 data

| | |
|---|---|
| Words / bigrams | 39,325 / 44,143 |
| Words with a corpus count | 37,659; 1,666 come from a word list only (score 1–2) |
| Where a word is attested | OCR and frequency list 22,539 · frequency list only 12,046 · OCR only 3,074 (the remainder: word list only) |
| In a word list | 5,733 |
| OCR-only (no word list, not in the frequency list) | 2,636, of which 1,609 seen only 3–4 times, where the v0 README expects 10–15 % OCR errors |
| Corpus tokens | 1,930,926: 1,455,487 from the frequency list, 475,439 from OCR |
| `base_score` | 1 … 491,452 (да); median 80 |
| Bigram weight | 2 … 1,213 (бары да); median 2 |
| Character inventory | the 33 Russian letters а–я, ё and the hyphen (380 words). No Latin letters, no palochka (U+04C0, U+04CF), no digits, no controls, no U+FFFD |
| Unicode | all NFC, all lowercase, all canonical under the `kumyk-cyrillic` profile; no two rows collapse to one canonical form |
| Contract validity | every row passes `Normalization.isValidToken` (≥ 2 letters with ъ ь as digraph tails, no `@ / .`, ≤ 64 scalars) |
| Duplicates / malformed rows | none (primary keys); TSV and SQLite agree exactly |
| Bigrams | no orphan words, no weight < 2, 23 self-pairs (`йыл йыл`, `аста аста`…, kept) |
| Metadata | `schema_version` 1, `content_version` 1, `normalization_version` 1, `min_reader_schema` 1, no `row_count`, no profile name (both added here) |

Encoding is clean. The problems are OCR errors and one tokenizer artifact.

### Patterns found

| Pattern | Rows | Example |
|---|---|---|
| OCR «кь» for «къ» (Kumyk has no «кь») | 134 | `халкь` (78) next to `халкъ` (2,680) |
| Two signs in a row | 23 | `кьъаршы` (8) next to `къаршы` (1,531) |
| Joined form of a hyphenated word (the frequency list strips hyphens: none of the 380 hyphenated rows has a frequency-list count) | 260 | `бирбир` (608) next to `бир-бир` (135 in running text) |
| «гь» where «гъ» is ≥ 10× as frequent, or the reverse | 56 | `дагьы` (45) vs `дагъы` (3,569) |
| «ть» for «гь» | 26 | `тьакъында` (38) vs `гьакъында` (3,816) |
| A token that spells an attested word pair without the space | 148 | `негетюгюл` (44) vs `неге тюгюл` (pair weight 282) |
| э after a consonant (glued words, abbreviations, loans) | 72 | `социалэкономика` (154) |
| No vowel (abbreviations) | 76 | `жкх`, `мфц` |
| Two-letter tokens outside the word lists | 111 | `аа`, `ны`, `на` |
| е for ё (the ё form ≥ 10× as frequent) | 7 | `кемек` (3) vs `кёмек` (1,976) |
| Lost ъ after г or к | 4 | `бырынгы` (3) vs `бырынгъы` (470) |

## What the build changes (and what it does not)

Three mechanical artifacts are **merged** into the attested word they stand
for:

- **S1** «кь» is «къ»: 132 rows (`халкь` → `халкъ`).
- **S2** two signs in a row are one: 18 rows (`кьъаршы` → `къаршы`,
  `гьакъь` → `гьакъ`).
- **H1** the joined form of a hyphenated word takes its hyphen back: 219
  rows (`айрыайры` → `айры-айры`, `бирбир` → `бир-бир`, `дрни` → `др-ни`).

A merge needs a source row that no word list knows and a repaired form that
is already a row of the data. S1 and S2 also need the repaired form to be
at least as frequent. H1 needs the hyphenated spelling to be at least five
times as common in the running text (the OCR corpus) as the joined one;
128 of the 219 joined rows never occur in running text at all. The source
row's counts are added to the target (its `base_score` is recomputed with
the v0 formula) and its bigrams are re-keyed (183 pairs re-keyed, 148
combined with existing pairs). Every merge is listed in
`dictionary/review/corrections.csv`.

48 candidates are **not merged** and stay as they are, flagged:

- 2 «кь» rows whose repaired form is not attested (`вкь`, `блукьмай`);
- 5 two-sign rows with two attested readings (`огьъар`: `огъар` or `огьар`);
- 41 joined forms that running text also writes joined, or that a word
  list has (`гьажимурат` is the usual spelling next to `гьажи-мурат`).

Everything else is **kept unchanged**: nothing is deleted, no spelling is
rewritten, no score is adjusted. 38,609 of the 39,325 v0 rows are
byte-for-byte the same, all 1,930,926 corpus tokens and the whole bigram
weight (198,959) are preserved. The гъ/гь doubts, the glued words, the
abbreviations and the Russian words are not decided by the build; they are
listed for a Kumyk speaker.

Result: 38,956 words, 43,995 bigrams; `content_version` 1,
`cleanup_version` 1, `normalization_version` 1, `normalization_profile`
`kumyk-cyrillic`.

## Normalization

Kumyk has its own profile (`KumykDefinition.normalization`, id
`kumyk-cyrillic`, version 1), mirrored in the build script:

- NFC, trim, lowercase, NFC again (the engine's fixed pipeline);
- **no palochka**: the convention of the Avar, Lezgi and Dargwa keyboards
  is off, nothing is ever repaired into ӏ, and a Latin `I` or `l` inside a
  Cyrillic word makes the token invalid;
- the twelve Latin twins (`a c e o p x y k m t b h`) are repaired inside
  Cyrillic tokens, as the v0 builder did;
- digraph tails **ъ ь**: гъ, гь, къ, оь, уь count as one letter each; нг
  counts as two, because г is a letter of its own. A word needs two
  letters to be learned or stored;
- ё, э and е are different letters and never folded.

The artifacts carry `normalization_profile = kumyk-cyrillic` in `meta`
(General Keyboard design §2.4a). The engine does not read that key yet,
and the learned store still records only the profile's version under the
key every keyboard uses. That is harmless here, because the Kumyk keyboard
has its own container and has only ever had this one profile, but it is the
engine gap `ADDING_A_KEYBOARD.md` lists for the first keyboard with its own
profile. No engine change was made for it.

## Review files (`dictionary/review/`)

- `flagged.csv`: **575 entries kept as they are and listed for a linguistic
  review**, 77 of them high priority (≥ 20 occurrences). Columns: priority,
  word, counts per source, word lists, score, categories, notes (with the
  attested alternative where one exists). Categories: possibly two words
  glued (148), two-letter token outside the word lists (111), no vowel
  (76), э after a consonant (72), «гь» where «гъ» is far more frequent
  (52), not merged H1 (41), very long token (31), possibly «гь» read as
  «ть» (26), word starts with гъ (18), same letter three times (17), оь or
  уь inside a word (10), possibly ё written as е (7), short hyphen part
  (6), not merged S2 (5), possibly lost ъ (4), «гъ» where «гь» is far more
  frequent (4), word starts with ь or ъ (3), not merged S1 (2).
- `corrections.csv`: the 369 merges with their counts.
- `summary.json`: the audit and the counts above, written by the build.

## What to know about the content

- The dictionary reflects newspaper and magazine Kumyk: the literary
  standard, with Russian loans and Russian month names in dates (`марта`,
  `сентября`), surnames (`магомедов`) and abbreviations (`жкх`).
- Words are stored in lowercase; a name is suggested capitalized only when
  its first letter is typed as a capital.
- `нчи`, `нчу`, `ни`, `ны` and the like are suffixes that Kumyk writes
  after a numeral or an abbreviation (2020-нчы йыл); they are rows because
  the sources tokenize them apart.
- Hyphenated words (380 rows, `бир-бир`, `ата-анасы`) are suggested from
  the part before the hyphen and inserted whole. The engine's tokenizer
  treats `-` as a separator while typing, so a hyphen typed by hand starts
  a new word (General Keyboard backlog).
- The layout covers every character the dictionary uses.

## Rebuilding

```bash
# from the repository root, with ../kumyk-dictionary/original-v0 in place
SOURCE_DATE_EPOCH=1795132800 python3 -I scripts/build_dictionary.py
python3 -I scripts/build_dictionary.py --validate     # checks the shipped files
```

The build verifies the SHA-256 of every input, refuses data that breaks
its assumptions, writes the two artifacts (page size 4096, vacuumed,
`row_count` in `meta`) and the review files, and validates the result
(schema, metadata, canonical form and contract validity of every row,
no orphan bigrams, no artifact left outside the flagged rows). With
`SOURCE_DATE_EPOCH` set the output is byte-identical on every run (the
shipped files were built with the value above, 2026-11-20T00:00:00Z). A
future cleanup version changes the rules in the script, bumps
`CLEANUP_VERSION` and `CONTENT_VERSION`, and rebuilds; the v0 inputs never
change.

To recreate `../kumyk-dictionary/original-v0/` from the archive:

```bash
unzip -j keyboard_data_v0.zip 'keyboard_data/kum_*' -d kumyk-dictionary/original-v0
```
