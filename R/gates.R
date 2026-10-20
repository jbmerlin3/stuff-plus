library(tidyverse)

FAMILY <- c(FF = "fastball", SI = "fastball", FC = "fastball",
            SL = "breaking", ST = "breaking", SV = "breaking", CU = "breaking",
            KC = "breaking", CH = "offspeed", FS = "offspeed", FO = "offspeed")
GATE3_TYPES <- c("FF", "SI", "SL", "ST", "CU", "CH")

# One row per pitcher x season x pitch type: raw grade (mean prediction) and
# what the pitch actually produced, in runs per 100 pitches
season_grades <- function(oof) {
  oof |> summarise(n = n(), grade = mean(pred), rv100 = 100 * mean(rv),
                   .by = c(pitcher, player_name, game_year, pitch_type))
}

# Same pitcher and pitch type, 100+ pitches in season t AND t+1 (section 6)
year_pairs <- function(sg, min_n = 100) {
  sg <- sg |> filter(n >= min_n)
  inner_join(sg, sg |> mutate(game_year = game_year - 1),
             by = c("pitcher", "game_year", "pitch_type"), suffix = c("", "_next")) |>
    mutate(family = FAMILY[pitch_type])
}

# Gate 1's statistic: does the grade predict next season better than this
# season's results do?
edge <- function(d) cor(d$grade, d$rv100_next) - cor(d$rv100, d$rv100_next)

# Gate 3's statistic: grade vs next season within type, every type centered on
# its own mean, so "sweepers are good" contributes nothing
within_type_r <- function(d) {
  d <- d |> filter(pitch_type %in% GATE3_TYPES) |>
    mutate(across(c(grade, rv100_next), \(x) x - mean(x)), .by = pitch_type)
  cor(d$grade, d$rv100_next)
}

# Pitcher-clustered bootstrap: resample whole pitchers, since one pitcher's
# pitch types and seasons are not independent of each other
boot_ci <- function(d, stat, reps = 1000) {
  set.seed(3)
  ids <- unique(d$pitcher)
  by_p <- split(d, d$pitcher)
  draws <- map_dbl(1:reps, \(i) stat(list_rbind(by_p[as.character(sample(ids, replace = TRUE))])))
  c(estimate = stat(d), lo = unname(quantile(draws, 0.025)), hi = unname(quantile(draws, 0.975)))
}
