# export_v2.R
# Refit frozen v2 on all 2022-2025 swings and score 2026.
#   Rscript scripts/export_v2.R             models/ and outputs/scored_2026.rds
#   Rscript scripts/export_v2.R <app_dir>   also writes the files the app reads

suppressMessages({ source("R/cv.R"); source("R/validity.R"); source("R/scale.R") })
app <- commandArgs(trailingOnly = TRUE)[1]
V2 <- c(INPUTS, "axis_diff")

# ---- Model and scale, from 2022-2025 ----
dev   <- prep_pitches()
model <- fit_whiff(dev, V2)
dsc   <- score_both_sides(model, dev, V2)
scale <- scale_constants(dsc) |>
  mutate(version = "v2", trained_on = "2022-2025 swings", built = as.character(Sys.Date()))
dir.create("models", showWarnings = FALSE); dir.create("outputs", showWarnings = FALSE)
xgb.save(model, "models/stuff_v2.ubj"); write_csv(scale, "models/stuff_v2_scale.csv")
rm(dsc, dev); gc()

# ---- Score 2026 ----
h <- prep_pitches("data/holdout/pitches_clean_2026.rds")
sc <- score_both_sides(model, h, V2) |>
  mutate(pitch_type = app_label(pitch_type),
         pred_side = if_else(same_side == 1L, pred_same, pred_opp))
saveRDS(sc, "outputs/scored_2026.rds")

# ---- Daily sums for the app ----
# Any date window and batter side is then a sum over rows, so the app never runs the model:
#   All   sum(s_both) / sum(n) over both sides (every throw scored 50/50)
#   vs R  sum(s_side) / sum(n) over stand == "R"
daily <- sc |>
  summarise(n = n(), s_both = sum(pred), s_side = sum(pred_side),
            .by = c(pitcher, game_date, pitch_type, stand)) |>
  mutate(game_date = as.character(game_date), across(c(s_both, s_side), \(x) signif(x, 7)))
if (!is.na(app)) {
  write_csv(daily, file.path(app, "lookups", "stuff_v2_2026.csv"))
  write_csv(scale, file.path(app, "lookups", "stuff_v2_scale.csv"))
}
cat(nrow(daily), "daily rows\n")
print(as.data.frame(scale |> select(group, mu, sigma, pitches, pitch_types)))
