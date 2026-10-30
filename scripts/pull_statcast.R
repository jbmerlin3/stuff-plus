# pull_statcast.R
# Raw Statcast from Baseball Savant, in three-day windows to stay under its 25,000-row cap.
# Savant revises pitches over time and row order changes, so a new pull won't reproduce the
# shipped model exactly. Use the release data for that (see the README).
#   Rscript scripts/pull_statcast.R                  all four seasons, to data/pitches_all_master.rds
#   Rscript scripts/pull_statcast.R <start> <end>    one window, to data/pull_<start>_<end>.rds

library(tidyverse)

SEASON_DATES <- tribble(
  ~start,        ~end,
  "2022-04-07",  "2022-10-05",
  "2023-03-30",  "2023-10-01",
  "2024-03-28",  "2024-09-29",
  "2025-03-27",  "2025-09-28"
)

# game_date_gt and game_date_lt are both inclusive, despite the names
savant_url <- function(start, end) {
  paste0("https://baseballsavant.mlb.com/statcast_search/csv?all=true&hfGT=R%7C",
         "&hfSea=", substr(start, 1, 4), "%7C&player_type=pitcher",
         "&game_date_gt=", start, "&game_date_lt=", end,
         "&min_pitches=0&min_results=0&type=details")
}

# Every column as text, so no type can clash on bind
pull_window <- function(start, end) {
  out <- read_csv(savant_url(start, end), col_types = cols(.default = col_character()), show_col_types = FALSE)
  if (nrow(out) >= 24000) warning("window ", start, " near the row cap, may be truncated")
  Sys.sleep(2)
  out
}

pull_range <- function(start, end) {
  starts <- seq(as.Date(start), as.Date(end), by = "3 days")
  map(starts, \(s) pull_window(as.character(s), as.character(min(s + 2, as.Date(end))))) |>
    list_rbind() |>
    distinct(game_pk, at_bat_number, pitch_number, .keep_all = TRUE)
}

args <- commandArgs(trailingOnly = TRUE)
dir.create("data", showWarnings = FALSE)
if (length(args) == 2) {
  saveRDS(pull_range(args[1], args[2]), sprintf("data/pull_%s_%s.rds", args[1], args[2]))
} else {
  pitches <- pmap(SEASON_DATES, pull_range) |> list_rbind() |>
    mutate(game_year = as.numeric(game_year))
  saveRDS(pitches, "data/pitches_all_master.rds")
}
