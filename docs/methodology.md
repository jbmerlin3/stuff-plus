# Methodology

Stuff+ v2 grades how often a pitch's shape misses bats when swung at. Numbers are on 2022-2025 unless they say otherwise. Results and their logs are in [validation](validation.md).

| Decision | Choice | Rejected | Evidence | Known limit |
|---|---|---|---|---|
| Purpose | Nastiness: shape only, without hitter, situation or location | Pitch value | v1's run-value model failed its bar | Doesn't reward weak contact |
| Target | Whiff on swing, swings only | Run value by count and outcome | Within-type whiff r 0.423 vs 0.282; run value on swings unchanged (0.216 vs 0.213) | Called strikes aren't targeted; whiffs on chase swings count, so some location gets in |
| Inputs | Velo, IVB, HB, release height, release side, velo gap, batter side, axis differential | Pitch label, count, location, spin rate, extension, arm angle | Sections below | Release height misfires at the extremes |
| Structure | One model, shape only | Label as input; separate family models | Family models lost, tested under run value with spin rate (0.231 vs 0.274) | Labels still set the display group |
| Settings | Depth 4, eta 0.05, 400 rounds, fixed in advance | Tuning, grid search | Tuning gains in an earlier, more complex build (+0.017 r) didn't replicate | Shallow trees predict flat for rare shapes |
| Validation | 5 folds by pitcher; 2026 held out | Holding out a season only | Pitcher folds stop a model grading a pitcher from memory | One clean exam season |
| Scale | 100 within pitch group, SD 10 | League-wide | Sections below | Grades don't compare across groups |
| Sample size | Grade shown at any count, with the count | Hiding under 10 pitches; shrinkage | Split-half 0.99 at 25 pitches, 2026 | A 1-pitch grade is noise |

## Purpose

Stuff+ describes the expected value of a shape, not how the pitch performed. Performance includes location, which the pitcher controls and a separate metric should measure. The grade is descriptive: it isn't a projection of a pitcher's results, and the 50/50 overall grade describes a pitch, not a pitcher's mix of hitters.

## Target

Trained on swings: swinging strike, blocked swinging strike, foul tip, foul, in play. Label 1 is a whiff, the first three. Grades average the prediction over every throw, not only swings.

Why it changed: on 2025, against FanGraphs on the same pitcher-pitch types, v1 was far behind on whiff per swing (0.234 vs 0.512), and no added input moved that gap. It came from what the model aimed at. The rule for the choice was the higher within-type whiff r on development data, since the purpose is nastiness, with only the winner taking the exam. Run value stays in the code as v1.

The cost is that sinkerballers grade low. That's accurate for the word nastiness, and it isn't a measure of value.

## Inputs

| Input | Definition | Why |
|---|---|---|
| `release_speed` | Velocity | Biggest single lever |
| `ivb` | `pfx_z` in inches | Ride or drop |
| `hb` | `pfx_x` in inches, arm side positive for both hands | Same sign means the same thing for both hands; glove-side pitches stay negative |
| `release_ht` | `release_pos_z` | Carries arm slot without a separate input |
| `release_side` | `release_pos_x`, arm side positive | Same |
| `velo_gap` | Velocity minus the pitcher's hardest FF, SI or FC thrown 10%+ and 20+ times that season, else his most-thrown fastball | Hitters time the hardest heater. Most-thrown alone made a cutter-first pitcher's changeup look faster than his fastball. Fallback applies to 144 of 3,217 pitcher-seasons |
| `same_side` | Batter on the pitcher's side | Sweepers depend on it; every pitch is scored both ways |
| `axis_diff` | Movement axis minus measured spin axis, lefties mirrored | A gap means something besides spin moved the ball, usually seam-shifted wake. Curveballs sit near 0, as a calibration |

**Left out:**
- **Pitch label.** It's a summary of the shape, so it would be a shortcut. Labels reach the model only by choosing the fastball baseline for `velo_gap`, and fastballs get a gap near zero, which tells the model "fastball" without a label. Batter side is allowed because it's context, not a summary.
- **Spin rate.** No gain when tested, under the run-value target only. `spin_axis` is used, through the axis differential; 0.16% of 2026 pitches are missing it and XGBoost routes them.
- **IVB and HB gaps.** No gain and changeups got worse, also under the run-value target only.
- **Extension.** A judgment call, and a bet rather than a finding: it was never tested as an input. Release y is extension under another name. A later check on 2026 four-seamers found almost no link to whiffs beyond the grade at 250+ pitches (partial r 0.006) and a small one at 50+ (0.081).
- **Count and location.** Stuff+ is meant to exclude them.

**Gyro caveat.** The axis differential runs largest on sweepers, sliders and cutters (median 27 to 31 degrees in 2026, against 9 on four-seamers and curveballs). Those pitches carry heavy gyro spin, which makes the measured 2D axis less meaningful, so part of their gap is measurement. It helped sinkers and four-seamers most and sweepers barely.

## Model

One XGBoost, `binary:logistic`, depth 4, eta 0.05, 400 rounds, `min_child_weight` 100, subsample 0.8, all inputs in every tree, seed 3. Under logistic loss `min_child_weight` counts p(1-p), so 100 means roughly 500 swings per leaf, not 100.

One model, because a family setup means separate settings, every feature decision made several times, and judgment calls on where cutters belong. It also lost when tested, under the run-value target with spin rate. A rare shape gets graded like its nearest common neighbor, which is a limit of shallow trees.

**Both sides.** Each pitch is scored against a same-side and an opposite-side hitter. Those are the vs RHH and vs LHH grades, and the overall is their 50/50 average. Weighting by hitters actually faced would reward a lefty specialist for usage, not stuff. Splits rest on about half the sample.

## Scale

Stuff+ = 100 + 10 x (grade - mu) / sigma, within group: fastball (FF, SI, FC), offspeed (CH, FS, FO), hard breaker (SL), soft breaker (ST, SV, CU, KC).

| Group | mu | sigma |
|---|---|---|
| Fastball | 0.204 | 0.050 |
| Offspeed | 0.316 | 0.039 |
| Hard breaker | 0.329 | 0.042 |
| Soft breaker | 0.314 | 0.039 |

mu is the mean prediction over all 2022-2025 pitches in the group. sigma is the SD across pitcher, season and pitch type rows with 100+ pitches: one SD is one SD for the unit people read. The scale is display only. The model and every validation number use raw predictions. KC folds into CU and FO into FS when grades go to the app, because the app joins on those labels.

**Reversals.**
- First, one league-wide scale. Breaking balls sat above fastballs because they miss more bats, with sinkers centered near 85 and four-seamers near 96, which isn't how a scouting app reader takes a 100.
- Then, the group scale above. 2026 group medians are 102 to 104 ([log](../results/group_medians_2026.log)).

**Cost of the group scale.** A 110 sinker and a 110 sweeper are each well above their group, not equally nasty. SL and ST sit in different groups, so a label change between them can move a grade about 4 points. The fastball sigma includes the gaps between FF, SI and FC averages, so fastball grades run tighter than a within-type SD would.

## Sample size

A grade is the plain average of its pitches' predictions, shown with its pitch count. Shrinking toward a type average would put the label back into a grade from a model built to ignore it, and pull in real outliers. Split-half reliability in 2026 is 0.99 at 25 pitches, which shows the grade is stable, not that it's correct.

## Cleaning

2,853,422 pitches to 2,827,868 ([log](../results/cleaning_2022_2025.log)):
- Position players pitching are out: pitcher-seasons more than half FA or EP, or averaging under 80 mph, except nine hand-checked soft-tossers (the ninth, Tom Cosgrove, was added when 2026 was cleaned, before the freeze; it doesn't change the 2022-2025 count). 245 pitcher-seasons, [listed](../results/position_players_excluded.csv).
- Bunts, pitchouts and automatic balls and strikes are out.
- Pitch types kept: FF, SI, FC, SL, ST, SV, CU, KC, CH, FS, FO. Forkballs matter: Senga's is tagged FO and would otherwise vanish.
- Errors count as outs, so the contact stays and the fielder goes. Sacrifice bunts are dropped; bunt hits can't be identified.

2026 runs through the same script (714,111 to 709,733). Fastball baselines and axis differentials for 2026 use 2026's own pitches, so the baseline reflects the full season.
