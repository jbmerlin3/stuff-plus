install.packages("renv")
renv::init()

lock <- readLines("~/statcast-arsenal-app/renv.lock")
grep('"xgboost"', lock, value = TRUE)
lock[grep('"xgboost"', lock) + 2]
renv::install(c("tidyverse", "xgboost"))
packageVersion("xgboost")


library(tidyverse)

all_pitches <- readRDS("data/pitches_all_master.rds")

# Memory check first, since this Mac tops out at 8 GB
format(object.size(all_pitches), units = "GB")

names(pitches)

# 1. Coverage. Full seasons run roughly 700k pitches, so a short year means a partial pull
all_pitches |>
  group_by(game_year) |>
  summarise(n = n(), first = min(game_date), last = max(game_date))

# 2. Every outcome string, so the isCSW map covers all of them
pitches |> count(description, sort = TRUE) |> print(n = Inf)

# 3. Missingness on the model inputs. any_of() skips a column instead of
#    erroring if the name doesn't exist
feature_cols <- c("release_speed", "release_spin_rate", "release_extension",
                  "release_pos_x", "release_pos_z", "pfx_x", "pfx_z",
                  "arm_angle", "spin_axis", "plate_z")

pitches |>
  group_by(game_year) |>
  summarise(across(any_of(feature_cols), \(x) round(mean(is.na(x)), 3))) |>
  print(width = Inf)

# 4. Pitch type codes, including rare ones, to see if the cache was pre-filtered
pitches |> count(pitch_type, sort = TRUE) |> print(n = Inf)