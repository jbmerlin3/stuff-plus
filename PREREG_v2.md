# v2 exam: frozen 2026-10-20, before any 2026 result

v1's pre-registration (PREREG.md) and its FAIL stand as recorded. v2 was
developed on 2022-2025 only (ITERATIONS.md); this document freezes it and fixes
the one exam on 2026. Decisions behind each item are in DECISIONS.md.

## Frozen model

- **Target:** whiff on swing. Trained on swings only (swinging strike, blocked
  swinging strike, foul tip, foul, in play); label 1 = whiff (first three).
- **Inputs (8):** velo, IVB, HB (arm side positive), release height, release
  side (arm side positive), velo gap to the hardest fastball (10% + 20 pitches,
  else most-thrown), batter side (same/opposite), axis differential (movement
  axis minus measured spin axis, lefties mirrored). No pitch type, count,
  location, spin rate or extension.
- **Model:** one XGBoost, `binary:logistic`, depth 4, eta 0.05, 400 rounds,
  min_child_weight 100, subsample 0.8, colsample 1.0, seed 3.
- **Grade:** every pitch scored against both batter sides, averaged 50/50;
  mean predicted whiff probability per pitcher and pitch type; 100 scale with
  μ and σ from the final fit (σ = SD across pitcher-type seasons with 100+).
- **Final fit:** all 2022-2025 swings. Never sees 2026.

## The exam

- **Data:** `data/holdout/pitches_clean_2026.rds`, cleaned by the same
  `02_clean.R` (709,733 pitches, 2026-03-25 to 2026-09-27).
- **Pass bar:** pooled within-type correlation between the 2026 grade and 2026
  whiff per swing, centered within pitch type, over FF, SI, FC, SL, ST, CU, CH,
  FS with 250+ pitches: **at least 0.38.** Development value: 0.465.
- **Reported, not gated:** run value on swings; each pitch type's r; FanGraphs
  Stuff+ on the same pitches over its 2026-03-26 to 2026-08-17 export window;
  2026 leaderboards by pitch type with FanGraphs alongside.
- **Also reported (added after the council, still before any 2026 result):**
  - **Face validity:** the signed-off known-answer list (PREREG.md section 8)
    on v2's out-of-fold 2022-2025 grades: share of elite entries in the top 20%
    and weak entries in the bottom 20% of their type that season (250+ pitches;
    FO ranked with FS).
  - **Reliability:** split-half correlation of 2026 grades at 25, 50, 100 and
    200 pitches.
  - **Data checks:** share of 2026 pitches missing `spin_axis` (and so the axis
    differential). Fastball baselines and axis differentials for 2026 are built
    from 2026's own pitches.
- **One run.** A true bug (code doing something other than this document says)
  is fixed, documented, and rerun. A disappointing number is a finding.

## Note, 2026-10-20 (after the exam)

The display scale changed to per-group 100 (fastball, offspeed, hard breaker,
soft breaker). The exam's verdict is unaffected: it ran on raw predictions, and
the model is unchanged.
