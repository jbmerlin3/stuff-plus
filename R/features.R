library(tidyverse)

FASTBALLS <- c("FF", "SI", "FC")

# Arm side positive for every pitcher; glove-side pitches (sliders, sweepers,
# most cutters) stay negative. Statcast's x is from the catcher's view, where a
# righty's arm side is negative, so the RIGHTIES get the flip. The first version
# flipped lefties: hands matched but every sign was backwards (audit 2026-10-19)
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

# The fastball hitters time to: the HARDEST FF/SI/FC he throws at least 10% of
# the time and 20+ times that season. The floors stop a rare show-me 98 or a
# 4-pitch sample from becoming the baseline for his whole arsenal. If none
# qualifies, his most-thrown fastball. Most-thrown alone (the first rule) made a
# cutter-first pitcher's changeup look faster than his fastball (Brazoban).
# Built per pitcher-season from his own pitches, so it needs no fold
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

# No fastball at all leaves velo_gap missing, which XGBoost routes on its own.
# ivb_gap and hb_gap are used ONLY by the pre-registered changeup fallback (7a)
add_velo_gap <- function(df) {
  df |>
    left_join(primary_fastball(df), by = c("pitcher", "game_year")) |>
    mutate(velo_gap = release_speed - fb_velo,
           ivb_gap  = ivb - fb_ivb,
           hb_gap   = hb - fb_hb)
}

# Axis differential (v2 experiment 4): the gap between the spin axis Hawk-Eye
# measures and the axis implied by the ball's actual movement. A gap means
# something besides spin moved the ball (seam-shifted wake): the pitch breaks
# differently than its spin tells the hitter. Calibrated 2026-10-20: curveballs
# sit near 0 for both hands; sinkers, changeups and splitters run larger; the
# sign flips by hand, so lefties are mirrored
add_axis_diff <- function(df) {
  df |>
    mutate(move_axis = (180 + atan2(-pfx_x, pfx_z) * 180 / pi) %% 360,
           axis_diff = ((move_axis - spin_axis + 540) %% 360) - 180,
           axis_diff = if_else(lhp, -axis_diff, axis_diff)) |>
    select(-move_axis)
}
