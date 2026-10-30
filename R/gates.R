# gates.R
# v1's four pre-registered gates, on raw out-of-fold predictions.

library(tidyverse)

FAMILY <- c(FF = "fastball", SI = "fastball", FC = "fastball",
            SL = "breaking", ST = "breaking", SV = "breaking", CU = "breaking",
            KC = "breaking", CH = "offspeed", FS = "offspeed", FO = "offspeed")
GATE3_TYPES <- c("FF", "SI", "SL", "ST", "CU", "CH")

# One row per pitcher, season and pitch type: mean prediction and runs per 100 pitches
season_grades <- function(oof) {
  oof |> summarise(n = n(), grade = mean(pred), rv100 = 100 * mean(rv),
                   .by = c(pitcher, player_name, game_year, pitch_type))
}

# Same pitcher and pitch type, 100+ pitches in season t and t+1
year_pairs <- function(sg, min_n = 100) {
  sg <- sg |> filter(n >= min_n)
  inner_join(sg, sg |> mutate(game_year = game_year - 1),
             by = c("pitcher", "game_year", "pitch_type"), suffix = c("", "_next")) |>
    mutate(family = FAMILY[pitch_type])
}

# Gate 1: does the grade predict next season better than this season's results do?
edge <- function(d) cor(d$grade, d$rv100_next) - cor(d$rv100, d$rv100_next)

# Gate 3: grade vs next season, every pitch type centered on its own mean
within_type_r <- function(d) {
  d <- d |> filter(pitch_type %in% GATE3_TYPES) |>
    mutate(across(c(grade, rv100_next), \(x) x - mean(x)), .by = pitch_type)
  cor(d$grade, d$rv100_next)
}

# Resamples whole pitchers, since one pitcher's rows aren't independent
boot_ci <- function(d, stat, reps = 1000) {
  set.seed(3)
  ids <- unique(d$pitcher)
  by_p <- split(d, d$pitcher)
  draws <- map_dbl(1:reps, \(i) stat(list_rbind(by_p[as.character(sample(ids, replace = TRUE))])))
  c(estimate = stat(d), lo = unname(quantile(draws, 0.025)), hi = unname(quantile(draws, 0.975)))
}

run_gates <- function(oof) {
  sg <- season_grades(oof)
  yp <- year_pairs(sg)
  g1 <- boot_ci(yp, edge)
  g2 <- yp |> summarise(edge = edge(pick(everything())), pairs = n(), .by = family)
  g3 <- boot_ci(yp, within_type_r)
  g3_types <- yp |> filter(pitch_type %in% GATE3_TYPES) |>
    summarise(r = cor(grade, rv100_next), pairs = n(), .by = pitch_type)
  g4 <- known_answers(sg)
  list(
    gate1 = g1, gate2 = g2, gate3 = g3, gate3_types = g3_types, gate4 = g4$table,
    pass = c(gate1 = unname(g1["lo"] > 0),
             gate2 = all(g2$edge > 0),
             gate3 = unname(g3["lo"] > 0) & sum(g3_types$r > 0) >= 5,
             gate4 = g4$pass)
  )
}
