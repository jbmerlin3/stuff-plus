# Rscript exam_v2.R dry    -> 2026 slice, structure only, no 2026 result printed
# Rscript exam_v2.R exam   -> the one v2 exam on 2026 (PREREG_v2.md)
suppressMessages({ source("R/cv.R"); source("R/gates.R"); source("R/known.R"); source("R/reported.R")
                   source("R/validity.R"); source("R/leaderboards.R") })
mode <- commandArgs(trailingOnly = TRUE)[1]; stopifnot(mode %in% c("dry", "exam"))
out <- file.path("outputs", paste0("exam_v2_", mode)); dir.create(out, recursive = TRUE, showWarnings = FALSE)
V2 <- c(INPUTS, "axis_diff")
FG26 <- "/Users/jonathanmerlin/Desktop/Baseball Questionnaires/06_Data/savant_leaderboards/fg_stuff_2026-03-26_2026-08-17.csv"

# Final fit on ALL 2022-2025 swings; the run-value table (for the second
# yardstick) and the 100-scale constants also come from 2022-2025 only
dev0 <- prep_pitches()                      # untouched copy for the face-validity folds
tab <- rv_table(dev0)
dev <- dev0 |> left_join(tab, by = c("outcome", "balls", "strikes"))
if (mode == "dry") { set.seed(3); dev <- dev |> filter(pitcher %in% sample(unique(pitcher), 400)) }
model <- fit_whiff(dev, V2)
dsc <- score_both_sides(model, dev, V2)
dsg <- dsc |> summarise(n = n(), g = mean(pred), .by = c(pitcher, game_year, pitch_type))
mu <- mean(dsc$pred); sigma <- sd(dsg$g[dsg$n >= 100])

# 2026: features built from 2026's own pitches, valued with the 2022-2025 table
h <- prep_pitches("data/holdout/pitches_clean_2026.rds") |> left_join(tab, by = c("outcome", "balls", "strikes"))
if (mode == "dry") { set.seed(3); h <- h |> filter(pitcher %in% sample(unique(pitcher), 300)) }
sc <- score_both_sides(model, h, V2)

if (mode == "dry") {
  cat("dev rows:", nrow(dev), " 2026 rows scored:", nrow(sc), "of", nrow(h), "\n")
  cat("2026 missing per input:\n"); print(colSums(is.na(sc[, V2])))
  cat("2026 game_type range ok:", all(sc$game_year == 2026), "\n")
  steps <- list(validity = \() validity(pitch_outcomes(sc)), split = \() split_half(sc),
                fg_window = \() pitch_outcomes(filter(sc, game_date <= as.Date("2026-08-17"))) |>
                  add_fangraphs(FG26) |> filter(!is.na(fg_stuff)) |> validity(fg_stuff),
                board = \() season_board(sc, mu, sigma, 2026, min_n = 20))
  for (s in names(steps)) cat(s, ":", tryCatch({ steps[[s]](); "ran" }, error = \(e) conditionMessage(e)), "\n")
  quit(save = "no")
}

# ---- The exam: verdict first ------------------------------------------------
po <- pitch_outcomes(sc); v <- validity(po)
cat("\n=== V2 EXAM, 2026 ===\npooled within-type whiff r:", round(v$whiff, 3), " bar 0.38 ->",
    if (v$whiff >= 0.38) "PASS" else "FAIL", "\n")
saveRDS(list(scored = sc, mu = mu, sigma = sigma, validity = v), file.path(out, "exam.rds"))

# Reported
cat("\nrun value on swings r:", round(v$rv_swing, 3), "\nby pitch type:\n"); print(v$by_type |> arrange(pitch_type))
fgw <- pitch_outcomes(filter(sc, game_date <= as.Date("2026-08-17"))) |> add_fangraphs(FG26) |> filter(!is.na(fg_stuff))
cat("\nFanGraphs window (to 2026-08-17), same", nrow(fgw), "pitches: ours", round(validity(fgw)$whiff, 3),
    " FanGraphs", round(validity(fgw, fg_stuff)$whiff, 3), "\n")
cat("\nreliability (split-half):\n"); print(split_half(sc))
cat("\nspin_axis missing in 2026:", round(100 * mean(is.na(h$axis_diff)), 2), "%\n")
board <- season_board(sc, mu, sigma, 2026) |> add_fangraphs(FG26)
write_csv(board, file.path(out, "board_2026.csv"))
rm(dsc); gc()
oof <- run_cv(dev0, \(d) fit_whiff(d, V2), \(m, d) score_both_sides(m, d, V2))
fv <- known_answers(season_grades(oof))
cat("\nface validity on 2022-2025 (reported): elite in top 20%:", sum(fv$table$hit[fv$table$list == "elite"]),
    "of 15; weak in bottom 20%:", sum(fv$table$hit[fv$table$list == "weak"]), "of 4\n")
print(fv$table |> select(player_name, pitch_type, game_year, list, pct, hit))
