# v2 development log (2022-2025 only; 2026 untouched)

One line per experiment: date, change, result on the dev bars, kept or dropped.

| date | change | dev result | kept? |
|---|---|---|---|
| 2026-10-20 | v1 inputs (baseline) | dev whiff r 0.282, rv-swing 0.213; 2025 ours 0.234 vs FG 0.512 (gap -0.277). Weak: FS 0.03, ST 0.11, SL 0.19 | baseline |
| 2026-10-20 | + IVB and HB gaps (changeup fix) | dev whiff r 0.274; 2025 ours 0.220 vs FG 0.512; CH fell 0.276 -> 0.237 | dropped: no gain, CH worse |
| 2026-10-20 | Fairness check: our model in-sample on 2025 | ours 0.272 vs FG 0.512; in-sample advantage worth ~0.04 of the 0.28 gap | gap is the model, not the comparison |
| 2026-10-20 | 3a: one model + spin rate | dev whiff r 0.274; 2025 ours 0.227 vs FG 0.512. SL up 0.19 -> 0.22; CU down 0.37 -> 0.34; FS -0.03 | dropped: no overall gain |
| 2026-10-20 | 3b: three family models + spin rate | dev whiff r 0.231; 2025 ours 0.198 vs FG 0.512. FC collapsed 0.29 -> 0.01 | dropped: clearly worse, as in v5 Phase 2A |
| 2026-10-20 | Predictions before 3a/3b | Jonathan: CU improves most (it spins most); keep 3a if tied. Claude: FS and SL improve most, CU least | SL partly right; CU and FS wrong for both |
| 2026-10-20 | Benchmark check (`diag_benchmarks.R`), same pitches, same and adjacent season | 2025 same season: ours 0.234 vs FG 0.511. 2025 grades vs 2024 whiffs: ours 0.258 vs FG 0.452. 2024 same season: ours 0.262 vs public benchmark 0.285. 2024 grades vs 2025 whiffs: ours 0.247 vs 0.282 | FG's edge is mostly real (0.45 out of time); ours is within 0.02 to 0.04 of the second public benchmark. FG is the outlier |
| 2026-10-20 | **Whiff target** (swings only, 1 = whiff), v1 inputs | dev whiff r **0.423** (was 0.282), rv-swing 0.216 (was 0.213); 2025 ours 0.393 vs FG 0.512 (gap 0.12, was 0.28). FS 0.03 -> 0.44, CH 0.28 -> 0.36, FC 0.58; ST still 0.23. Predictive edge -0.078 (reported) | **kept: wins by the pre-set rule; v2 is the whiff model** |
| 2026-10-20 | Whiff model + **axis differential** (calibrated: CU ~0 both hands; SI/CH/FS larger; sign flips by hand, lefties mirrored) | dev whiff r **0.465** (+0.042), rv-swing 0.220; 2025 ours 0.450 vs FG 0.512 (gap 0.06). SI 0.45 -> 0.52, FF 0.46 -> 0.53, SL 0.43 -> 0.47; ST 0.23 -> 0.24; FS 0.44 -> 0.42 | **kept (+0.02 rule). v2 frozen: see PREREG_v2.md** |
