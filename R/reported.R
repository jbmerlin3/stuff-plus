# reported.R
# Checks reported beside the v1 and v2 results. None of them decides a verdict.

library(tidyverse)

# ---- Linear baseline ----
fit_linear   <- function(train) lm(rv ~ release_speed + ivb + hb, data = train)
score_linear <- function(model, df) df |> mutate(pred = predict(model, df))

# ---- Stabilization ----
# Two random halves of n pitches; a high r at small n means the grade settles early
split_half <- function(oof, sizes = c(25, 50, 100, 200)) {
  set.seed(3)
  map(sizes, function(n) {
    oof |> group_by(pitcher, game_year, pitch_type) |> filter(n() >= 2 * n) |>
      slice_sample(n = 2 * n) |> mutate(half = rep(1:2, n)) |>
      group_by(half, .add = TRUE) |> summarise(g = mean(pred), .groups = "drop") |>
      pivot_wider(names_from = half, values_from = g) |>
      summarise(pitches = n, r = cor(`1`, `2`), cases = n())
  }) |> list_rbind()
}

# ---- Location ----
# A strong grade-to-zone-rate link would mean location leaked into "shape"
location_check <- function(oof) {
  oof |> summarise(n = n(), grade = mean(pred), zone_rate = mean(zone %in% 1:9),
                   .by = c(pitcher, game_year, pitch_type)) |>
    filter(n >= 100) |>
    summarise(r_grade_zone = cor(grade, zone_rate), cases = n(), .by = pitch_type)
}

# ---- Platoon split by pitch type ----
by_type <- function(oof) {
  oof |> summarise(mean_pred = mean(pred), same_minus_opp = mean(pred_same - pred_opp),
                   pitches = n(), .by = pitch_type) |> arrange(-same_minus_opp)
}

# ---- v1 final fit and feature contributions ----
final_fit <- function(p, inputs = INPUTS) {
  tab   <- rv_table(p)
  p     <- p |> left_join(tab, by = c("outcome", "balls", "strikes"))
  model <- fit_model(p, inputs = inputs)
  sc    <- score_both_sides(model, p, inputs)
  sg    <- sc |> summarise(n = n(), g = mean(pred), .by = c(pitcher, game_year, pitch_type))
  list(model = model, rv_table = tab,
       mu = mean(sc$pred), sigma = sd(sg$g[sg$n >= 100]),
       importance = xgb.importance(model = model))
}

explain_pitch <- function(model, p, who, type, year, inputs = INPUTS) {
  d <- p |> filter(player_name == who, pitch_type == type, game_year == year)
  contrib <- predict(model, xgb.DMatrix(to_matrix(d, inputs)), predcontrib = TRUE)
  colMeans(contrib)
}
