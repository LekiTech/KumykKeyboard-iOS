# Pinned upstream files

Unmodified copies, used by `KumykLayoutTests` and kept for attribution.

| File | Repository | Path | Commit |
|---|---|---|---|
| `rus-3-rows.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-3-rows.yaml` | `86e000a966d5d5aa5282617d5f6d90c69890e8db` (2026-11-11) |
| `rus-longpress.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-longpress.yaml` | same |
| `kum_key_mapping_ext.json` | https://github.com/Agisight/rf-keyboard-corpora | `data/kum/Ali_Kuzhuget/mapping/kum_key_mapping_ext.json` | `cd7a94ee8318b1abb7690b93755242fd73aaf1b5` (2026-11-11) |

Both repositories are MIT licensed: `LICENSE-ios-system-keyboard`
(Copyright (c) 2025 Agisight) and `LICENSE-rf-keyboard-corpora`
(Copyright (c) 2025 Agisight (Ali Kuzhuget)).

What the Kumyk keyboard takes from them:

- `rus-3-rows.yaml`, `rus-longpress.yaml`: a transcription of the Russian
  iOS keyboard (letter rows, number and symbol pages, symbol alternates),
  the baseline the Kumyk layout departs from by one key.
- `kum_key_mapping_ext.json`: which Russian key carries each Kumyk digraph
  on a long press (Г: ГЪ, ГЬ · К: КЪ · Н: НГ · О: ОЬ · У: УЬ).

Not taken: `data/kum/Ali_Kuzhuget/frequencies/kum_monocorpus_freq.csv` of
rf-keyboard-corpora. At this commit it is byte-identical to the Tabasaran
file (`data/tab/.../tab_monocorpus_freq.csv`: it lists пӀ, кӀ, хь, аь and
gives ы 0.15 %), so it is not Kumyk data. The Kumyk frequencies in
`docs/LAYOUT.md` are measured from the keyboard's own dictionary instead.
