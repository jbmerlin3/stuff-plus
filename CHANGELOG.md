# Changelog

Dated milestones, newest first, with the commit that records each.

## 2026-10-30: Repository cleanup

- Working notes folded into `docs/`; scripts moved to `scripts/`; comments trimmed; tests added. No grade changed: the cleaned code reproduces the model file, the app's files and the exam log.

## 2026-10-20: v2 ships

- Display scale moved from league-wide to per pitch group (`3b26a9b`).
- Grades exported to the Pitcher Arsenal app, replacing a FanGraphs export (`5906d67`).
- **2026 exam: PASS,** 0.518 against a 0.38 bar (run at `d97a422`, recorded in `f1c32ba`).
- Exam dry run found a column-type mismatch between the 2022-2025 and 2026 files; fixed in cleaning (`d97a422`). The dry run prints no 2026 result.
- Exam script and two reported checks added before any 2026 result (`0b6a7ef`).
- v2 frozen: whiff target plus axis differential (`dda6607`). Exam bar set at 0.38 (`9f31a8a`).
- Whiff target adopted over run value on development data (`9a3743e`).

## 2026-10-20: v1 fails

- v1 run, recorded as FAIL: gates 1 and 2 failed, 3 and 4 passed; the depth-6 check agreed (run at `9ac2e0b`; verdict and v2 rules in `b6094e0`).

## 2026-10-19: v1 pre-registered

- Target, inputs, settings, folds, gates and known-answer list fixed before any fit (`14e1e21`), with dated amendments before the run.

## 2026-09-10: Data

- Statcast inspection and cleaning scripts (`e2f2c5d`).
