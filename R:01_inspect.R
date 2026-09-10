library(tidyverse)

# Split lives here so every later script reads the same years
TRAIN_YEARS <- 2022:2024
TEST_YEAR   <- 2025

raw <- readRDS("data/pitches_all_master.rds")

keep_cols <- c(
  # Identity and grouping. game_pk + at_bat_number + pitch_number uniquely
  # identify a pitch, which matters for catching duplicate rows
  "pitcher", "player_name", "game_year", "game_date",
  "game_pk", "at_bat_number", "pitch_number", "p_throws", "stand",
  
  # Target. description drives isCSW, balls/strikes drive the count adjustment
  "description", "balls", "strikes",
  
  # Features, pitch shape and release
  "pitch_type", "release_speed", "release_spin_rate", "release_extension",
  "release_pos_x", "release_pos_z", "pfx_x", "pfx_z", "arm_angle", "spin_axis",
  
  # Trajectory, only needed if you build a height-adjusted VAA feature
  "vx0", "vy0", "vz0", "ax", "ay", "az", "plate_z"
)

# 2026 is a partial pull, so only complete seasons go in.
# game_type is dropped because every row is already regular season
all_pitches <- raw |>
  select(all_of(keep_cols)) |>
  filter(game_year %in% c(TRAIN_YEARS, TEST_YEAR))

rm(raw)
gc()

# Memory check on the slim frame, since this Mac tops out at 8 GB
format(object.size(all_pitches), units = "GB")

# 1. Coverage. Full seasons run roughly 700k pitches
all_pitches |>
  group_by(game_year) |>
  summarise(n = n(), first = min(game_date), last = max(game_date))

# 2. Every outcome string, so the isCSW map covers all of them
all_pitches |> count(description, sort = TRUE) |> print(n = Inf)

# 3. Missingness by year. A column missing only in early seasons is a
#    different problem from one missing everywhere
feature_cols <- c("release_speed", "release_spin_rate", "release_extension",
                  "release_pos_x", "release_pos_z", "pfx_x", "pfx_z",
                  "arm_angle", "spin_axis", "plate_z")

all_pitches |>
  group_by(game_year) |>
  summarise(across(all_of(feature_cols), \(x) round(mean(is.na(x)), 3))) |>
  print(width = Inf)

# 4. Pitch type codes, including rare ones, to see if the cache was pre-filtered
all_pitches |> count(pitch_type, sort = TRUE) |> print(n = Inf)



position_players <- all_pitches |>
  group_by(pitcher, player_name, game_year) |>
  summarise(n = n(),
            share_fa_ep = mean(pitch_type %in% c("FA", "EP")),
            mean_velo = mean(release_speed, na.rm = TRUE),
            .groups = "drop") |>
  filter(share_fa_ep > 0.5)

position_players |> arrange(desc(mean_velo)) |> print(n = 20)



# Position players pitch in blowouts at 60 to 75 mph and would drag down
# every fastball baseline and outcome rate they touch
all_pitches <- all_pitches |>
  anti_join(position_players, by = c("pitcher", "game_year"))



all_pitches |>
  group_by(pitcher, player_name, game_year) |>
  summarise(n = n(), mean_velo = mean(release_speed, na.rm = TRUE),
            .groups = "drop") |>
  filter(mean_velo < 80) |>
  arrange(mean_velo)


low_velo <- all_pitches |>
  group_by(pitcher, player_name, game_year) |>
  summarise(n = n(),
            mean_velo = mean(release_speed, na.rm = TRUE),
            max_velo  = max(release_speed, na.rm = TRUE),
            types     = paste(sort(unique(pitch_type)), collapse = " "),
            .groups = "drop") |>
  filter(mean_velo < 80) |>
  arrange(desc(max_velo))

low_velo |> print(n = Inf)





# Real soft-tossers who fall under the 80 mph screen, checked by hand.
# pitcher is character in this file, so IDs are quoted
real_pitchers <- c(
  "448179",  # Hill, Rich
  "643511",  # Rogers, Tyler
  "502179",  # Espino, Paolo
  "642232",  # Yarbrough, Ryan
  "689690",  # Jacob, Alek
  "592222",  # Claudio, Alex
  "491624",  # Valdez, César
  "572383"   # Moran, Brian
)

low_velo_pp <- low_velo |> filter(!pitcher %in% real_pitchers)
nrow(low_velo_pp)   # should be 26

all_pitches <- all_pitches |>
  anti_join(low_velo_pp, by = c("pitcher", "game_year"))