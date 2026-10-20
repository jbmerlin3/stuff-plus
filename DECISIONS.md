# Stuff+ decisions log

One entry per modeling decision. Quotes are Jonathan's own words from the
session where he made the call. "Not discussed" means he accepted a
recommendation without the options being laid out; those are fair game to
revisit.

---

## 2026-10-19: Keep it simple

**Decision.** Few features, a simple target, no stacked sub-models.

**Options considered.** Keep the v5g design (13 features, two fitted
sub-models feeding the main model, shrinkage, several mode flags), or rebuild
small.

**Why.** "I'm pretty confident the model is too complicated. Needs to be
simpler. Include only the most important features and we need to make the
target variable simpler." Tuning gains in v5 (+0.017 r) were smaller than
year-to-year drift (0.054) and did not replicate.

---

## 2026-10-19: Target is run value averaged by count and outcome

**Decision.** Each pitch gets the league-average `delta_run_exp` for its
outcome (ball, called strike, whiff, foul, single, out, and so on) in its
count. Balls in play take the actual result. No xwOBA substitution.

**Options considered.**
- Whiff per swing: stable, mostly physics, but ignores weak contact and called
  strikes.
- Raw `delta_run_exp`: simplest, but grades the base-out situation, which the
  pitch does not control.
- Count-and-outcome average (tjStuff+ style xRV): removes base-out state, keeps
  ball-in-play luck.
- What teams do: separate models for swing, whiff, contact, and contact
  quality, combined into runs (BP StuffPro). Too many models for this build.

**Why.** He first wanted "just raw run value" or a published xRV. After
seeing that raw run value grades the runners on base, he chose the averaged
version as the one-model version of what a team does.

**Known cost.** A bloop single and a rocket count the same.

---

## 2026-10-19: Features

**Decision.** Velo, IVB, HB, release height, release side. Breaking and
offspeed models also get the velo gap to the pitcher's primary fastball.

**Options considered.** Public models (FanGraphs, BP StuffPro, tjStuff+,
Baseball America, FG Community xWhiff) all use velo, movement and release
point; most add extension and spin; FG, BP and tjStuff+ add velo and movement
gaps, BA uses velo gap only.

**Why, in his words.**
- "Take out extension."
- "Scratch extension and arm angle and use release height and release side
  instead." Release point carries arm slot without a separate input, the way BP
  uses release point and pitcher height.
- "I think velo_differential could be helpful for offspeed and breaking balls."
- Velo gap only, not IVB and HB gaps: "velo only." The movement gaps largely
  repeat raw movement (r 0.84 to 0.86 in v5g).
- He agreed with dropping spin, VAA and carry_res.

**Known risk.** Changeups lean on looking different from the fastball, and
only the velo gap is kept. A one-time fallback (add IVB and HB gaps to the
offspeed model) is pre-registered in case CH fails.

---

## 2026-10-19: Scale is league-wide 100, SD 10

**Decision.** 100 is the average pitch of any type, not the average of each
type.

**Options considered.** League-wide 100, or 100 per pitch type.

**Why.** "I know some models do 100 league wide and breaking balls, like
sweepers, typically grade higher than average, thus supporting the trend in
increased breaking ball usage and lower fastball usage." On pitches that grade
low: "Just let sinkers and prob CH too grade low and state that."

---

## 2026-10-19: SL and ST share a model, grade separately

**Decision.** SL, ST, SV, CU and KC train in one breaking-ball model with no
pitch-type feature. Grades are per Statcast pitch type, so a pitcher's SL and ST
get separate numbers. The within-type check (gate 3) covers FF, SI, SL, ST, CU
and CH.

**Why.** He asked whether SL and ST are grouped, then added ST and CU to the
check so the model has to separate good sweepers from bad ones, not just rate
sweepers as a group.

---

## 2026-10-19: One model, no pitch type feature

**Decision.** A single model for every pitch. Pitch type is not an input; the
model sees shape only. Fastballs get a velo gap near zero, which tells the
model "fastball" without a label.

**Options considered.**
- One model, no type: simplest, one set of settings, every pitch judged on
  shape (tjStuff+ style).
- Three family models: each family learns its own physics (BP StuffPro, FG
  Community xWhiff), but three sets of settings, every feature decision made
  three times, and judgment calls on where FC and KC belong.
- One model with type as a feature (FanGraphs style): simple, but the model can
  lean on the label ("sweeper = good") instead of the shape.

**Why.** Took the recommendation. His own v5 Phase 2A test already rejected
per-type architectures, and he had named the cost then: N sets of settings and
every future feature decision adjudicated N times.

**Follow-on.** The pre-registration still describes three family models; it
needs updating before commit. Gate 2 can keep the three families as reporting
groups.

---

## 2026-10-19: Mirror lefties

**Decision.** HB and release side are mirrored for LHP so arm side is positive
for every pitcher.

**Why.** "Mirror handedness for lefties." Without it, the model would have to
learn a lefty's changeup and a righty's changeup as two different shapes, and
half the data would be wasted on handedness instead of pitch shape.

**Correction he got.** Mirroring does not remove negative HB. Glove-side pitches
(sliders, sweepers, most cutters) stay negative. The sign means the same thing
for both hands, which is the point.

**Interview line on "how does it tell a changeup from a fastball without the
label":** by shape. An 85 mph pitch with a -9 velo gap, 8" of ride and 15" of
fade grades as that shape; the word changeup never enters.

---

## 2026-10-19: Batter side as an input, split grades

**Decision.** Add one yes/no input: same-side or opposite-side hitter (after
mirroring). Score every pitch twice, once against each side. Those two
predictions are the vs RHH and vs LHH grades; the overall grade averages them
50/50.

**Options considered.**
- Add batter side: split grades that fit the app's Batter side selector, at
  the cost of one feature and half the sample behind each split.
- One grade only: simplest, as FanGraphs and tjStuff+ do. BP StuffPro includes
  batter side.

**Why.** He raised it: "I know some stuff models are able to split and give one
grade vs righties and a different grade vs lefties." A sweeper's value depends
heavily on which side the hitter stands.

**Why the 50/50 overall.** Averaging over the hitters he actually faced would
reward a lefty specialist for his usage, not his stuff. Scoring both sides for
every pitch keeps the overall grade about the pitch.

---

## 2026-10-19: Validate by holding out pitchers

**Decision.** 5 folds by pitcher on 2022-2025. Every pitch is graded by a model
that never saw that pitcher. Pass means season-t Stuff+ predicts season-t+1 run
value better than season-t run value does (the pre-registered gates).

**Options considered.**
- Hold out pitchers: every grade is a "new call-up" grade; uses all four seasons
  and gives three season pairs to judge.
- Hold out a season (earlier plan: train 2022-24, test 2025): tests the future,
  but most 2025 pitchers were in training, so the model can grade them from
  memory and the test looks better than it is.
- Both: strictest, least data, one season pair.

**Why.** Took the recommendation. Boosted trees can memorize a pitcher's exact
shape and the results it got. The grades that matter most (call-ups, a pitcher
who just changed a pitch) are the ones memory cannot help, so the test should
not let memory help either.

**Rule that follows.** Anything learned from data (the run-value table and the
scale constants) is fit inside the training folds only. This
is the carry_res bug from v5.

---

## 2026-10-19: Count stays in the target (revisited)

**Decision.** Keep count in the run-value table. Count is not a model input;
it only sets what each outcome is worth.

**Options considered.**
- Keep count: each outcome valued within its count, so the average pitch nets
  about zero in every count.
- Strip count fully: one value per outcome, strikeouts folded into whiffs and
  walks into balls.

**Why.** He first wanted it stripped ("I think this should be stripped out
too") so the target would be situation-agnostic. Stripping it adds a usage
bias instead: 0-2 chase sliders get charged a full ball for pitches meant to
miss, and 3-0 fastballs collect easy called-strike credit. Valuing outcomes
within the count is what keeps a pitch from being rewarded for when it is used.

**What he learned along the way.** The run-value table and the scale constants
are fit inside the training folds only. In his words: "prevent leakage."
Interview line: "Anything estimated from data, even a league average, is part
of the model. Otherwise the held-out pitchers help write their own answer key."

---

## 2026-10-19: No shrinkage

**Decision.** A grade is the plain average of its pitches' predictions. The
app shows the pitch count beside it; leaderboards require 250 pitches.

**Options considered.**
- No shrinkage: nothing to justify; predictions are already expected values
  from shape, which settles fast (FanGraphs: about 80 pitches); a real new
  pitch shows its grade at once. Cost: under ~30 pitches a grade can drift.
- Shrink toward the pitch-type average (v5 used 75 pitches): steadier small
  samples, but the pitch label comes back through the shrink target, real
  outliers get pulled in, and the constant has to be defended.
- Shrink toward 100: no label, but pulls small-sample sinkers up and sweepers
  down toward a center neither belongs at, and still needs a constant.

**Why.** He asked for the pros and cons of each, then took no shrinkage. The
deciding point: shrinking toward a type average would put the pitch label back
into a grade from a model designed to ignore it.

**Interview line.** "Stuff+ describes the pitch, so I show it with its sample
size. Shrinkage belongs in projection, where you're forecasting results."

---

## 2026-10-19: 10 points = 1 SD of pitcher pitch types

**Decision.** Stuff+ = 100 + 10 × (grade − μ) / σ. μ is the mean prediction
over all pitches (100 = the average pitch thrown). σ is the SD across pitcher ×
pitch-type seasons with 100+ pitches. Both are fit on training folds, then
fixed. The vs RHH and vs LHH grades use the same constants, so a split grade
reads on the same scale as the overall.

**Options considered.**
- SD of pitcher pitch types: familiar ~80 to 120 spread; one SD is one SD for
  the unit people actually read.
- SD of single pitches (how FanGraphs states its scale): tidy, but pitcher
  grades compress to roughly 92 to 108.

**Why.** Took the recommendation. A pitcher's average of hundreds of pitches
varies far less than single pitches, so a pitch-level SD would make real
differences look small.

**From the shrinkage check, in his words:** "The number is real... however
it's a small sample and subject to change as he throws more of them."
Sharpened: the grade is the shape, which settles much faster than results, and
the pitch count shown beside it is the number to point to.

---

## 2026-10-19: Model settings fixed in advance

**Decision.** XGBoost, depth 4, learning rate 0.05, 400 rounds, at least 100
pitches per leaf (`min_child_weight` 100), row sampling 0.8, all features in
every tree. A depth-6 refit runs only as a fragility check: if any gate result
flips, the result is UNRESOLVED, not "use whichever depth looks better."

**Options considered.**
- Fixed in advance: nothing tuned on the test, so nothing to defend but the
  defaults.
- Early stopping on held-out training pitchers: picks rounds from data, but
  adds a third split and another place for a leak.
- Grid search: the "optimal" answer, slow on 3M pitches, and invites picking
  settings that flatter the test.

**Why.** Took the recommendation. His v5 tuning study found schedule and
regularization changes worth about +0.017 r, smaller than year-to-year drift,
and it did not replicate.

**What the settings mean, in baseball terms.** Depth is how many traits one
rule can combine (ride from a low release, against a same-side hitter, at
96+). Rounds and learning rate are how many small corrections the model makes
and how big each is. Minimum leaf size stops a rule being built around one
pitcher's odd pitch.

---

## 2026-10-19: Fix settings and bar before fitting; checks only veto

**Decision.** One pre-registered shot at the test. Sensitivity checks (the
depth-6 refit) can only veto a result, never choose one. 2026 stays untouched
as a fresh test for a v2 if this fails.

**Why.** He asked for this to be explained further: "I believe this is where
previous models went wrong." Picking the best of several runs picks luck, like
calling the one hitter who went 12-for-30 a .400 hitter. His v5 history shows
it: a tuning arm "significant" on 2025 tied on 2024; carry_res passed only after
"confirm" was reread as "not contradict"; 13 vs 11 features was rerun and won
by 0.004 r. Each step reasonable alone, together a drift toward whatever
flattered the test.

**Interview line.** "I fixed the settings and the bar before fitting. Checks
can veto a result but not pick one, because choosing the best of several runs
is choosing noise. A 'significant' tuning win in my earlier version vanished
the next season."

---

## 2026-10-19: Gate 3 pooled; gate 4 a hard gate on a verified list

**Gate 3 decision.** Grades and next-season run value are each centered on
their own pitch type's average, then one correlation is computed across FF,
SI, SL, ST, CU and CH. Its 95% CI must exclude zero, and at least 5 of the 6
types must be individually positive.

**Options considered.** All six positive (as first written: lenient per type,
but one noisy small type fails everything); pooled plus 5 of 6; beat current
run value within every type (strongest, but underpowered at ~250 pairs per
type).

**Gate 4 decision.** Stays a hard gate: 10 of 15 elite pitches in the top 20%
of their type, 3 of 4 weak in the bottom 20%. Every entry is checked against
Statcast labels and pitch counts before fitting (no grades seen), and he signs
off on the names.

**Options considered.** Hard gate; eye test only (stop and investigate if under
half hit); minimum rank agreement with FanGraphs and tjStuff+ (objective, but
the designs differ on purpose, so any threshold is arbitrary).

**Why.** Took both recommendations. Gate 4 is the only check that catches a
model that passes the statistics but ranks the wrong pitches. Known weakness:
some reputations (Skubal's changeup) are partly built on results, and a pure
stuff model can fairly disagree.

---

## 2026-10-19: Forkballs included, graded as FO

**Decision.** FO pitches enter training and get their own FO grade, as Savant
labels them. Senga's known-answer entry is FO 2023 (664 pitches).

**How it came up.** Verifying the known-answer list against labels: Senga's
ghost fork has 0 pitches as FS and 664 as FO. The old pipeline kept only FF,
SI, FC, SL, ST, SV, CU, KC, CH and FS, so every forkball was silently dropped.

**Options considered.** Include as FO; include but fold into FS for grades;
exclude and drop Senga.

**Why.** Took the recommendation. The model never sees labels, so including
forkballs costs nothing, and keeping Savant's code avoids a silent relabel.

**Still excluded:** KN, EP, CS, SC (rare) and PO (pitchouts).

**List check result, 2026-10-19 (labels and pitch counts only, no grades):**
all 19 entries exist with 250+ pitches once Senga is FO. Closest to the floor:
Duran FS 2024 at 277.

---

## 2026-10-19: Eye-test leaderboards by pitch type

**Decision.** After the fit, one board per pitch type (FF, SI, FC, SL, ST, SV,
CU, KC, CH, FS, FO): top and bottom 15 on the overall grade, 250-pitch minimum,
2025 and 2026 (through 2026-09-27), each row showing the grade, the pitch count
and the inputs. Plus one small table per type of average vs RHH minus vs LHH,
to confirm the batter-side input behaves (sweepers should grade much better
against same-side hitters).

**Options considered.** Overall plus a split check; overall only; full top and
bottom 15 for overall, vs RHH and vs LHH (three times the reading).

**Why.** He asked for "a leaderboard for the eye test split by pitch type," and
took the recommendation on splits.

**Rule for using the boards.** A grade that looks wrong because of a bug (a
lefty not mirrored, a bad fastball baseline) gets the bug fixed, documented,
and rerun. A grade that looks wrong with correct code is a finding for the
writeup; features and settings do not change to make the boards look nicer.

---

## 2026-10-19: Three reported additions (not gates)

**Decision.** Add to the reported section:
1. **Baseline to beat.** A linear model on velo, IVB and HB, with the same
   folds and target; report what the boosted model adds.
2. **Stabilization curve.** Split-half reliability of grades at 25, 50, 100 and
   200 pitches, giving a "trust it after N pitches" number.
3. **What drives the grades.** Feature importance plus worked examples (why
   Strider's FF grades where it does).

**Left out.** The Coors check (home-minus-road grades for Rockies pitchers).
Known bias, not sized in this build.

**Why.** He asked what else would help. Each answers an interview question:
what the model knows beyond velocity, when a small-sample grade can be trusted,
and how to explain the model to a pitching coach. Reported only, so none adds a
forking path.

---

## 2026-10-19: Keep the cleaning filters (pre-registration amendment 1)

**Decision.** Keep the two filters already in `02_clean.R` (position players
pitching; bunts, pitchouts, automatic balls and strikes) and add them to the
pre-registration as a dated amendment. `02_clean.R` was edited to match the
pre-registration: 2022-2025 together, FO kept, target columns kept, spin not
required.

**How it came up.** The first input audit read `02_clean.R` before writing new
code and found four mismatches with PREREG.md and two good filters PREREG.md
had missed.

**Why amending is fair here.** No model was fit and no outcome was seen. An
amendment before the shot is housekeeping; the same change after seeing grades
would be a forking path.

---

## 2026-10-19: Velo gap measured from the hardest fastball (amendment 2)

**Decision.** Baseline = the hardest FF, SI or FC thrown at least 10% of the
time and 20+ times that season; otherwise the most-thrown fastball.

**How it came up.** The baseline audit: Brazobán throws mostly 88 mph cutters
and a 96 to 97 sinker and four-seamer. Measured from the cutter, his changeup
looked faster than his fastball.

**Options considered.** Most-thrown (the old rule); hardest with 10% usage and
20 pitches; hardest with 10% only; hardest at any usage.

**Why, in his words.** "Use the velo difference from 96." Hitters gear up for
the hardest heater. The floors came from his point that a baseline from a few
fastballs is "a small sample": one bad baseline shifts every secondary pitch's
gap.

**Other audit answers, in his words.**
- Cease's 75 mph 2023 changeup: "Cease did throw a 75 mph CH in 2023, but he
  threw it only 3%." The label stays.
- Slow curves 20+ mph off the fastball: "probably would really like these
  pitches bc of the big velo gap. However, I know velocity is king." Lesson:
  the model learns which wins from outcomes, and trees predict flat at the
  edges, so rare shapes are graded like their nearest common neighbors.

---

## 2026-10-19: Errors count as outs, sac bunts dropped (amendment 3)

**Decision.** A reached-on-error ball in play gets field-out value. Sacrifice
bunts are dropped.

**Options considered.** Errors: count as outs; drop (v5); keep as reached base.
Sac bunts: drop; keep as outs.

**Why.** Took both recommendations. Counting errors as outs keeps the contact
the pitch induced while removing the fielder, which is the target's job;
dropping them would throw that contact away, and keeping them as hits charges
the pitcher for his defense. A sac bunt is the hitter choosing to make an out,
consistent with his bunt filter.

**Leak test result.** Without each fold's pitchers, the run-value table moves
by up to 0.014 to 0.039 runs in its thinnest cells. Small overall, real in
thin cells, which is why it is built per fold.

---

## 2026-10-19: Gates on raw predictions; pre-shot review (amendment 4)

**Decision.** Gates use raw out-of-fold predictions; the 100 scale is applied
only for display, with constants from the final fit.

**Why, in his words.** "Every stuff model does this, it's common practice."

**His concern, recorded.** "One thing I don't like is how you keep finding
little mistakes. If we only have one shot at this, we can't have little
mistakes." Response: three of the four were gaps in Claude's own draft of the
pre-registration and one was Claude's code; all were caught before any grade
was seen. To stop relying on catching them, the shot now waits for a
line-by-line plan-versus-code review and a structure-only dry run.

---

## 2026-10-19: His platoon prediction, recorded before fitting

**Prediction, in his words.** "It should be tougher on same-sided hitters. I'd
expect curveballs with more downward action to be more hand neutral."

**Why it holds up.** Vertical movement looks the same to either hitter; lateral
movement breaks away from a same-side hitter and into an opposite-side one. So
the same-side advantage should be largest for sweepers and sliders, smallest for
curveballs and splitters. Added to the split-check table in PREREG.md as an
expectation, not a gate.

**Interview line on why batter side is allowed but pitch type is not.** "Pitch
type is a summary of the shape, so it is a shortcut. Batter side is context, so
the model learns it, and every pitch is scored against both sides so the
overall grade is about the pitch."

---

## Accepted, not discussed (revisit in the loop)

- **Known-answer list.** Draft of 15 elite and 4 weak pitches, waiting on his
  edits.

Draft pre-registration with all of the above: `~/Desktop/Baseball
Questionnaires/02_StuffPlus/PREREG_SimpleStuff.md` (uncommitted).
