# dev_experiment.R
# One v2 development experiment on 2022-2025. Never reads 2026.
#   Rscript scripts/dev_experiment.R <name>

suppressMessages({ source("R/cv.R"); source("R/gates.R"); source("R/validity.R"); source("R/leaderboards.R") })
name <- commandArgs(trailingOnly = TRUE)[1]
EXPERIMENTS <- list(
  v1          = INPUTS,                               # baseline
  ch_gaps     = c(INPUTS, "ivb_gap", "hb_gap"),       # dropped
  spin_one    = c(INPUTS, "release_spin_rate"),       # dropped
  spin_family = c(INPUTS, "release_spin_rate"),       # three family models, dropped
  whiff       = INPUTS,                               # whiff target, kept
  whiff_axis  = c(INPUTS, "axis_diff")                # plus axis differential, kept: this is v2
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
res <- list(name = name, inputs = inputs,
            dev_whiff = v$whiff, dev_rv_swing = v$rv_swing, by_type = v$by_type,
            predictive_edge = edge(year_pairs(season_grades(oof))))
if (file.exists(FG_2025)) {
  fg <- po |> filter(game_year == 2025) |> add_fangraphs(FG_2025) |> filter(!is.na(fg_stuff))
  res <- c(res, list(ours_2025 = validity(fg)$whiff, fg_2025 = validity(fg, fg_stuff)$whiff, fg_rows = nrow(fg)))
}
dir.create("outputs/dev", recursive = TRUE, showWarnings = FALSE); saveRDS(res, file.path("outputs/dev", paste0(name, ".rds")))
cat("\n==", name, "==\n")
cat("dev 2022-25 within-type r, whiff/swing:", round(res$dev_whiff, 3), " rv on swings:", round(res$dev_rv_swing, 3), "\n")
if (file.exists(FG_2025)) {
  cat("2025, same", res$fg_rows, "pitches: ours", round(res$ours_2025, 3), " FanGraphs", round(res$fg_2025, 3),
      " gap", round(res$ours_2025 - res$fg_2025, 3), "\n")
}
cat("predictive edge (reported only):", round(res$predictive_edge, 3), "\n"); print(res$by_type |> arrange(pitch_type))
