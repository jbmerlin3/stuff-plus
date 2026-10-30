# known.R
# Known-answer list, fixed before any fit. Names as Statcast writes them.

library(tidyverse)

KNOWN <- tribble(
  ~player_name,          ~pitch_type, ~game_year, ~list,
  "Strider, Spencer",    "FF", 2023, "elite",  "Miller, Mason",       "FF", 2024, "elite",
  "Misiorowski, Jacob",  "FF", 2025, "elite",  "Holmes, Clay",        "SI", 2022, "elite",
  "Clase, Emmanuel",     "FC", 2024, "elite",  "Strider, Spencer",    "SL", 2023, "elite",
  "Miller, Mason",       "SL", 2024, "elite",  "Ohtani, Shohei",      "ST", 2023, "elite",
  "Glasnow, Tyler",      "CU", 2024, "elite",  "Snell, Blake",        "CU", 2023, "elite",
  "Williams, Devin",     "CH", 2023, "elite",  "Skubal, Tarik",       "CH", 2024, "elite",
  "Skenes, Paul",        "FS", 2024, "elite",  "Senga, Kodai",        "FO", 2023, "elite",
  "Duran, Jhoan",        "FS", 2024, "elite",
  "Hendricks, Kyle",     "SI", 2024, "weak",   "Greinke, Zack",       "FF", 2023, "weak",
  "Corbin, Patrick",     "SI", 2023, "weak",   "Miley, Wade",         "FF", 2023, "weak"
)

# Percentile within pitch type and season at 250+ pitches. FO has one such season, so it ranks with FS.
known_answers <- function(sg) {
  ranked <- sg |>
    filter(n >= 250) |>
    mutate(pool = if_else(pitch_type == "FO", "FS", pitch_type)) |>
    mutate(pct = percent_rank(grade), .by = c(pool, game_year))
  hits <- KNOWN |>
    left_join(ranked, by = c("player_name", "pitch_type", "game_year")) |>
    mutate(hit = if_else(list == "elite", pct >= 0.80, pct <= 0.20))
  # A missing entry stops the run instead of being dropped
  stopifnot(!anyNA(hits$pct))
  list(table = hits,
       pass  = sum(hits$hit[hits$list == "elite"]) >= 10 &
               sum(hits$hit[hits$list == "weak"])  >= 3)
}
