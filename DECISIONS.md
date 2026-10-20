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
- Count-and-outcome average (often called xRV): removes base-out state, keeps
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

**Options considered.** Public models (FanGraphs, BP StuffPro, Baseball
America, FG Community xWhiff) all use velo, movement and release point; most
add extension and spin; FG and BP add velo and movement gaps, BA uses velo gap
only.

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
  shape.
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
- One grade only: simplest, as FanGraphs does. BP StuffPro includes batter
  side.

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
half hit); minimum rank agreement with public Stuff+ models (objective, but
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

## 2026-10-20: Council review before the shot (amendment 5)

**What happened.** Five advisors (contrarian, first principles, expansionist,
outsider, executor) reviewed the plan and code, then reviewed each other
blind, and a chairman ruled.

**Verdict.** Design sound, no leak or broken gate found; not ready to run
until the plumbing exists: no run script, no code for the reported checks,
and `renv.lock` recorded no packages.

**His calls.** Linear baseline stays reported, not gated. Location check added
as a reported item.

**Points worth keeping for interviews.**
- Gate 1 is the easy gate; gates 3 and 4 carry the weight.
- Location leaks into the target (balls, called strikes, walks); every stuff
  model shares it, and this one now measures it.
- The known-answer list is partly circular: reputations are partly results.
- The 50/50 grade describes a pitch, not a pitcher's projected results.

**v2 list (not before the shot).** Pitch-design what-ifs, Triple-A prospect
grades, a trust indicator in the app from the stabilization curve, a public
writeup built from this log.

---

## 2026-10-20: Line-by-line review; changeup fallback trigger (amendment 6)

**Review result.** Everything in data, target, inputs, settings, folds and
gates matched. Four gaps fixed before the shot (reproducibility check,
explicit depth-6 comparison, worked examples, mean Stuff+ on the 100 scale);
the changeup fallback was coded in advance. Full checklist: REVIEW.md.

**His call.** The changeup fallback runs only if gate 3 fails with CH among
the misses. Options were that, or whenever CH misses (which would make CH a
must-pass type). Took the recommendation, consistent with gate 3's one-miss
rule.

---

## 2026-10-20: v1 result, and v2 purpose and rules

**v1 verdict: FAIL** (gates 1 and 2 failed, 3 and 4 passed, depth 6
RESOLVED). Lost to raw results on changeups, splitters and sinkers. Recorded
as is; not rerun to pass.

**Purpose, in his words.** "Stuff+ is meant to measure how nasty a pitch is in
a hitter, situation, and location agnostic way." And: "I don't need the most
predictive stat in the world... I want this to be a descriptive metric."
Clarified: it describes the expected value of the shape, not how the pitch
performed (that would include location, which the pitcher controls:
Pitching+).

**Extension is out, final.** His override: "Extension will not be in the
model."

**v2 rules (Claude as team R&D analyst, he vetoes).**
- Data roles: iterate on 2022-2025 with pitcher folds; 2026 is the one
  untouched final test.
- Bars follow the purpose: reliability (split-half, year to year), validity
  (within-type same-season whiff rate and run value on swings, benchmarked
  against FanGraphs Stuff+ on the same pitches), face validity (known answers).
  The predictive test is reported, not a bar.
- First change to try: IVB and HB gaps to the hardest fastball.
- Pitcher roll-up: usage-weighted, descriptive only; no K-BB% projection test.

**Interview line.** "v1 taught me I'd judged a descriptive metric with a
predictive bar. I re-derived the bars from the purpose and tested on a
held-out season."

---

## 2026-10-20: Council on v2; FanGraphs bar

**Council refinements, adopted.**
- Main validity test: within each pitch type, same-season correlation of
  Stuff+ with **whiff per swing** (the most shape-driven outcome), pooled across
  types. Run value on swings reported beside it.
- The 2026 holdout is same-season, so no year pairs are needed (~950 qualified
  pitch types), cleaned through the same `02_clean.R`.
- Reliability is a sanity check, not a bar.
- Every development experiment is logged one line each in `ITERATIONS.md`.
- FanGraphs' 2026 export ends 2026-08-17: compare over that window or pull a
  full-season export.

**His call.** On 2026, v2's pooled within-type correlation with whiff per swing
may trail FanGraphs' by **at most 0.05**. Allows for leaving out extension and
spin on purpose while still requiring public-grade description.

---

## 2026-10-20: v2 target becomes whiffs

**Decision.** v2 is a whiff model: trained on swings only, label 1 = whiff,
0 = contact. A grade is the average predicted whiff probability over all of a
pitch's throws, scaled to 100. Run value on swings becomes the second
yardstick.

**How it came up.** Development results showed the target and the purpose did
not match. The model was trained on run value (value) but judged on whiffs
(nastiness). On 2025, against FanGraphs on the same pitches: whiff per swing
0.234 vs 0.512, but run value on swings 0.185 vs 0.263. The gap was mostly
about what the model aimed at, not any input, which is why no added input
moved it.

**Options considered.** Whiff per swing; keep run value and rename the purpose
"pitch value"; build both.

**Why, in his words.** "Whiffs don't make a pitch the best," then, "but from a
nastiness perspective they do." And: "Make it a whiff model." It also matches
his first instinct in v1: "Just let sinkers and prob CH too grade low and state
that, since we're chasing whiffs."

**Cost.** The grade no longer rewards weak contact: sinkerballers grade low on
nastiness. That is accurate for the word, not a measure of a pitch's value.

**Keep both, his call.** "Keep both versions and see which is better." Rule
set while the whiff run was still in progress, before any of its results:
the version with the higher within-type whiff-per-swing r on 2022-2025 wins
(the purpose is nastiness); run value on swings is reported as a second check.
Only the winner takes the 2026 exam; picking between them on 2026 would be
selecting on the exam. The other version stays in the code and log, available
later as a separate "pitch value" grade.

**Correction recorded.** Claude earlier called checking a whiff-trained model
against whiffs "circular." That is wrong for out-of-fold grades: the model never
saw those pitchers, so it is the normal accuracy test.

---

## 2026-10-20: The 2026 exam bar

**Decision.** v2 passes the 2026 exam if its pooled within-type correlation
with whiff per swing is **at least 0.38**. Development (2022-2025, out of fold)
is 0.42; 0.38 allows normal season-to-season wobble but not collapse. FanGraphs
is reported beside it, not a bar. Replaces the earlier "within 0.05 of
FanGraphs," which the benchmark check showed no comparable design would pass.
Set before any 2026 result exists.

**His answers on the way here, in his words.**
- On judging both versions on whiffs: "Comparing apples to apples. It doesn't
  make sense to judge on whiffs if the target is RV." Refinement: each model is
  judged on its own target to ask whether it works; the choice between them is
  judged on the purpose (nastiness). The whiff model also tied on run value on
  swings, 0.216 vs 0.213.
- On the holdout: "Could we make a copy?" No: a holdout is information, not a
  file. Once a result is seen and acted on, every copy is spent.
- On k-means slider groups (from his sweep velocity project): clusters built
  from the same inputs add little the trees cannot find; v5's cluster variable
  was inert. Possible use as a cleaner grouping for judging sweepers, reported
  only.

---

## 2026-10-20: Axis differential kept; v2 frozen

**Result.** Adding the axis differential to the whiff model raised dev whiff r
from 0.423 to 0.465, clearing his +0.02 rule. Gap to FanGraphs on 2025: 0.06,
down from 0.28 at the start of v2. Sweepers barely moved (0.23 to 0.24): still
an open question for v3.

**How it is built, as taught.** Measured spin axis (Hawk-Eye) against the axis
implied by the actual movement; the gap is movement spin does not explain
(seam-shifted wake), i.e. deception. Calibrated before use: curveballs near 0
for both hands, sinkers and changeups larger, sign flipping by hand.

**Frozen.** No more experiments before the exam. Spec: PREREG_v2.md.

---

## 2026-10-20: v2 exam result: PASS

**Verdict.** 2026 pooled within-type whiff r **0.518** against the 0.38 bar
(development, out of fold: 0.465). Exam run at commit 4af1edd, log in
`outputs/exam_v2_exam/exam.log`.

**Reported.** Run value on swings 0.281. Against FanGraphs on the same 767
pitches over its export window (to 2026-08-17): ours 0.497, FanGraphs 0.483.
Split-half reliability 0.99 at 25 pitches (expected for a shape model: proves
stability, not correctness). Face validity on 2022-2025: 10 of 15 elite, 4 of 4
weak. By type: SI 0.65, FC 0.64, SL 0.60, FF 0.53, CH 0.51, FS 0.48, CU 0.42,
ST 0.33.

**Predictions.** He predicted lower than development; so did Claude. It came
in higher. Likely reasons: the final model trained on all four seasons, and
most 2026 pitchers appear in 2022-2025 training, so 0.518 is a "veteran" grade.
The strict call-up figure is development's 0.465.

**Findings to keep.** Hard splitters are a blind spot: Duran's 97 mph splitter
(3 mph off his fastball) ranks 0th percentile among splitters, read as
fastball-like. Clase's cutter (19th) wins on weak contact, which a nastiness
grade correctly ignores. Sweepers remain the weakest type.

---

## 2026-10-20: Two follow-ups to the exam

**"Did it just learn pitchers?" No.** 2026 whiff r: returning pitchers 0.522,
pitchers new in 2026 0.441 (57 pitch types). Recognition adds some, but the
never-seen group is still well above the bar, and development's 0.465 came
from a model that saw none of the pitchers it graded.

**Hard splitters: not a blind spot, a definition.** He: "Hard splitters should
grade well." Duran's splitter ranks near the bottom in whiff per swing every
season (2023 27%, 19th of 23; 2024 21%, 32nd of 34; 2025 23%, 30th of 33; 2026
28%). The model's low grade matches. Its value is getting swings and weak
contact at 97 mph, which a nastiness (whiff) grade correctly ignores. Cade
Smith (39 to 45% whiffs) grades 124, correctly. Yamamoto (42% in 2025, 34% in
2026, grade 107) may be slightly underrated.

**Lesson.** Duran was a poor known-answer pick for a whiff metric: chosen from
reputation without checking what the reputation was about. When a metric and a
scout disagree, check what each measures first. A value grade (the run-value
model) would be the one to rate Duran's splitter highly.

---

## 2026-10-20: Eye test on the 2026 board

**His verdict.** "This model is pretty solid. Passes my eye test for sure."

**Axis differential, the definition to use.** The angle between the spin axis
Hawk-Eye measures out of the hand and the axis implied by the ball's actual
movement. If spin alone moved the ball they would match; a gap means something
besides spin pushed it, usually seam-shifted wake. The hitter reads spin early
and the ball goes somewhere else: deception, measured in degrees. Positive is
extra movement toward the arm side; lefties mirrored.

**Board floor.** The 250-pitch floor hid most pitch types (1,008 of 3,863
shown): Max Meyer's CH (182) and SI (173), and every pitch of Justin Martinez
(231 pitches in all of 2026). Board now shows 50+ with small samples marked,
and a percentile within pitch type.

**Four-seamers "lower in general."** Mostly the league-wide whiff scale he
chose: four-seamers miss fewer bats than breaking balls. Cam Schlittler is a
real miss: his FF grades 99 (73rd percentile among FF) but gets 35% whiffs per
swing (98th). Sean Burke's 73rd vs 78th is about right. Extension checked and
ruled out as the fix: across all four-seamers it explains nothing about whiffs
beyond the grade (partial r 0.01). His exclusion holds.

**Uniqueness (Tyler Rogers), a v3 idea.** Rogers's sinker gets 12% whiffs per
swing against a 13% median: his uniqueness produces weak contact, which a value
model rewards and a nastiness model should not. A "distance from any common
shape" input is a fair v3 experiment; the model will use it only if rarity
itself misses bats. 2026 is spent as an exam, so v3 is judged on 2027.

---

## 2026-10-20: Release y stays out; Rogers stays as a documented limit

**Release y.** He asked whether to add release x, y and z. x (side) and z
(height) are already inputs. y is distance from the plate at release, about
60.5 ft minus extension, so it is extension under another name. His call holds:
"I'm pretty confident we shouldn't use extension." Not added.

**Axis differential runs largest on the slider family.** Calibration order: CU
~0, FF ~8, SI and CH 12 to 20, SL, FC and ST 24 to 31 degrees. Seam effects are
real on sweepers, but sliders and cutters carry heavy gyro spin, which makes the
measured 2D axis less meaningful, so part of their gap is measurement. Consistent
with the result: the axis input helped SI and FF most and ST barely.

**Tyler Rogers.** "We'll leave Rogers as is, and understand his limitations to
the model." A nastiness grade does not reward weak contact or rarity.

---

## 2026-10-20: App shows Stuff+ at every sample size

**Decision.** No minimum pitch count for showing Stuff+ in the app; the count
sits beside every grade, as with every other column.

**Options considered.** Leave it; hide Stuff+ under 10 pitches in the chosen
window.

**Why, in his words.** "I think we have to leave it." Consistent with the
app's other columns. Known cost: a 1-pitch grade (Martinez's slider vs LHH in
local testing) can look more authoritative than it is.

**His local test results.** Sweeper better vs same-side hitters (Cade Smith ST
116 vs RHH, 109 vs LHH), curve neutral (Schlittler CU 120/121/120), cutter
glove-side split (Schlittler FC 104 vs RHH, 96 vs LHH), splitters steady (Smith
124 every view). Grade follows dates and batter side.

---

## 2026-10-20: 100 is per pitch group, not league-wide

**Decision.** 100 is the average pitch within its group and 10 points one SD
across pitcher pitch types within the group. Groups: fastball (FF, SI, FC);
offspeed (CH, FS, FO); hard breaker (SL); soft breaker (ST, SV, CU, KC, CS).

**Why, in his words.** "We need to group by pitch type... I've realized that
this is necessary." Cutter is a fastball. KC and CS go with soft breakers and
FO with offspeed, matching how the app already folds them.

**What changed and what did not.** Display only. The model, its predictions and
every validation number (the 2026 exam ran on raw predictions) are unchanged;
the 2026 daily scores file is byte-identical. Constants from 2022-2025: average
whiff probability fastball 0.204, hard breaker 0.329, offspeed 0.316, soft
breaker 0.314; SDs 0.039 to 0.050, against 0.075 for the single scale, which was
inflated by the gap between groups. 2026 full-season medians (250+ pitches):
102 to 104 in every group.

**Trade-off, stated.** Grades no longer compare across groups: a 110 sinker and
a 110 sweeper are each well above their own group, not equally nasty. This
reverses the 2026-10-19 league-wide choice; the familiar convention for readers
of a scouting app outweighed it.

---

## 2026-10-20: "Differentiation" hypothesis tested on release height

**His hypothesis.** "Think of release height and side as a bell curve... what
matters is that you aren't towards the mean. You have to be differentiated,
either on the low tail or the high tail."

**Result, four-seamers 2022-2025 (1,265 pitcher-seasons, raw whiff per
swing).** One-sided. Lowest release-height decile 25.7%, middle 21.5 to 23.4%,
top three deciles 19.6 to 20.8%, even though high slots carry more ride (17.4"
vs 13.0"). From a high slot the ball arrives at a steeper angle, so ride
flattens it less. Release side also one-sided, the other way (widest deciles
~24% vs ~21%). The model's learned release-height effect has the same
monotone shape (+0.15 to -0.07 log-odds); a tree could have learned a U and the
data has none.

**Where the idea holds.** "Different from expected," not "far from average":
Schlittler (6.1 ft slot, 16.9" ride, 35% whiffs, graded 108) gets more from his
ride than his slot predicts. The data-supported form is ride relative to arm
slot (v5's carry_res idea). v3 candidates for 2027: location-adjusted VAA, ride
relative to slot, uniqueness.

**Schlittler, explained by the model's contributions.** Velocity is the biggest
lever, and 98 adds about half what 100 to 101 does; his ride adds a little; his
high release subtracts. Mirror case: Josh Ekness grades 128 (best FF) on a
5.2 ft slot but gets 24% whiffs. Release height is a proxy for approach angle
that misfires at both ends.

---

## Open items

- None from v1. The known-answer list was signed off 2026-10-19 and the old
  02_StuffPlus draft was deleted.
