# Rscript dev_experiment.R <name>   -> one v2 development experiment on 2022-2025
# Never reads the 2026 holdout
suppressMessages({ source("R/cv.R"); source("R/gates.R"); source("R/validity.R"); source("R/leaderboards.R") })
name <- commandArgs(trailingOnly = TRUE)[1]
EXPERIMENTS <- list(
  v1          = INPUTS,                               # baseline: the v1 inputs
  ch_gaps     = c(INPUTS, "ivb_gap", "hb_gap"),       # changeups vs the fastball (dropped)
  spin_one    = c(INPUTS, "release_spin_rate"),       # 3a: one model + spin
  spin_family = c(INPUTS, "release_spin_rate"),       # 3b: three family models + spin
  whiff       = INPUTS,                               # v2: whiff target, v1 inputs
  whiff_axis  = c(INPUTS, "axis_diff")                # v2 exp 4: + axis differential
)
inputs <- EXPERIMENTS[[name]]; stopifnot(!is.null(inputs))
p   <- prep_pitches()
oof <- if (name %in% c("whiff", "whiff_axis")) {
  run_cv(p, \(d) fit_whiff(d, inputs), \(m, d) score_both_sides(m, d, inputs))
} else if (name == "spin_family") {
  run_cv(p, \(d) fit_family(d, inputs), \(m, d) score_family(m, d, inputs))
} else {
  run_cv(p, \(d) fit_model(d, inputs = inputs), \(m, d) score_both_sides(m, d, inputs))
}
po  <- pitch_outcomes(oof)
v   <- validity(po)
fg  <- po |> filter(game_year == 2025) |>
  add_fangraphs("/Users/jonathanmerlin/Desktop/Baseball Questionnaires/06_Data/savant_leaderboards/fg_stuff_2025-03-18_2025-09-30.csv") |>
  filter(!is.na(fg_stuff))
res <- list(name = name, inputs = inputs,
            dev_whiff = v$whiff, dev_rv_swing = v$rv_swing, by_type = v$by_type,
            ours_2025 = validity(fg)$whiff, fg_2025 = validity(fg, fg_stuff)$whiff,
            fg_rows = nrow(fg), predictive_edge = edge(year_pairs(season_grades(oof))))
dir.create("outputs/dev", showWarnings = FALSE); saveRDS(res, file.path("outputs/dev", paste0(name, ".rds")))
cat("\n==", name, "==\n")
cat("dev 2022-25 within-type r, whiff/swing:", round(res$dev_whiff, 3), " rv on swings:", round(res$dev_rv_swing, 3), "\n")
cat("2025, same", res$fg_rows, "pitches: ours", round(res$ours_2025, 3), " FanGraphs", round(res$fg_2025, 3),
    " gap", round(res$ours_2025 - res$fg_2025, 3), "\n")
cat("predictive edge (reported only):", round(res$predictive_edge, 3), "\n"); print(res$by_type |> arrange(pitch_type))
