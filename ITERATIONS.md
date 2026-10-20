# v2 development log (2022-2025 only; 2026 untouched)

One line per experiment: date, change, result on the dev bars, kept or dropped.

| date | change | dev result | kept? |
|---|---|---|---|
| 2026-10-20 | v1 inputs (baseline) | dev whiff r 0.282, rv-swing 0.213; 2025 ours 0.234 vs FG 0.512 (gap -0.277). Weak: FS 0.03, ST 0.11, SL 0.19 | baseline |
| 2026-10-20 | + IVB and HB gaps (changeup fix) | dev whiff r 0.274; 2025 ours 0.220 vs FG 0.512; CH fell 0.276 -> 0.237 | dropped: no gain, CH worse |
| 2026-10-20 | Fairness check: our model in-sample on 2025 | ours 0.272 vs FG 0.512; in-sample advantage worth ~0.04 of the 0.28 gap | gap is the model, not the comparison |
