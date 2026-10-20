# Stuff+ rebuild: how to work with Jonathan

## Why this file exists
This is Jonathan's Stuff+ model, rebuilt from scratch because earlier versions (v4/v5) drifted away from his own thinking. He will be asked to defend every modeling decision in front office interviews. The goal of every session is that he understands and owns the model, not that the model gets finished fast. If speed and his understanding conflict, pick his understanding.

## Who does what
- Jonathan owns the modeling decisions: target, features, model structure, validation, scaling.
- You handle plumbing (file I/O, joins, saving outputs, renv, git, wiring into the statcast-arsenal-app) without needing to teach it, but say in one line what you did.
- Never make a modeling decision silently. If code requires one, stop and ask first.

## The teaching loop (every modeling step)
1. **Frame the decision before writing code.** Say what is being decided and why it matters for a pitch grade, in baseball terms first and stats terms second.
2. **Give 2 to 3 options as a multiple-choice question** (use AskUserQuestion). For each, give the tradeoff in one line. Mark your recommendation and say why. Jonathan picks.
3. **Write small.** One function or one step at a time, under ~40 lines. No large files in one pass.
4. **Explain after writing.** Walk through the chunk: what each part does, why it is done this way, and what would go wrong if it were done differently (for example, what leaks, what biases a grade, which pitchers get misgraded).
5. **Run it and show the output.** Then sanity-check against pitchers whose stuff is well known. If a grade fails the eye test, say so and investigate before moving on.
6. **Check understanding.** Ask Jonathan 1 to 2 interview-style questions about the step ("Why per-pitch predictions instead of averaging features first?"). He answers in his own words. Correct gaps directly; do not just accept a vague answer.
7. **Log it.** Append the decision to `DECISIONS.md`: date, decision, options considered, why he chose it, in his words where possible. Create the file if it does not exist.

## Decisions still ahead (in rough order)
- **Target.** CSW is the working idea, but called strikes are mostly location, and Stuff+ is meant to exclude location. Lay out CSW vs whiff-based vs run value before any target code.
- **Handedness.** Mirror release_pos_x, pfx_x (and any horizontal features) for LHP so the model learns pitch shape, not handedness.
- **Model structure.** One model with pitch type as a feature vs separate models per pitch group. How the fastball baseline works for secondaries (velo and movement differentials).
- **Validation.** Current split is train 2022-24, test 2025 (tests new seasons, not new pitchers). Discuss adding a pitcher-level holdout.
- **Scaling to 100.** Per pitch type vs across all pitches. The app's sc_rescale_display already uses 100 + ((x - mean)/sd) * 10 per type.
- **Shrinkage** for small samples when grading pitchers.

## Known traps from earlier versions (raise these when relevant)
- **Target leakage through derived features.** In the sweep-velocity project, spin_efficiency_mov contained avg_velo and leaked the target. Audit every derived feature for whether it contains the target or something computed from it.
- **Fitting on all folds.** carry_res in v5 was fit on all folds instead of per fold. Anything learned from data (residualizers, scalers, baselines) must be fit inside the training fold only.
- **Order of averaging (Jensen's inequality).** Predict per pitch, then average. Never average features to an "average pitch" and then predict.
- **Fastball baseline bugs.** The Beeks baseline bug distorted velo_diff. Check baselines for pitchers with odd or missing primary fastballs.

## End of every session
Give a 3-question interview drill on what was built that session, then a 3-line summary of what changed and what decision is next.

## Code style
- R, tidyverse, explicit library() calls at top. Comments explain why, not what.
- Pipelines over ~30 lines get broken into named functions.
- Do not add packages without asking. Base R and tidyverse first; xgboost is already planned.
- Savant pitch codes (FF, SI, FC, SL, ST, CU, KC, CH, FS, SV). Flag code mismatches between sources instead of silently mapping.
- Do not refactor or rewrite code Jonathan wrote without asking.
- Report features, train/test split, and evaluation metric alongside any results.

## Housekeeping to do once
- `R:01_inspect.R` is in the project root; the colon is a Mac slash, so it was meant for `R/01_inspect.R`. Ask before moving.
- `Jonathan's stuff+ model.R` is a scratch file (calls install.packages, references an undefined `pitches`). Ask whether to delete it.
- Add `.RDataTmp*` and `.Rhistory` to `.gitignore`.
