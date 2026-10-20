library(tidyverse)

# ---- Constants ---------------------------------------------------------------
# Validation holds out pitchers, not a season (PREREG.md section 6), so all four
# complete seasons are cleaned together. 2026 stays out until v1 is judged
SEASONS <- 2022:2025

KEEP_COLS <- c(
  "pitcher", "player_name", "game_year", "game_date",
  "game_pk", "at_bat_number", "pitch_number", "p_throws", "stand",
  "description", "events", "balls", "strikes", "delta_run_exp",
  "pitch_type", "release_speed", "release_spin_rate", "release_extension",
  "release_pos_x", "release_pos_z", "pfx_x", "pfx_z", "arm_angle", "spin_axis",
  "vx0", "vy0", "vz0", "ax", "ay", "az", "plate_z",
  "zone"   # for the reported location check (amendment 5), never a model input
)

# Not real pitch outcomes (clock violations, pitchouts) or not stuff outcomes (bunts)
DROP_DESC <- c("automatic_ball", "automatic_strike", "pitchout",
               "foul_bunt", "missed_bunt", "bunt_foul_tip")

# FO added 2026-10-19: Senga's ghost fork is tagged FO, and leaving it out
# silently dropped every forkball
VALID_TYPES <- c("FF", "SI", "FC", "SL", "ST", "CU", "KC", "CH", "FS", "SV", "FO")

# Only the columns the model will use. A row missing spin_axis shouldn't be
# dropped if spin_axis never becomes a feature
# Spin is not an input (DECISIONS.md), so a pitch missing spin is kept
MODEL_INPUTS <- c("release_speed", "release_pos_x", "release_pos_z", "pfx_x", "pfx_z")

# Real soft-tossers who fall under the 80 mph screen, checked by hand Sept 2026.
# Revisit whenever a season is added
REAL_PITCHERS <- c(
  448179L,  # Hill, Rich
  643511L,  # Rogers, Tyler
  502179L,  # Espino, Paolo
  642232L,  # Yarbrough, Ryan
  689690L,  # Jacob, Alek
  592222L,  # Claudio, Alex
  491624L,  # Valdez, César
  572383L   # Moran, Brian
)

# ---- Functions ---------------------------------------------------------------

# Returns the data unchanged so it can sit anywhere in a pipe
log_step <- function(df, label) {
  message(label, ": ", format(nrow(df), big.mark = ","), " rows")
  df
}

# The raw frame lives only inside this function, so its 3.8 GB is freed on return
load_pitches <- function(path) {
  readRDS(path) |>
    select(all_of(KEEP_COLS)) |>
    filter(game_year %in% SEASONS) |>
    # Integer IDs so joins to FanGraphs xMLBAMID work later
    mutate(pitcher = as.integer(pitcher))
}

# Computed before any pitch-type filtering, because FA and EP tags are the evidence
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
    # %in% returns FALSE for NA, so untagged pitches drop here too
    filter(pitch_type %in% VALID_TYPES) |>
    log_step("after pitch type filter") |>
    drop_na(all_of(MODEL_INPUTS)) |>
    log_step("after missing features") |>
    # No run value means no target; a 4-ball or 3-strike count is a data error
    filter(!is.na(delta_run_exp), balls < 4, strikes < 3) |>
    log_step("after target and count checks")
}

# One row per pitch, or the script stops
check_unique <- function(df) {
  n_unique <- df |> distinct(game_pk, at_bat_number, pitch_number) |> nrow()
  stopifnot(n_unique == nrow(df))
  message("No duplicate pitches")
}

# ---- Run ---------------------------------------------------------------------
all_pitches <- load_pitches("data/pitches_all_master.rds")
gc()
stopifnot(!anyNA(all_pitches$pitcher))

flagged <- flag_position_players(all_pitches)
message("Flagged pitcher-seasons: ", nrow(flagged))
write_csv(flagged, "outputs/position_players_excluded.csv")

pitches_clean <- clean_pitches(all_pitches, flagged)
check_unique(pitches_clean)

saveRDS(pitches_clean, "data/pitches_clean.rds")