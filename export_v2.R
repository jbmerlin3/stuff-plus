# Rscript export_v2.R <app_dir>
# Frozen v2 (PREREG_v2.md): refit on all 2022-2025 swings exactly as the exam
# did, save the model for next season, score 2026, and write what the app needs.
suppressMessages({ source("R/cv.R"); source("R/validity.R") })
app <- commandArgs(trailingOnly = TRUE)[1]; stopifnot(dir.exists(app))
V2 <- c(INPUTS, "axis_diff")

dev   <- prep_pitches()
model <- fit_whiff(dev, V2)
dsc   <- score_both_sides(model, dev, V2)
dsg   <- dsc |> summarise(n = n(), g = mean(pred), .by = c(pitcher, game_year, pitch_type))
scale <- tibble(mu = mean(dsc$pred), sigma = sd(dsg$g[dsg$n >= 100]), version = "v2",
                trained_on = "2022-2025 swings", built = as.character(Sys.Date()))
dir.create("models", showWarnings = FALSE)
xgb.save(model, "models/stuff_v2.ubj"); write_csv(scale, "models/stuff_v2_scale.csv")
rm(dsc, dev); gc()

# The app folds KC and CS into CU and FO into FS (its PITCH_CODE_RULES), so the
# grades must use the same labels or they will not join
h <- prep_pitches("data/holdout/pitches_clean_2026.rds")
sc <- score_both_sides(model, h, V2) |>
  mutate(pitch_type = case_when(pitch_type %in% c("KC", "CS") ~ "CU",
                                pitch_type == "FO" ~ "FS", TRUE ~ pitch_type),
         pred_side = if_else(same_side == 1L, pred_same, pred_opp))
saveRDS(sc, "outputs/scored_2026.rds")

# Daily sums by pitcher, date, pitch type and batter side. Any date window and
# either batter side is then a sum over rows, so the app never runs the model:
#   All   -> sum(s_both) / sum(n) over both sides (every throw scored 50/50)
#   vs R  -> sum(s_side) / sum(n) over stand == "R" (throws to righties, as righties)
daily <- sc |>
  summarise(n = n(), s_both = sum(pred), s_side = sum(pred_side),
            .by = c(pitcher, game_date, pitch_type, stand)) |>
  mutate(game_date = as.character(game_date), across(c(s_both, s_side), \(x) signif(x, 7)))
write_csv(daily, file.path(app, "lookups", "stuff_v2_2026.csv"))
write_csv(scale, file.path(app, "lookups", "stuff_v2_scale.csv"))
cat("wrote", nrow(daily), "daily rows;", format(file.size(file.path(app, "lookups", "stuff_v2_2026.csv")) / 1e6, digits = 2), "MB\n")
cat("scale: mu", signif(scale$mu, 6), " sigma", signif(scale$sigma, 6), "\n")
