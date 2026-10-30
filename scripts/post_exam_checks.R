# post_exam_checks.R
# Follow-up questions asked after the exam, on data it already used. Descriptive; none changed the model.
#   Rscript scripts/post_exam_checks.R

suppressMessages({ library(tidyverse); source("R/validity.R"); source("R/scale.R"); source("R/leaderboards.R"); source("R/reported.R") })
exam  <- readRDS("outputs/v2_exam/exam.rds")$scored
dev   <- readRDS("data/pitches_clean.rds")
hold  <- readRDS("data/holdout/pitches_clean_2026.rds")
scale <- read_csv("models/stuff_v2_scale.csv", show_col_types = FALSE)

# ---- 1. Returning pitchers against pitchers new in 2026 ----
po <- pitch_outcomes(exam) |> mutate(returning = pitcher %in% dev$pitcher)
cat("Within-type whiff r, 2026:\n")
print(po |> filter(pitch_type %in% GRADED_TYPES) |>
        summarise(r = within_r(pick(everything()), grade, whiff), rows = n(), .by = returning))

set.seed(3)
boot_new <- map_dbl(1:1000, \(i) {
  new <- po |> filter(!returning, pitch_type %in% GRADED_TYPES)
  ids <- unique(new$pitcher)
  picks <- sample(ids, replace = TRUE)
  within_r(map(picks, \(id) filter(new, pitcher == id)) |> list_rbind(), grade, whiff)
})
cat("New pitchers, pitcher-clustered bootstrap 95% interval:", round(quantile(boot_new, c(0.025, 0.975), na.rm = TRUE), 2), "\n")

# ---- Naive baselines on the same 2026 rows ----
last_year <- dev |> filter(game_year == 2025) |>
  summarise(n_prev = n(), prev_whiff = sum(description %in% WHIFF_DESC) / sum(description %in% SWING_DESC),
            .by = c(pitcher, pitch_type)) |> filter(n_prev >= 100)
velo <- exam |> summarise(velo = mean(release_speed), .by = c(pitcher, game_year, pitch_type))
base <- po |> filter(pitch_type %in% GRADED_TYPES) |> left_join(velo, by = c("pitcher", "game_year", "pitch_type"))
paired <- base |> inner_join(last_year, by = c("pitcher", "pitch_type"))
cat("\nNaive baselines, within-type whiff r, 2026:\n")
print(tibble(check = c("velocity alone", "Stuff+ on rows with a 2025 whiff rate", "2025 whiff rate, 100+ pitches"),
             r = c(within_r(base, velo, whiff), within_r(paired, grade, whiff), within_r(paired, prev_whiff, whiff)),
             rows = c(nrow(base), nrow(paired), nrow(paired))))

# ---- FanGraphs on both outcomes, its 2026 window ----
if (file.exists(FG_2026)) {
  fgw <- pitch_outcomes(filter(exam, game_date <= as.Date("2026-08-17"))) |> add_fangraphs(FG_2026) |> filter(!is.na(fg_stuff))
  ours <- validity(fgw); theirs <- validity(fgw, fg_stuff)
  cat("\nSame", nrow(fgw), "rows. Whiff per swing: ours", round(ours$whiff, 3), "FanGraphs", round(theirs$whiff, 3),
      "\nRun value on swings: ours", round(ours$rv_swing, 3), "FanGraphs", round(theirs$rv_swing, 3), "\n")
}

# ---- Does location leak into v2? ----
cat("\nGrade vs zone rate by pitch type, 2026, 100+ pitches:\n")
print(location_check(exam) |> mutate(r_grade_zone = round(r_grade_zone, 3)) |> arrange(pitch_type))

# ---- Size of the axis differential ----
cat("\nMedian absolute axis differential by pitch type, 2026:\n")
print(exam |> summarise(median_abs = round(median(abs(axis_diff), na.rm = TRUE), 1), .by = pitch_type) |> arrange(median_abs))

# ---- 2. Same-side minus opposite-side prediction by pitch type ----
cat("\nSame-side minus opposite-side predicted whiff, 2026:\n")
print(exam |> summarise(same_minus_opp = round(mean(pred_same - pred_opp), 4), pitches = n(), .by = pitch_type) |>
        arrange(-same_minus_opp))

# ---- 3. Does extension explain four-seam whiffs beyond the grade? ----
ext <- hold |> filter(pitch_type == "FF") |>
  summarise(ext = mean(release_extension, na.rm = TRUE), .by = c(pitcher))
ff <- function(min_n) {
  d <- pitch_outcomes(exam, min_n) |> filter(pitch_type == "FF") |> inner_join(ext, by = "pitcher") |> drop_na(ext)
  partial <- cor(resid(lm(whiff ~ grade, d)), resid(lm(ext ~ grade, d)))
  tibble(min_pitches = min_n, rows = nrow(d), partial_r = round(partial, 3))
}
cat("\nExtension vs whiff per swing given the grade, 2026 FF:\n"); print(bind_rows(ff(250), ff(50)))

# ---- 4. Four-seam whiff by release height and side decile, 2022-2025 ----
deciles <- dev |> filter(pitch_type == "FF") |>
  mutate(side = if_else(p_throws == "L", release_pos_x, -release_pos_x)) |>
  summarise(n = n(), whiff = 100 * sum(description %in% WHIFF_DESC) / sum(description %in% SWING_DESC),
            ride = mean(pfx_z * 12), ht = mean(release_pos_z), side = mean(side),
            .by = c(pitcher, game_year)) |>
  filter(n >= 250)
cat("\nFour-seam pitcher-seasons:", nrow(deciles), "\nBy release height decile:\n")
print(deciles |> mutate(decile = ntile(ht, 10)) |> summarise(whiff = round(mean(whiff), 1), ride = round(mean(ride), 1), .by = decile) |> arrange(decile))
cat("By release side decile:\n")
print(deciles |> mutate(decile = ntile(side, 10)) |> summarise(whiff = round(mean(whiff), 1), .by = decile) |> arrange(decile))

# ---- 5. Grades that read against reputation ----
named <- function(who, type) {
  bind_rows(dev |> select(player_name, pitch_type, game_year, description),
            hold |> select(player_name, pitch_type, game_year, description)) |>
    summarise(n = n(), whiff_pct = round(100 * sum(description %in% WHIFF_DESC) / sum(description %in% SWING_DESC), 1),
              .by = c(player_name, pitch_type, game_year)) |>
    filter(n >= 250, pitch_type == type) |>
    mutate(whiff_rank = min_rank(-whiff_pct), of = n(), .by = game_year) |>
    filter(player_name == who) |> arrange(game_year)
}
cat("\nDuran splitter:\n"); print(named("Duran, Jhoan", "FS"))
cat("\nRogers sinker:\n"); print(named("Rogers, Tyler", "SI"))

board <- read_csv("results/leaderboard_2026.csv", show_col_types = FALSE)
cat("\n2026 grades:\n")
print(as.data.frame(board |> filter(n >= 250) |>
  filter((player_name == "Schlittler, Cam" & pitch_type == "FF") | (player_name == "Ekness, Josh" & pitch_type == "FF") |
         (player_name == "Duran, Jhoan" & pitch_type == "FS") | (player_name == "Rogers, Tyler" & pitch_type == "SI")) |>
  select(player_name, pitch_type, stuff_plus, n, whiff_pct, velo, ivb, release_ht)))
