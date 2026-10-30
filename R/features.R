# features.R
# Model inputs built from one pitch or from the pitcher's own season.

library(tidyverse)

FASTBALLS <- c("FF", "SI", "FC")

# Arm side positive for both hands. Statcast x is from the catcher's view, where
# a righty's arm side is negative, so righties flip.
add_shape <- function(df) {
  df |>
    mutate(
      lhp           = p_throws == "L",
      ivb           = pfx_z * 12,
      hb            = if_else(lhp, pfx_x, -pfx_x) * 12,
      release_side  = if_else(lhp, release_pos_x, -release_pos_x),
      release_ht    = release_pos_z,
      same_side     = as.integer(stand == p_throws)
    )
}

# Hardest FF/SI/FC thrown 10%+ of the time and 20+ times that season, else his most-thrown fastball
primary_fastball <- function(df) {
  fb <- df |>
    group_by(pitcher, game_year) |>
    mutate(season_n = n()) |>
    filter(pitch_type %in% FASTBALLS) |>
    group_by(pitcher, game_year, pitch_type) |>
    summarise(n_fb = n(), share = n() / first(season_n),
              fb_velo = mean(release_speed), fb_ivb = mean(ivb), fb_hb = mean(hb),
              .groups = "drop") |>
    mutate(qualifies = share >= 0.10 & n_fb >= 20)

  hardest  <- fb |> filter(qualifies) |>
    slice_max(fb_velo, n = 1, with_ties = FALSE, by = c(pitcher, game_year))
  fallback <- fb |> anti_join(hardest, by = c("pitcher", "game_year")) |>
    slice_max(n_fb, n = 1, with_ties = FALSE, by = c(pitcher, game_year))

  bind_rows(hardest, fallback) |>
    transmute(pitcher, game_year, fb_type = pitch_type, fb_velo, fb_ivb, fb_hb,
              fb_rule = if_else(qualifies, "hardest", "fallback"))
}

# No fastball leaves velo_gap NA, which XGBoost routes on its own.
# ivb_gap and hb_gap are not v2 inputs; only the development experiments use them.
add_velo_gap <- function(df) {
  df |>
    left_join(primary_fastball(df), by = c("pitcher", "game_year")) |>
    mutate(velo_gap = release_speed - fb_velo,
           ivb_gap  = ivb - fb_ivb,
           hb_gap   = hb - fb_hb)
}

# Movement axis minus measured spin axis: a gap means something besides spin moved
# the ball. The sign flips by hand, so lefties are mirrored.
add_axis_diff <- function(df) {
  df |>
    mutate(move_axis = (180 + atan2(-pfx_x, pfx_z) * 180 / pi) %% 360,
           axis_diff = ((move_axis - spin_axis + 540) %% 360) - 180,
           axis_diff = if_else(lhp, -axis_diff, axis_diff)) |>
    select(-move_axis)
}
