library(tidyverse)

# Reported, never gated (PREREG.md section 10, amendment 5)

# 1. Linear baseline: velo, IVB and HB in a straight line, same folds and target
fit_linear   <- function(train) lm(rv ~ release_speed + ivb + hb, data = train)
score_linear <- function(model, df) df |> mutate(pred = predict(model, df))

# 2. Stabilization: split each pitch's pitches into two random halves of n and
#    correlate the halves' grades. High r at small n = trust it early
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

# 3. Location: how strongly a grade tracks zone rate within each pitch type.
#    Strong = the target let location leak into "shape"
location_check <- function(oof) {
  oof |> summarise(n = n(), grade = mean(pred), zone_rate = mean(zone %in% 1:9),
                   .by = c(pitcher, game_year, pitch_type)) |>
    filter(n >= 100) |>
    summarise(r_grade_zone = cor(grade, zone_rate), cases = n(), .by = pitch_type)
}

# 4. Shape of the scale and of the platoon split, by pitch type. same_minus_opp
#    tests his prediction: largest for ST and SL, smallest for CU and FS
by_type <- function(oof) {
  oof |> summarise(mean_pred = mean(pred), same_minus_opp = mean(pred_same - pred_opp),
                   pitches = n(), .by = pitch_type) |> arrange(-same_minus_opp)
}

# 5. Final model on all of 2022-2025, the 100-scale constants, and what drives
#    grades. Built only after the gates are read
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

# Feature contributions for one pitch: which inputs pushed its grade up or down
explain_pitch <- function(model, p, who, type, year, inputs = INPUTS) {
  d <- p |> filter(player_name == who, pitch_type == type, game_year == year)
  contrib <- predict(model, xgb.DMatrix(to_matrix(d, inputs)), predcontrib = TRUE)
  colMeans(contrib)
}
