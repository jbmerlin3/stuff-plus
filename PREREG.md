# Pre-registration: Stuff+

Written 2026-10-19, **before anything was fit**. Every choice below is logged
with its reasoning in `DECISIONS.md`. The only numbers here are row and pair
counts from `pitches_all_master.rds`, read 2026-10-19. No model output, grade
or leaderboard informed any of it.

## 0. What this test decides

**Whether this Stuff+ replaces the FanGraphs CSV in the arsenal app's Stuff+
column.** It ships if all four gates in section 7 pass. If any fails, nothing
ships, the failure is written up, and a v2 may be tested on 2026, which this
test never touches.

One shot. Settings and gates are fixed here. Sensitivity checks can veto a
result but never choose one.

## 1. Data

- **Training and validation:** 2022 to 2025 regular season, complete.
  2,834,000 pitches after the filters below (1,663 of them forkballs).
- **Filters:** `delta_run_exp` present, balls under 4, strikes under 3, pitch
  type in FF, SI, FC, SL, ST, SV, CU, KC, CH, FS, FO. Excluded: KN, EP, CS, SC
  (rare) and PO (pitchouts).
- **2026 is untouched by the gates.** The 2026 leaderboards and the FanGraphs
  comparison (section 10) are produced only if the gates pass, so a failed
  shot leaves 2026 clean for v2.

## 2. Target

**Run value averaged by count and outcome, sign flipped so higher is better for
the pitcher.**

- Each pitch gets an outcome: ball, called strike, swinging strike, foul, walk,
  HBP, strikeout, single, double, triple, home run, field out.
- Its value is the league mean of `delta_run_exp` for that outcome in that
  count. A cell under 50 pitches falls back to the outcome's mean across counts.
- Balls in play take the actual result. No xwOBA substitution.

Runners and outs are stripped. Count stays, because valuing each outcome
within its count is what keeps a pitch from being rewarded for when it is
used. Known cost: a bloop single and a rocket count the same.

## 3. Inputs

| input | source | notes |
|---|---|---|
| velo | `release_speed` | |
| IVB | `pfx_z * 12` | inches |
| HB | `pfx_x * 12` | inches, mirrored for LHP: arm side positive, glove side negative |
| release height | `release_pos_z` | feet |
| release side | `release_pos_x` | feet, mirrored for LHP |
| velo gap | `release_speed` minus primary fastball mean velo | primary fastball reads about 0 |
| batter side | same or opposite hand as pitcher | 0/1 |

- **Primary fastball:** the pitcher's most-thrown of FF, SI, FC that season. A
  pitcher with none gets a missing velo gap, which XGBoost routes natively.
- **No pitch type input.** The model grades shape. Statcast labels are used
  only to report grades and to define the gate 3 and gate 4 groups.
- **Not inputs:** count, location, spin, extension, arm angle, VAA, IVB and HB
  gaps.

## 4. Model

**One XGBoost regressor for every pitch, settings fixed now.**

| setting | value |
|---|---|
| objective | squared error |
| `max_depth` | 4 |
| `eta` | 0.05 |
| rounds | 400, no early stopping |
| `min_child_weight` | 100 |
| `subsample` | 0.8 |
| `colsample_bytree` | 1.0 |
| seed | 3 |

No tuning of any kind.

## 5. Grade

1. **Score each pitch twice,** once as if thrown to a same-side hitter and once
   to an opposite-side hitter.
2. **Split grades:** average each side's predictions per pitcher and pitch type.
   vs RHH and vs LHH map from same and opposite by the pitcher's hand.
3. **Overall grade:** the 50/50 average of the two, so a grade is not rewarded
   for the hitters a pitcher happened to face.
4. **Scale:** Stuff+ = 100 + 10 × (grade − μ) / σ.
   - μ: mean overall prediction across all pitches (100 = the average pitch
     thrown, any type).
   - σ: SD of overall grades across pitcher × pitch-type seasons with 100+
     pitches.
   - The split grades use the same μ and σ.
5. **No shrinkage.** The pitch count is shown beside every grade.

Sweepers will likely average above 100 and sinkers and changeups below. That is
the expected shape of a league-wide scale and gets stated on the page.

## 6. Validation scheme

- **5 folds by pitcher,** `set.seed(3)`, over 2022 to 2025. Every pitch is
  graded by a model that never saw that pitcher.
- **Fit inside the training folds only:** the run-value table (section 2) and
  μ and σ (section 5). The primary fastball is the pitcher's own, not a league
  fit, so it needs no fold.
- **Population:** pitcher × pitch type with 100+ pitches in both season t and
  t+1. 3,486 pairs: 1,158 (2022→23), 1,155 (2023→24), 1,173 (2024→25).
- **RV/100:** the section 2 target averaged per pitcher × pitch type, per 100
  pitches.

## 7. Gates (all four must pass)

1. **Predictive.** r(Stuff+_t, RV/100_t+1) > r(RV/100_t, RV/100_t+1), pooled
   over the three pairs. Pitcher-clustered paired bootstrap, 1,000 replicates;
   the 95% CI on the difference excludes zero.
2. **Every family.** The same difference has a positive point estimate in each
   reporting group: fastball (FF, SI, FC), breaking (SL, ST, SV, CU, KC),
   offspeed (CH, FS, FO).
3. **Not just pitch type.** Stuff+_t and RV/100_t+1 are each centered on their
   pitch type's mean, then one correlation is computed across FF, SI, SL, ST, CU
   and CH. Its bootstrap 95% CI excludes zero, and at least 5 of the 6 types
   have a positive within-type r. Pairs per type: FF 991, SL 558, SI 551, CH 417,
   CU 257, ST 245. A model that only learned "sweepers are good" grades every
   sweeper about the same, so its within-type r sits near zero.
4. **Known answers.** At least 10 of the 15 elite entries (section 8) grade in
   the top 20% of their pitch type that season, and at least 3 of the 4 weak
   entries in the bottom 20%. Percentiles are among pitcher-seasons with 250+
   pitches of that type, using out-of-fold grades.
   - **Forkball exception:** only one pitcher-season in 2022 to 2025 has 250+
     FO (Senga 2023), so his FO is ranked against the combined FS and FO pool for
     2023.

### 7a. Changeup fallback, declared now

If CH fails gate 3's within-type check, **one** fix is allowed: add IVB and HB
gaps to the primary fastball as inputs, refit, and rerun all four gates. If CH
still fails, the shot fails. A pass through the fallback is reported as such.

### 7b. Bugs versus findings

A grade that is wrong because of a bug (a lefty not mirrored, a bad fastball
baseline) gets the bug fixed, documented, and the shot rerun. A grade that
looks wrong with correct code is a finding for the writeup; settings and inputs
do not change.

## 8. Known-answer list

Signed off by Jonathan 2026-10-19. Checked against Statcast labels and pitch
counts only: every entry has 250+ pitches of that type that season.

Elite (top 20% of type expected):

| pitcher | pitch | season | pitches |
|---|---|---|---:|
| Spencer Strider | FF | 2023 | 1,826 |
| Mason Miller | FF | 2024 | 646 |
| Jacob Misiorowski | FF | 2025 | 642 |
| Clay Holmes | SI | 2022 | 784 |
| Emmanuel Clase | FC | 2024 | 765 |
| Spencer Strider | SL | 2023 | 1,048 |
| Mason Miller | SL | 2024 | 358 |
| Shohei Ohtani | ST | 2023 | 733 |
| Tyler Glasnow | CU | 2024 | 364 |
| Blake Snell | CU | 2023 | 627 |
| Devin Williams | CH | 2023 | 549 |
| Tarik Skubal | CH | 2024 | 767 |
| Paul Skenes | FS | 2024 | 603 |
| Kodai Senga | FO | 2023 | 664 |
| Jhoan Duran | FS | 2024 | 277 |

Weak (bottom 20% of type expected):

| pitcher | pitch | season | pitches |
|---|---|---|---:|
| Kyle Hendricks | SI | 2024 | 757 |
| Zack Greinke | FF | 2023 | 592 |
| Patrick Corbin | SI | 2023 | 1,213 |
| Wade Miley | FF | 2023 | 364 |

## 9. What the test can resolve

Estimated before running. With 3,486 pairs, the gate 1 CI half-width should be
about 0.02 to 0.03. Shape-based grades are expected to beat observed run value
by far more (FanGraphs reports Stuff+ reliable at about 80 pitches; observed run
value needs several hundred), so a narrow pass is itself a warning. At ~250
pairs, a single type's within-type r carries about ±0.06 of noise, which is why
gate 3 pools the types and allows one miss.

## 10. Reported, not gated

1. **Baseline to beat:** a linear model on velo, IVB and HB, same folds and
   target. Gate 1 and gate 3 statistics for it, beside the main model.
2. **Stabilization curve:** split-half reliability of grades at 25, 50, 100 and
   200 pitches.
3. **What drives the grades:** feature importance, plus worked examples for
   three known-answer pitches.
4. **Sensitivity (veto only):** refit at `max_depth` 6. If any gate verdict
   flips, the result is UNRESOLVED.
5. **Mean Stuff+ by pitch type,** so the league-wide shape is shown, not
   assumed.
6. **Pitcher level:** usage-weighted Stuff+ against same-season K-BB%, with v5g
   computed the same way on the same pitchers. Also the v5g vs this-model grade
   correlation and gate 1 for v5g, as the measured price of simplicity.
7. **Eye-test leaderboards** (only if the gates pass, for 2026): one per pitch
   type, top and bottom 15, 250-pitch minimum, for 2025 and for 2026 through
   2026-09-27 from the season store. Each row shows the grade, pitch count and
   inputs. Plus one table per type of average vs RHH minus vs LHH.
8. **Source comparisons** (2026 only if the gates pass): FanGraphs Stuff+ on its
   2026-03-26 to 2026-08-17 export window, and tjStuff+ for 2024. Same pitchers,
   same windows, 250+ pitches. Spearman rank r per pitch type and the ten largest
   disagreements by name.

## 11. Non-statistical cost

- **Chosen before fitting, not up for re-litigation by the results:** seven
  inputs, one model, no sub-models, no shrinkage, fixed settings. v5g has 13
  features, two fitted sub-models, a shrinkage constant and several mode flags.
- **App cost:** xgboost and one model file join the app's data build in GitHub
  Actions. Scoring happens at build time, so the deployed app does not need
  xgboost.
- **Gain:** Stuff+ follows the user's date window and Batter side selector, and
  the column is Jonathan's own model.

## 12. Out of scope

- App integration (a separate step after the gates pass).
- Production fit on 2022 to 2026 for the app.
- Coors and other park effects on movement: a known bias, not sized here.
- Location+, Pitching+, contact-quality models.
