# Stuff+ v2: decisions and evidence

How often a pitch's shape misses bats when swung at. Development 2022-2025,
exam 2026 (held out until the model was frozen). Full history: DECISIONS.md.

| Decision | Choice | Rejected | Evidence | Known limit |
|---|---|---|---|---|
| Purpose | Nastiness: shape only, hitter, situation and location agnostic | Pitch value (run value) | v1 run-value model failed its pre-registered bar | Does not reward weak contact (Tyler Rogers, Duran's splitter) |
| Target | Whiff on swing (1 = whiff, 0 = contact), swings only | Run value by count and outcome | Within-type whiff r 0.423 vs 0.282 for run value; run value on swings unchanged (0.216 vs 0.213) | Called strikes and chases are location, so excluded by design |
| Inputs | Velo, IVB, HB, release height, release side, velo gap to hardest fastball, batter side, axis differential | Pitch label, count, location, extension, arm angle, release y | Each in DECISIONS.md | Release height stands in for approach angle and misfires at the extremes (Schlittler under, Ekness over) |
| No pitch label | One model sees shape only | Label as input; separate family models | Family models lost (0.231 vs 0.274), as in v5 | Labels still set the display group |
| Mirror lefties | Arm side positive for both hands | Raw Statcast sign | Audit: hands match, arm-side pitches positive | None |
| Velo gap baseline | Hardest FF/SI/FC thrown 10%+ and 20+ times, else most-thrown | Most-thrown fastball | Fixed cutter-first bug (Brazobán's changeup read faster than his fastball) | Tiny-sample seasons use the fallback (144 of 3,217) |
| Axis differential | Movement axis minus measured spin axis, lefties mirrored | Leave out | +0.042 whiff r, cleared the pre-set +0.02 rule; curveballs ~0 as calibration | Gyro-heavy sliders and cutters inflate it partly through measurement |
| Batter side | Input; every pitch scored vs both sides, overall = 50/50 | One grade only | Sweepers split by side, curves neutral, as predicted before fitting | Splits rest on half the sample |
| Extension | Out | In | Explains nothing about four-seam whiffs beyond the grade (partial r 0.01) | Not tested as a model input |
| Spin rate, IVB/HB gaps | Out | In | No gain when tested (under the earlier run-value target) | Not re-tested under the whiff target |
| Model | One XGBoost, depth 4, eta 0.05, 400 rounds, min leaf 100, fixed in advance | Tuning, grid search | v5 tuning gains (+0.017) did not replicate; depth 6 reached the same v1 verdict | Shallow trees predict flat for rare shapes |
| Validation | 5 folds by pitcher on 2022-2025; 2026 untouched until frozen | Hold out a season only | Leak tests pass; pitchers never seen score 0.441 in 2026 | Only one clean exam season; v3 cannot be fairly tested |
| Exam bar | Within-type whiff r >= 0.38 on 2026, set before 2026 | Within 0.05 of FanGraphs | **2026: 0.518, PASS.** Same pitches vs FanGraphs: 0.497 vs 0.483 | 0.518 includes recognizing returning pitchers |
| Scale | 100 = average within group (fastball; offspeed; hard breaker SL; soft breaker ST, SV, CU), SD 10 within group | League-wide 100 | Display only; 2026 group medians 102 to 104 | Grades do not compare across groups; SL vs ST label can move a grade ~4 points |
| Sample size | Grade shown at any count, count beside it | Hide under 10 pitches | Shape grades 0.99 split-half at 25 pitches | 1-pitch grades are noise |
| Cleaning | Position players, bunts, pitchouts, automatic calls out; errors as outs; sac bunts dropped | Keep all | Funnel 2,853,422 to 2,827,868, logged | Bunt hits cannot be identified |
