# test_features.R
# Inputs and scale on small literal fixtures, so it runs without any data.

suppressMessages({ library(tidyverse); source("R/cv.R"); source("R/scale.R") })

pitch <- function(p_throws, pitch_type = "FF", release_speed = 95, pfx_x = 0.5, pfx_z = 1,
                  release_pos_x = 2, release_pos_z = 6, spin_axis = 180, stand = "R",
                  pitcher = 1L, game_year = 2025) {
  tibble(p_throws, pitch_type, release_speed, pfx_x, pfx_z, release_pos_x, release_pos_z,
         spin_axis, stand, pitcher, game_year)
}

# ---- Mirroring ----
# A righty's arm-side sinker has negative Statcast pfx_x and release_pos_x; a lefty's has positive
r <- add_shape(pitch("R", pfx_x = -1, release_pos_x = -2))
l <- add_shape(pitch("L", pfx_x = 1, release_pos_x = 2))
stopifnot(r$hb == 12, l$hb == 12, r$release_side == 2, l$release_side == 2)
stopifnot(r$same_side == 1L, l$same_side == 0L)
stopifnot(add_shape(pitch("R", pfx_x = 1))$hb == -12)   # glove side stays negative

# ---- Velo gap baseline ----
# Mostly cutters at 88 with a 97 four-seamer: baseline is the hardest qualifying, not most-thrown
arsenal <- bind_rows(
  map(1:60, \(i) pitch("R", "FC", 88)), map(1:25, \(i) pitch("R", "FF", 97)),
  map(1:25, \(i) pitch("R", "CH", 86))) |> add_shape() |> add_velo_gap()
stopifnot(all(arsenal$fb_type == "FF"), all(arsenal$velo_gap[arsenal$pitch_type == "CH"] == -11))

# A rare show-me fastball under 10% doesn't qualify
rare <- bind_rows(
  map(1:95, \(i) pitch("R", "SI", 92)), map(1:5, \(i) pitch("R", "FF", 99))) |> add_shape() |> add_velo_gap()
stopifnot(all(rare$fb_type == "SI"))

# Nothing qualifies: most-thrown. No fastball at all: NA, which XGBoost routes.
thin <- bind_rows(map(1:5, \(i) pitch("R", "SI", 90)), map(1:3, \(i) pitch("R", "FF", 94))) |>
  add_shape() |> add_velo_gap()
stopifnot(all(thin$fb_rule == "fallback"), all(thin$fb_type == "SI"))
none <- pitch("R", "CU", 80) |> add_shape() |> add_velo_gap()
stopifnot(is.na(none$velo_gap))

# ---- Axis differential ----
# Spin axis matching the movement axis gives 0; the same physical gap flips sign by hand
move_axis <- function(pfx_x, pfx_z) (180 + atan2(-pfx_x, pfx_z) * 180 / pi) %% 360
match <- pitch("R", pfx_x = -1, pfx_z = 1, spin_axis = move_axis(-1, 1)) |> add_shape() |> add_axis_diff()
stopifnot(abs(match$axis_diff) < 1e-9)
ar <- pitch("R", pfx_x = 0, pfx_z = 1, spin_axis = 170) |> add_shape() |> add_axis_diff()
al <- pitch("L", pfx_x = 0, pfx_z = 1, spin_axis = 170) |> add_shape() |> add_axis_diff()
stopifnot(ar$axis_diff == 10, al$axis_diff == -10)
# Wraps across 0/360: movement axis 350, spin axis 10
wrap <- pitch("R", pfx_x = -sin(170 * pi / 180), pfx_z = cos(170 * pi / 180), spin_axis = 10)
stopifnot(abs(add_axis_diff(add_shape(wrap))$axis_diff + 20) < 1e-9)

# ---- Target ----
stopifnot(outcome("strikeout", "swinging_strike") == "strikeout",
          outcome(NA, "foul_tip") == "whiff",
          outcome("field_error", "hit_into_play") == "field_out",
          is.na(outcome("sac_bunt", "hit_into_play")))
stopifnot(all(WHIFF_DESC %in% SWING_DESC), "foul" %in% SWING_DESC, !"foul" %in% WHIFF_DESC)

# ---- Scale ----
codes <- c("FF", "SI", "FC", "CH", "FS", "FO", "SL", "ST", "SV", "CU", "KC")
stopifnot(!anyNA(stuff_group(codes)), stuff_group("KN") |> is.na())
stopifnot(identical(stuff_group(app_label(codes)), stuff_group(codes)))   # the app's fold never changes a group
stopifnot(app_label("KC") == "CU", app_label("FO") == "FS", app_label("ST") == "ST")
stopifnot(to_stuff_plus(0.25, 0.2, 0.05) == 110)

# mu weighs pitches; sigma uses only rows with 100+ pitches
scored <- bind_rows(
  tibble(pitcher = 1L, game_year = 2025, pitch_type = "FF", pred = rep(0.20, 100)),
  tibble(pitcher = 2L, game_year = 2025, pitch_type = "SI", pred = rep(0.30, 100)),
  tibble(pitcher = 3L, game_year = 2025, pitch_type = "FF", pred = rep(0.90, 50)))
k <- scale_constants(scored)
stopifnot(nrow(k) == 1, k$group == "fastball", k$pitches == 250, k$pitch_types == 2,
          abs(k$sigma - sd(c(0.2, 0.3))) < 1e-12, abs(k$mu - 0.38) < 1e-12)

message("ALL FEATURE TESTS PASS")
