# Validation

v1 failed its pre-registered test. v2 passed a different one on a held-out season. Each result below links its log.

## What "within-type" means

Three versions appear, and they aren't comparable:

- **v2 pooled** (`within_r`): grade and outcome centered within pitch type and season, then one correlation.
- **v2 by type** (`validity()$by_type`): one pitch type, not centered by season.
- **v1 gate 3** (`within_type_r`): centered within pitch type across all seasons, against next season's run value.

v2 uses eight pitch types with 250+ pitches: FF, SI, FC, SL, ST, CU, CH, FS. Rows are pitcher, season and pitch type. The logs label these rows "pitches"; they aren't individual pitches.

## v1: run value, FAIL

Target: run value averaged by count and outcome. Test: does this season's grade predict next season's run value better than this season's results do? Run once, at commit `9ac2e0b`, under [its pre-registration](preregistration/v1.md). [Log](../results/v1_run.log).

| Gate | Result | Pass? |
|---|---|---|
| 1. Beats this season's results | -0.016 [-0.063, 0.033] | No |
| 2. Beats them in every family | Fastball 0.011, breaking 0.021, offspeed -0.178 | No |
| 3. Within-type r above zero, 5 of 6 types positive | 0.155 [0.116, 0.194], 6 of 6 | Yes |
| 4. Known answers: 10 of 15 elite, 3 of 4 weak | 12 of 15, 3 of 4 | Yes |

A depth-6 refit reached the same verdict. A linear baseline on velo, IVB and HB did worse (gate 1 -0.104, gate 3 0.087). The changeup fallback never ran: it needed gate 3 to fail.

Before the run, a line-by-line check matched the plan to the code. One deviation was kept on purpose: a missing known-answer entry stops the run, instead of being dropped and the bar scaled.

## v2 development

On 2022-2025 only, out of fold, with 2026 untouched. "2025" compares with FanGraphs on the same pitcher-pitch types. [Logs](../results/dev/).

| Change | Whiff r | 2025: ours vs FanGraphs | Kept? |
|---|---|---|---|
| v1 inputs, run-value target (baseline) | 0.282 | 0.234 vs 0.512 | Baseline |
| + IVB and HB gaps | 0.274 | 0.220 vs 0.512; changeups fell 0.276 to 0.237 | No |
| + spin rate, one model | 0.274 | 0.227 vs 0.512 | No |
| + spin rate, three family models | 0.231 | 0.198 vs 0.512; cutters fell 0.29 to 0.01 | No |
| **Whiff target**, v1 inputs | **0.423** | 0.393 vs 0.512 | **Yes** |
| Whiff target + **axis differential** | **0.465** | 0.450 vs 0.512 | **Yes: v2** |

The axis differential cleared a +0.02 rule for adding an input, though splitters slipped (0.437 to 0.415). These experiments had no fixed count and weren't pre-registered; the logs hold what was tried.

**Benchmark check** ([log](../results/benchmark_check.log), on v1 grades, not reproducible without the two external files). FanGraphs had a real edge on whiffs even out of time (0.452 vs 0.258), while a second public model was close to ours (0.285 vs 0.262). So the first exam bar, "within 0.05 of FanGraphs," was replaced after v1 and the second public model both missed that distance on 2024-2025.

## 2026 exam: PASS

**The bar.** 0.38 was set at `9f31a8a`, when development stood at 0.42 with the whiff target alone: it allows normal season-to-season wobble, not collapse. 2026 data and FanGraphs' 2026 grades existed then, but this model had not scored 2026.

Frozen at `dda6607`. The [pre-registration](preregistration/v2.md) fixes the model and the bar. Between freeze and run, two commits landed before any 2026 result: the exam script (`0b6a7ef`) and a cleaning fix for mismatched column types found in the dry run (`d97a422`). The dry run reports structure only. The exam ran at `d97a422`. [Log](../results/v2_exam.log).

| | |
|---|---|
| **Pooled within-type whiff r, bar 0.38** | **0.518, 982 rows** |
| Run value on swings | 0.281 |
| By type | SI 0.65, FC 0.64, SL 0.60, FF 0.53, CH 0.51, FS 0.48, CU 0.42, ST 0.33 |
| FanGraphs, same 767 rows, through 2026-08-17 | 0.497 vs 0.483 (no sweeper column there, so ST compares with its SL) |
| Split-half reliability, 25 / 50 / 100 / 200 pitches | 0.992 / 0.996 / 0.998 / 0.999 |
| `spin_axis` missing | 0.16% |

**How to read 0.518.** It's above development's 0.465, and recognition is a likely contributor, not measured: the final model trained on all four seasons, and most 2026 pitchers appear there. Returning pitchers score 0.522 and new pitchers 0.441, with a pitcher-clustered interval of 0.20 to 0.65 on 57 rows, so that figure is imprecise ([log](../results/post_exam_checks.log)). Development's 0.465 is the stricter estimate.

**Known answers,** on out-of-fold 2022-2025 grades: 10 of 15 elite, 4 of 4 weak. The misses are Clase's cutter, Strider's slider, Snell's curveball, Skenes's splitter and Duran's splitter. The list is partly circular, since reputations are partly results, and some of those reputations are about weak contact, not whiffs. Duran's was a poor pick for a whiff metric.

## Follow-up checks

Asked after the exam, on data it had used, so they're descriptive. None changed the model. [Log](../results/post_exam_checks.log).

- **Naive baselines.** Velocity alone reaches 0.160. Last season's whiff rate reaches 0.614 against Stuff+'s 0.525 on the same 759 rows. For a pitcher with history, past results describe whiffs better. Stuff+ earns its place where there's no history.
- **FanGraphs on both outcomes,** same 767 rows: whiff per swing 0.497 vs 0.483, run value on swings 0.259 vs 0.280.
- **Location.** Grade vs zone rate within pitch type, 100+ pitches, is weak and mostly negative (0.02 to -0.25 on the main types). Better shapes get thrown in the zone a little less.
- **Platoon split.** Predicted before fitting: same-side advantage largest for ST and SL, smallest for CU and FS. Partly right. FC (0.049) and ST (0.048) lead and SL follows (0.030). CU (0.009) and KC (0.005) are small, FS (0.019) isn't. Sinkers run the other way (-0.006).
- **Duran's splitter** ranks near the bottom in whiff per swing every season (19th of 23, 32nd of 34, 31st of 33, 25th of 33), and grades 81. The grade matches what it measures.
- **Tyler Rogers's sinker** gets 12% whiffs per swing (115th of 171) and grades 86.
- **Release height is one-sided on four-seamers.** Lowest decile 25.4% whiffs, top three about 20%, even though high slots carry more ride (17 inches vs 13). There's no U-shape, so being unusual isn't what helps; a low slot is. Release side leans the other way: 23.5% at the widest deciles vs about 21%.
- **Schlittler and Ekness** are the limit of that proxy. Same velocity, 108 with 35% whiffs and 128 with 24%.

## Tests

`Rscript tests/run_all.R` runs each file in its own process and prints PASS, FAIL or SKIP.

| File | Checks | Needs data |
|---|---|---|
| `test_features.R` | Mirroring, velo gap rules, axis differential, outcome mapping, scale constants | No |
| `test_leaks.R` | No pitcher in two folds; held-out pitchers would have moved the run-value table (up to 0.039 runs, [log](../results/leak_test.log)), every held-out pitch is valued | Yes |

A check on the code itself ([log](../results/reproduction_check.log)): the scripts in this repo, rerun from raw inputs on the build machine, reproduce both cleaned files (`identical()`), the model file and the app's two files byte for byte (apart from the scale file's build date), the app's parity fixture, and the exam log apart from memory lines.

## Not validated

- **Next-season prediction under v2.** Reported only: v2's predictive edge on run value is -0.086 ([log](../results/dev/axis_differential.txt)). A descriptive grade shouldn't be read as a forecast.
- **Depth sensitivity under v2.** The depth-6 check ran on v1 only.
- **Extension as an input,** and spin, movement gaps and family models under the whiff target.
- **Park effects.** A Coors bias is known and not sized.
- **A later version.** 2026 is spent as an exam, so any new version would need a new season.

## Pre-registration notes

v1 carries dated amendments from before its run. v2 gained reported checks before the exam (`0b6a7ef`) and a dated note after it (`3b26a9b`). Neither was otherwise edited, so they use old names:

- `02_clean.R` is now `scripts/clean_pitches.R`, `run_shot.R` is `scripts/run_v1.R`, and `exam_v2.R` is `scripts/run_v2_exam.R`.
- `DECISIONS.md`, `ITERATIONS.md`, and `REVIEW.md` were working logs, now folded into these docs and available in git history.
- "v5" and "v5g" are an earlier, more complex build that isn't in this repo.
- "Council" is an adversarial review of the plan, run with AI reviewers.
