# The Kumyk layout

This is the **proposed LekiTech Kumyk layout**. No community or official
Kumyk iOS layout existed to copy; it was designed here from corpus data.
It is not an Apple keyboard. It has been tested on an iPhone by the project
owner; a wider review by Kumyk speakers is still open
([open questions](#open-questions)).

## Rows (iPhone)

```
й ц у к е н г ш ъ з х        11 keys
ф ы в а п р о л д ж э        11 keys
⇧ я ч с м и т ь б ю ⌫        9 letters
123 ⚙︎ 😀 🌐  space  ⏎
```

The Russian iOS layout with **one key changed**: the hard sign **ъ** is
where the Russian keyboard has **щ**; **щ** is a long press on ш. Every
other letter is in its Russian place. Key sizes are those of the Russian
keyboard (11 keys per row, 29.7–30 pt on a 402 pt iPhone); the engine
draws the grid with `KeyboardGridModel.nativeCells`.

The number and symbol pages are the Russian iOS pages, unchanged:
`1 2 3 4 5 6 7 8 9 0` / `- / : ; ( ) ₽ & @ "` / `#+= . , ? ! ' ⌫` and
`[ ] { } # % ^ * + =` / `_ \ | ~ < > $ € ¥ •` / `123 . , ? ! ' ⌫`.

## Long press (complete)

| Key | Options (in order) | |
|---|---|---|
| г | гъ гь | digraph letters; гъ first (1.72 % of letters vs 0.79 %) |
| к | къ | digraph letter |
| н | нг | digraph letter |
| о | оь | digraph letter |
| у | уь | digraph letter |
| е | ё | no key of its own, as on the Russian keyboard |
| ш | щ | no key of its own |
| ь | ъ | the Russian keyboard's habit keeps working |
| 0 | ° | |
| ₽ | $ € £ ¥ ￦ | |
| # | № | |
| . | … | |
| % | ‰ ∞ | |
| = | ≠ ≈ | |
| - | • – — | |
| / | \ | |
| & | § | |
| ? | ¿ | |
| ! | ¡ | |
| ' | ’ ‘ ` | |
| " | ” “ „ » « | |

The popup shows the key's own letter first, then the options, centred over
the key. Under **г** (two options) the first option, гъ, is under the
finger: hold and release types гъ, a slide to the right гь. Under a key
with one option the popup has two cells and the finger rests on their
border, so the option is picked with a slight slide to the right (a finger
on the right half of the key is already on it). This is General Keyboard's
popup, the same in the Lezgi and Dargwa keyboards. A digraph option inserts
both characters at once. **Each digraph is two ordinary Cyrillic
characters** (гъ = U+0433 U+044A, гь = U+0433 U+044C, къ = U+043A U+044A,
нг = U+043D U+0433, оь = U+043E U+044C, уь = U+0443 U+044C): no special
code points, no Latin letters, no palochka.

All six digraphs can also be typed key by key (г then ъ), which is what the
ъ key is for. Shift capitalizes the first letter of a digraph (**Гъ**,
**Оь**), Caps Lock all of it (**ГЪ**, **ОЬ**), for the long-press options
and for plain typing alike.

## Kumyk spelling the layout is built on

The alphabet in use since 1938 has 39 letters: the 33 Russian letters and
six digraphs.

```
а б в г гъ гь д е ё ж з и й к къ л м н нг о оь п р с т у уь ф х ц ч ш щ ъ ы ь э ю я
```

- **гъ** [ʁ], **гь** [h], **къ** [q], **нг** [ŋ], **оь** [ø], **уь** [y].
- **оь** and **уь** are written at the beginning of a word (оьзю, уьч);
  after a consonant the same vowels are written **ё** and **ю** (кёп, гюн).
  The corpus agrees: оь is word-initial in 40,426 of 40,465 occurrences,
  уь in 14,327 of 14,336; 75 % of ё and 82 % of ю follow a consonant.
- **ъ** on its own marks the glottal stop of Arabic loans (маъна, таъсир,
  масъала) and is the Russian separator (съезд, объект).
- **ф, ц, щ** occur in loanwords only.

Sources: the alphabet and sound values as given in the Kumyk articles of
Wikipedia and Omniglot, which cite З. З. Бамматов, «К вопросу о
письменности кумыков» (1972) and «Орфография кумыкского языка» (1973,
in «Орфографии тюркских литературных языков СССР», Москва, Наука); the
positional rule for оь/уь and ё/ю is measured from the corpus above.
Бамматов's texts were not read directly.

## The evidence

Measured by `scripts/analyze_layout.py` from the keyboard's own dictionary
(`kumyk_words.sqlite`, cleanup version 1): 37,293 word forms with a corpus
count, 1,930,926 word tokens, 12.2 million characters, token-weighted. The
counts come from two independent corpora, a newspaper frequency list (1.46
million tokens) and the OCR of a magazine (0.48 million); see
[DICTIONARY.md](DICTIONARY.md). Full output:
[layout/analysis.json](layout/analysis.json).

**Characters, % of all characters**

| а | н | л | е | р | и | г | ы | д | т | **ъ** | у | к | о | м | б | с |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14.42 | 7.25 | 6.82 | 5.99 | 5.46 | 5.30 | 4.82 | 4.46 | 3.90 | 3.87 | **3.84** | 3.67 | 3.64 | 2.89 | 2.85 | 2.82 | 2.51 |

| й | ю | ш | в | з | п | **ь** | ч | я | э | **ё** | х | ж | ц | ф | **щ** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1.81 | 1.78 | 1.69 | 1.65 | 1.39 | 1.37 | **1.29** | 1.24 | 1.04 | 0.66 | **0.56** | 0.44 | 0.38 | 0.11 | 0.10 | **0.008** |

- **ъ is the 11th most frequent character (3.84 %)**, ahead of у, к and о.
  97.7 % of it is in **къ** (52.7 %) and **гъ** (45.0 %); 55.6 % of all к
  and 35.9 % of all г are followed by ъ.
- **щ is the rarest letter (0.008 %)**: 59 word forms, all Russian loans
  (заведующий, училище, овощлар).
- **ь is 1.29 %**: 58.4 % in гь, 25.7 % in оь, 9.1 % in уь, the rest
  Russian (ль, нь).
- The digraphs as letters of the alphabet: къ 2.14 %, гъ 1.72 %, гь
  0.79 %, нг 0.47 %, оь 0.35 %, уь 0.12 %; together 5.6 % of all letters.
- Most frequent character pairs: ла 2.8 %, ан 2.7 %, **къ 2.4 %**, да
  2.3 %, ар 2.2 %, ъа 2.1 %, **гъ 2.1 %**, ге 1.6 %.
- Words: 6.34 letters on average; five letters is the most common length
  (16 %), 90 % of running words have 2–10 letters. Kumyk is agglutinative:
  word forms are long chains of suffixes (болгъан, къумукъланы), which
  keeps к, г, ъ, л, н, д busy.
- The two corpora agree: ъ is 3.86 % in the newspapers and 3.74 % in the
  magazine, щ 0.008 % and 0.009 %, and the eleven most frequent letters are
  the same set in both.

### What Agisight's projects contain for Kumyk

- [rf-keyboard-corpora](https://github.com/Agisight/rf-keyboard-corpora)
  `data/kum/Ali_Kuzhuget/` (commit `cd7a94e`, MIT): the long-press mapping
  `kum_key_mapping_ext.json` (Г: ГЪ ГЬ · К: КЪ · Н: НГ · О: ОЬ · У: УЬ),
  **used here** and pinned in `Tests/KumykCoreTests/Fixtures/agisight/`.
- Its frequency table `kum_monocorpus_freq.csv` is **not Kumyk**: at that
  commit the file is byte-identical to the Tabasaran table (it lists пӀ,
  кӀ, хь, аь and gives ы 0.15 %, where Kumyk has 4.5 %). Not used.
- Its corpus file holds only a link to the Kumyk part of FineWeb-2 on
  Hugging Face; that corpus was not downloaded.
- [ios-system-keyboard](https://github.com/Agisight/ios-system-keyboard)
  (commit `86e000a`, MIT) has no Kumyk layout and no Kumyk key names. Its
  transcription of the Russian iOS keyboard (`layout/rus`) is the baseline
  the tests compare against.

## Candidates compared

All numbers are **model estimates**, not measured typing: every word of the
corpus typed letter by letter with two thumbs, no suggestion picked; a
long press costs a tap plus the keyboard's default 0.3 s delay; thumb
travel on the 402 pt grid. Assumptions are in the script's header.

| | A0 | A | **B (chosen)** | C1 | C2 |
|---|---|---|---|---|---|
| | Russian keyboard as it is: ъ under ь | Russian layout + къ, гъ… on long press | ъ on щ's key, щ under ш | Russian layout + ъ as a 12th top-row key | B + ё on ц's key, ц under ч |
| Long presses per 100 words | 27.8 | 27.8 | **3.6** | 3.5 | 0.7 |
| Words needing a long press | 23.9 % | 23.9 % | **3.6 %** | 3.5 % | 0.7 % |
| Key presses per word | 6.34 | 6.10 | 6.34 | 6.34 | 6.34 |
| Seconds per 100 words, 0.25 s per tap | 166.7 | 160.8 | **159.5** | 159.5 | 158.6 |
| Seconds per 100 words, 0.18 s per tap | 122.4 | 118.1 | **115.1** | 115.1 | 114.3 |
| Thumb travel per character | 53.1 pt | 49.1 pt | 52.7 pt | 55.8 pt | 53.0 pt |
| Narrowest letter key (402 / 375 pt screen) | 29.9 / 27.5 pt | 29.9 / 27.5 pt | **29.9 / 27.5 pt** | 26.9 / 24.7 pt | 29.9 / 27.5 pt |
| Keys that differ from Russian | 0 | 0 | **1** (щ) | 11 shifted (narrower row) | 2 (щ, ц) |
| къ | long press | long press | 2 taps, both thumbs | 2 taps, both thumbs, far | as B |
| гъ | long press | long press | 2 taps, 72 pt apart | 2 taps, 165 pt apart | as B |
| гь, нг, оь, уь | 2 taps | 2 taps | 2 taps | 2 taps | 2 taps |

**Why B.**

- It removes 87 % of the long presses (27.8 → 3.6 per 100 words). On a
  Russian-style layout almost every fourth word needs one, because ъ is not
  a key; with B it is one word in 28, nearly all of them for ё.
- It costs one key of Russian familiarity, the rarest letter of the
  language, and keeps the Russian key size. щ stays one long press away,
  under ш.
- A (long-press digraphs) types къ in one press, so its modelled time is
  within 1–3 % of B's. But the model assumes every long press is held
  exactly 0.3 s and released on the right option. In practice a hold breaks
  the two-thumb rhythm 28 times per 100 words, a release that comes too
  early types a plain к, and the faster the typist the more a fixed delay
  costs (2.5 % at 0.18 s per tap). B still offers the same long presses for
  those who like them.
- к is on the left half and ъ on the right, so **къ**, the most frequent
  digraph, alternates thumbs. **гъ** is one thumb, two keys to the right;
  **нг** is two neighbouring keys; **о** sits directly above **ь**.
- The same slot holds ъ in the Dargwa keyboard, so the sibling keyboards
  agree.

**Why not the others.**

- C1 keeps щ but makes the top row 12 keys: 10 % narrower keys (24.7 pt on
  a 375 pt iPhone), every top-row letter shifted off its Russian position,
  and ъ in the far corner, 165 pt from г. No gain over B in long presses.
- C2 gives ё (0.56 %) a key by moving ц (0.11 %) under a long press. That
  saves a further 2.9 long presses per 100 words, about 12 % of what B
  already saves, and breaks a second Russian position (the «ц» of ЙЦУКЕН, needed
  for Russian words inside Kumyk text). Kept as an
  [open question](#open-questions) rather than decided without speakers.
- A letter after the space bar (Lezgi's «ъ» style) was not modelled: it
  narrows the space bar and Return on every word for a letter that is
  0.6 % (ё) or already has a key (ъ).

## Known trade-offs

- **щ needs a long press.** Rare in Kumyk (0.008 %) but roughly 0.4 % of
  Russian text, so Russian written with this keyboard is slightly slower.
  The Russian keyboard is one 🌐 away.
- **ё needs a long press**, as on the Russian keyboard: 3.5 per 100 words,
  almost all of the long presses that remain.
- **гъ is typed with one thumb** (г, then ъ two keys to the right).
- **ь → ъ** on a long press is redundant with the ъ key. It is kept so
  that the Russian-keyboard habit «hold ь» still produces ъ.
- Thumb travel is 7 % higher than in A (52.7 vs 49.1 pt per character),
  the price of tapping ъ instead of holding к or г.
- **A long press with one option needs a small slide** (see the long-press
  table). Native iOS preselects a single alternate; General Keyboard does
  not. Worth an engine change for every keyboard, not made here.
- The model types every letter; in real use suggestions shorten words, and
  the dictionary knows 38,956 word forms.

## Familiarity

The layout is recognizable as Russian at a glance: 30 of the 31 letter
keys are where the Russian keyboard has them, the number and symbol pages
are identical, and both Russian long presses (е → ё, ь → ъ) still work.

## Implementation

`KumykKeyboardExtension/KumykLayout.swift`: one style
(`LayoutStyle.standard`, persisted under `layoutStyle`), rows written once
in lowercase, the engine derives Shift and Caps Lock. With one style the
engine hides the layout selector. `KumykLayoutTests` pins the rows, checks
that exactly one key differs from the pinned Russian layout, checks every
long-press mapping and the digraph code points, and re-measures the
frequencies above from the shipped dictionary.

Not implemented: iPad-specific rows (iPad shows the iPhone rows on the
engine's weighted grid), a macOS layout.

## Open questions

For Kumyk speakers and the first testers:

1. **ё on a key?** ё is five times as frequent as ц or ф. Variant C2 would
   put it on ц's key. Is losing ц's Russian position acceptable?
2. **Is щ under ш enough**, or do users write enough Russian with this
   keyboard to miss the key?
3. **Should ь → ъ stay** now that ъ has a key?
4. **Order under г**: гъ first is the frequency order. Does it feel right?
5. **A second, strictly Russian style** (щ on its key, ъ only on long
   press) could be offered in the keyboard's settings, as Lezgi offers two
   styles. Wanted?
