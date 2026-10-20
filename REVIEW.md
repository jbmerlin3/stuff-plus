# Pre-shot review: PREREG.md against the code

2026-10-20. Every plan item matched to the code that implements it. No model
had been fit and no grade seen when this was written.

Key: ✅ matches · 🔧 gap, fixed before the shot · ⏳ runs after the verdict, so it
cannot affect the gates · ❓ needs Jonathan's call

## Data and cleaning (sections 1, amendment 1)

| plan | code | status |
|---|---|---|
| 2022-2025 only; 2026 untouched | `02_clean.R` `SEASONS <- 2022:2025` | ✅ |
| `delta_run_exp` present, balls < 4, strikes < 3 | `clean_pitches()` last filter | ✅ |
| Pitch types incl. FO; KN, EP, CS, SC, PO out | `VALID_TYPES` | ✅ |
| Position players out (FA/EP > 50% or < 80 mph, 8 hand-checked exceptions) | `flag_position_players()`, `REAL_PITCHERS` | ✅ |
| Bunts, pitchouts, automatic calls out | `DROP_DESC` | ✅ |
| 2,827,868 pitches | cleaning log, rerun 2026-10-20 with `zone` | ✅ |

## Target (section 2, amendment 3)

| plan | code | status |
|---|---|---|
| Outcomes: ball, called strike, whiff, foul, walk, HBP, K, 1B, 2B, 3B, HR, out | `outcome()` in `R/target.R` | ✅ |
| Errors are outs; sac bunts, CI, truncated PA dropped; foul tips are whiffs | `OUT_EVENTS`, `DROP_EVENTS`, `WHIFF_DESC` | ✅ |
| League mean of `delta_run_exp` by outcome × count; < 50 falls back | `rv_table(min_cell = 50)` | ✅ |
| Sign flipped, higher = better for pitcher | `rv = -...` | ✅ |
| Built from training pitchers only | `run_cv()`: `rv_table(train)`; leak tests pass | ✅ |

## Inputs (section 3, amendment 2)

| plan | code | status |
|---|---|---|
| Seven inputs, no pitch type, count or location | `INPUTS` in `R/model.R` | ✅ |
| IVB, HB in inches; HB and release side arm-side positive for both hands | `add_shape()`; audit table 2026-10-19 | ✅ |
| Velo gap from hardest FF/SI/FC at 10% + 20 pitches, else most-thrown | `primary_fastball()`; re-audit clean | ✅ |
| Batter side 0/1 | `same_side` | ✅ |

## Model (section 4)

| plan | code | status |
|---|---|---|
| squared error, depth 4, eta 0.05, 400 rounds, min_child 100, subsample 0.8, colsample 1.0 | `PARAMS`, `N_ROUNDS` | ✅ |
| Seed 3, reproducible | `set.seed(3)` in `fit_model()` | 🔧→✅ dry run fits one fold twice and requires identical predictions |

## Grade (section 5, amendment 4)

| plan | code | status |
|---|---|---|
| Score both sides; overall = 50/50 | `score_both_sides()` | ✅ |
| Split grades mapped to vs RHH / vs LHH by pitcher hand | not written | ⏳ needed for leaderboards and the app, not for any gate |
| μ = mean overall prediction, σ = SD of pitcher-type seasons with 100+ | `final_fit()` | ✅ |
| Gates use raw predictions, scale is display only | `run_gates()` uses `pred` | ✅ |

## Validation and gates (sections 6, 7)

| plan | code | status |
|---|---|---|
| 5 pitcher folds, seed 3 | `assign_folds()`; leak test 1 | ✅ |
| Pairs: 100+ pitches in t and t+1 | `year_pairs(min_n = 100)` | ✅ |
| Gate 1: edge, pitcher-clustered paired bootstrap, 1,000 reps, CI above 0 | `edge()`, `boot_ci()`, `pass$gate1` | ✅ |
| Gate 2: edge positive in each family | `FAMILY`, `pass$gate2` | ✅ |
| Gate 3: type-centered pooled r, CI above 0, 5 of 6 types positive | `within_type_r()`, `pass$gate3` | ✅ Centering is by pitch type across all seasons pooled, as written. A per-season centering would also be defensible; noted, not changed |
| Gate 4: 10 of 15 elite top 20%, 3 of 4 weak bottom 20%, 250+ pool, FO with FS | `known_answers()` | ✅ One deviation, kept on purpose: a missing entry **stops** the run instead of being dropped and the bar scaled. All 19 were verified at 250+, so a missing one means a bug |
| 7a changeup fallback | `INPUTS_CH`, shot section | 🔧→✅ written before the shot; trigger settled in amendment 6 |
| 7b bugs vs findings | procedure | ✅ |

## Reported (section 10, amendment 5)

| plan | code | status |
|---|---|---|
| 1. Linear baseline, gates 1 and 3 | `fit_linear()`, shot prints both | ✅ |
| 2. Stabilization at 25/50/100/200 | `split_half()` | ✅ |
| 3. Importance + worked examples for three known pitches | `final_fit()`, `explain_pitch()` in the shot | 🔧→✅ |
| 4. Depth 6, UNRESOLVED if any verdict flips | explicit comparison in the shot | 🔧→✅ |
| 5. Mean Stuff+ by type | `stuff_plus` column in the shot | 🔧→✅ |
| 6. Pitcher-level K-BB%, v5g comparison | not written | ⏳ needs K-BB% and v5g grades joined; written after the verdict |
| 7. Leaderboards, platoon table, his prediction | platoon table in `by_type()`; boards not written | ⏳ written after the verdict, before anyone looks at a board |
| 8. FanGraphs and tjStuff+ comparisons | not written | ⏳ 2026 parts only if gates pass |
| Location check | `location_check()` | ✅ |
| Package versions recorded | `renv.lock`, 136 packages | ✅ |

## ✅ Decided: when does the changeup fallback trigger?

Jonathan, 2026-10-20: only if gate 3 fails with CH among the misses (amendment 6).

Section 7a was drafted when gate 3 required all six types positive: "If CH
fails gate 3's within-type check... If CH still fails, the shot fails." Gate 3
was then changed to allow one type to miss, and 7a was not updated. So the two
sections disagree when CH is the only miss: gate 3 passes, but 7a says the shot
fails.
