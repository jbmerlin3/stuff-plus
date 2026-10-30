# clean_pitches.R
# Raw Statcast pitches to the model's cleaned file.
#   Rscript scripts/clean_pitches.R                       2022-2025 development data
#   Rscript scripts/clean_pitches.R <in> <out> <season>   a holdout season, same filters

library(tidyverse)

# ---- Constants ----
SEASONS <- 2022:2025

KEEP_COLS <- c(
  "pitcher", "player_name", "game_year", "game_date",
  "game_pk", "at_bat_number", "pitch_number", "p_throws", "stand",
  "description", "events", "balls", "strikes", "delta_run_exp",
  "pitch_type", "release_speed", "release_spin_rate", "release_extension",
  "release_pos_x", "release_pos_z", "pfx_x", "pfx_z", "arm_angle", "spin_axis",
  "vx0", "vy0", "vz0", "ax", "ay", "az", "plate_z",
  "zone"   # for a reported location check, never a model input
)

NUMERIC_TYPES <- c("game_year", "game_pk", "at_bat_number", "pitch_number", "balls",
                   "strikes", "release_speed", "release_spin_rate", "release_extension",
                   "release_pos_x", "release_pos_z", "pfx_x", "pfx_z", "arm_angle",
                   "spin_axis", "plate_z", "zone", "delta_run_exp")

# Not real pitch outcomes (clock violations, pitchouts) or not stuff outcomes (bunts)
DROP_DESC <- c("automatic_ball", "automatic_strike", "pitchout",
               "foul_bunt", "missed_bunt", "bunt_foul_tip")

VALID_TYPES <- c("FF", "SI", "FC", "SL", "ST", "CU", "KC", "CH", "FS", "SV", "FO")

# A pitch missing a column the model doesn't use is kept
MODEL_INPUTS <- c("release_speed", "release_pos_x", "release_pos_z", "pfx_x", "pfx_z")

# Real soft-tossers under the 80 mph screen, checked by hand
REAL_PITCHERS <- c(
  448179L,  # Hill, Rich
  643511L,  # Rogers, Tyler
  502179L,  # Espino, Paolo
  642232L,  # Yarbrough, Ryan
  689690L,  # Jacob, Alek
  592222L,  # Claudio, Alex
  491624L,  # Valdez, César
  572383L,  # Moran, Brian
  676680L   # Cosgrove, Tom
)

# ---- Functions ----
log_step <- function(df, label) {
  message(label, ": ", format(nrow(df), big.mark = ","), " rows")
  df
}

load_pitches <- function(path) {
  readRDS(path) |>
    select(all_of(KEEP_COLS)) |>
    filter(game_year %in% SEASONS) |>
    mutate(pitcher = as.integer(pitcher)) |>
    # The 2022-2025 and 2026 sources store balls, strikes and zone as different types
    mutate(across(any_of(NUMERIC_TYPES), as.numeric), game_date = as.Date(game_date))
}

# Before any pitch-type filter, because FA and EP tags are the evidence
flag_position_players <- function(df) {
  df |>
    group_by(pitcher, player_name, game_year) |>
    summarise(n = n(),
              share_fa_ep = mean(pitch_type %in% c("FA", "EP")),
              mean_velo   = mean(release_speed, na.rm = TRUE),
              .groups = "drop") |>
    filter(share_fa_ep > 0.5 |
             (mean_velo < 80 & !pitcher %in% REAL_PITCHERS))
}

clean_pitches <- function(df, flagged) {
  df |>
    log_step("start") |>
    anti_join(flagged, by = c("pitcher", "game_year")) |>
    log_step("after position players") |>
    filter(!description %in% DROP_DESC) |>
    log_step("after description filter") |>
    filter(pitch_type %in% VALID_TYPES) |>
    log_step("after pitch type filter") |>
    drop_na(all_of(MODEL_INPUTS)) |>
    log_step("after missing features") |>
    filter(!is.na(delta_run_exp), balls < 4, strikes < 3) |>
    log_step("after target and count checks")
}

check_unique <- function(df) {
  n_unique <- df |> distinct(game_pk, at_bat_number, pitch_number) |> nrow()
  stopifnot(n_unique == nrow(df))
  message("No duplicate pitches")
}

# ---- Run ----
args <- commandArgs(trailingOnly = TRUE)
in_path  <- if (length(args) >= 1) args[1] else "data/pitches_all_master.rds"
out_path <- if (length(args) >= 2) args[2] else "data/pitches_clean.rds"
if (length(args) >= 3) SEASONS <- as.integer(args[3])
flag_path <- file.path("outputs", paste0(sub("\\.rds$", "", basename(out_path)), "_position_players.csv"))
dir.create("outputs", showWarnings = FALSE)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

all_pitches <- load_pitches(in_path)
gc()
stopifnot(!anyNA(all_pitches$pitcher))

flagged <- flag_position_players(all_pitches)
message("Flagged pitcher-seasons: ", nrow(flagged))
write_csv(flagged, flag_path)

pitches_clean <- clean_pitches(all_pitches, flagged)
check_unique(pitches_clean)

saveRDS(pitches_clean, out_path)
