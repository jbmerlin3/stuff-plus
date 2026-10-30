# Stuff+

An XGBoost model that grades every MLB pitch on its characteristics and release point: how often that shape misses bats when a hitter swings, with hitter, count and location left out. Grades run on the 100 scale and appear in the Stuff+ column of the [Pitcher Arsenal app](https://jonathanmerlin.shinyapps.io/pitcher-arsenal/) ([code](https://github.com/jbmerlin3/statcast-arsenal-app)).

Trained on 2022-2025 swings. Frozen, then tested once on the held-out 2026 season. Built in R.

## Results

**The 2026 exam passed: within-type correlation with whiff per swing was 0.518 against a bar of 0.38, set before any 2026 result existed.**

| Check | Result | Read it as |
|---|---|---|
| 2026, all pitchers | 0.518 | Most of these pitchers were in training, which likely helps |
| 2026, pitchers new to the data | 0.441 (57 pitcher-pitch types, interval 0.20 to 0.65) | The fairer test, on a small sample |
| 2022-2025, out of fold | 0.465 | Every pitch graded by a model that never saw that pitcher |
| 2026, velocity alone | 0.160 | The model adds a lot beyond velocity |
| 2026, last season's whiff rate, same 759 rows | 0.614 vs 0.525 | Past results beat Stuff+ for a pitcher with history. The grade's use is where there's no history: a new pitch, a call-up, a changed grip |
| 2026, run value on swings | 0.281 | Lower by design: the target is whiffs, not value |
| FanGraphs Stuff+, 2026 through Aug 17, same 767 rows | Whiffs 0.497 vs 0.483; run value on swings 0.259 vs 0.280 | About even, on the outcome this model was trained for |
| FanGraphs Stuff+, 2025, same 977 rows | Whiffs 0.450 vs 0.512 | Behind in the last development season |

The correlation is same-season, on an outcome the model trained on in other seasons. It shows the grade describes whiffs. It doesn't predict next year: v2's edge on next-season run value is -0.086, worse than the -0.016 that failed v1.

Highest 2026 grades, 250+ pitches. 100 is the average pitch in its group.

| Pitch | Top grades |
|---|---|
| Four-seam | Ekness 128, Misiorowski 125, Scott 125 |
| Sinker | Hader 114, Dodd 107, Whitlock 102 |
| Cutter | Bello 136, Alvarado 133, Alcantara 130 |
| Slider | Miller 132, Ashcraft 129, Doval 126 |
| Sweeper | Meyer 139, Hicks 125, Cavalli 124 |
| Curveball | Misiorowski 142, McLean 140, Varland 139 |
| Changeup | Morejon 133, Soriano 121, Baker 121 |
| Splitter | Smith 130, Sasaki 123, Gilbert 122 |

The full board, down to 50 pitches, is in [results/leaderboard_2026.csv](results/leaderboard_2026.csv). The exam covered only 250+, so small-sample rows near the top (146 on 57 pitches) aren't validated.

**Where it's wrong, or measures something else:**
- It doesn't reward weak contact. Tyler Rogers's sinker grades 86 and Jhoan Duran's splitter 81, and both pitches are good. Their whiff rates are ordinary, so these grades describe whiffs correctly and say little about value.
- Release height stands in for approach angle and misfires at the extremes. Cam Schlittler's four-seam grades 108 with 35% whiffs per swing; Josh Ekness's grades 128 with 24%.
- Sweepers are the weakest pitch type (r 0.33).
- Sinkers grade low (median 88) because they share a scale with four-seamers and miss fewer bats. Compare sinkers with sinkers.

## How it works

**Target.** Whiff on swing. Every pitch thrown is then scored, and a grade is the average predicted whiff probability over all of a pitch's throws.

**Inputs.** Velocity, induced vertical break, horizontal break, release height, release side, velocity gap to the pitcher's hardest fastball, batter side, and axis differential (movement axis minus measured spin axis). The model never sees the count or the location. Pitch labels reach it only through the fastball baseline.

**Validation.** Five folds by pitcher on 2022-2025, then one exam on 2026. Both versions were pre-registered: the [v1](docs/preregistration/v1.md) and [v2](docs/preregistration/v2.md) documents predate their results.

**v1 failed, and that changed the design.** v1 targeted run value and had to predict next season better than this season's results. It failed two of four gates and was recorded as a failure, not rerun. That result showed the bar and the purpose didn't match: this metric is meant to describe a pitch's nastiness. v2 changed the target to whiffs, added the axis differential, and passed its own bar. That's an easier test than v1's, and it's the main thing to weigh when reading the 0.518. v2 can't pass v1's test.

More detail:

- [Methodology](docs/methodology.md): every modeling decision, what was rejected, and its known limit.
- [Validation](docs/validation.md): v1's gates, the development log, the 2026 exam, the follow-up checks, and what hasn't been validated.
- [Changelog](CHANGELOG.md)

## Reproduce it

`renv.lock` pins the packages, against R 4.5.2.

```bash
git clone https://github.com/jbmerlin3/stuff-plus.git
cd stuff-plus
Rscript -e 'renv::restore()'
Rscript tests/run_all.R
```

Without data, `test_features.R` runs on small fixtures and `test_leaks.R` is skipped. The cleaned pitches are published as a release asset (286 MB, public Statcast data):

```bash
gh release download data-v2 --pattern pitches_clean.rds --dir data
gh release download data-v2 --pattern pitches_clean_2026.rds --dir data/holdout
Rscript scripts/run_v2_exam.R exam
```

The exam takes about 3 minutes on a laptop and about 4 GB of memory, and prints what's in [results/v2_exam.log](results/v2_exam.log). FanGraphs exports aren't redistributed, so that comparison is skipped unless they're in `data/external/`. The rerun matched on the machine that built it ([check](results/reproduction_check.log)); XGBoost output can differ slightly across machines and thread counts.

Scripts run from the repo root, in this order:

| Script | What it does | Needs |
|---|---|---|
| `pull_statcast.R` | Raw 2022-2025 Savant pull. Savant revises pitches, so a new pull won't match the stored data | Network |
| `clean_pitches.R` | Filters to model-ready pitches. 2026's raw file is the app repo's `season-store` release | Raw pull |
| `run_v1.R` | v1's pre-registered run | Cleaned pitches |
| `dev_experiment.R` | One v2 development experiment | Cleaned pitches |
| `run_v2_exam.R` | The 2026 exam | Cleaned pitches |
| `export_v2.R` | Final model and scale; with the app's path, also the files it reads | Cleaned pitches |
| `leaderboard_2026.R` | The 2026 board | `export_v2.R` |
| `post_exam_checks.R` | Follow-up checks | Exam and board |
| `parity_fixture.R` | The app's test fixture | `export_v2.R`, app path |
| `benchmark_check.R` | v1 against two public models | `run_v1.R`, external files |

## Repository layout

```
R/         features, target, model, folds, gates, validity, scale
scripts/   the pipeline and follow-up checks, run from the repo root
tests/     test files; run_all.R runs them
models/    the shipped model and its scale constants
results/   the logs and tables the docs cite
docs/      methodology, validation, pre-registrations
```
