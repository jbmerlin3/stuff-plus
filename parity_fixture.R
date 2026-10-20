# Rscript parity_fixture.R <app_dir>
# 25 sampled full-season 2026 grades on the per-group 100 scale, for the app's
# tests/step18 parity check. Reads only scores already made.
suppressMessages(library(tidyverse))
app <- commandArgs(trailingOnly = TRUE)[1]
sc    <- readRDS("outputs/scored_2026.rds")
scale <- read_csv("models/stuff_v2_scale.csv", show_col_types = FALSE)
group <- function(pt) case_when(pt %in% c("FF", "SI", "FC") ~ "fastball", pt %in% c("CH", "FS") ~ "offspeed",
                                pt == "SL" ~ "hard breaker", pt %in% c("ST", "SV", "CU") ~ "soft breaker")
g <- sc |> summarise(n = n(), g = mean(pred), .by = c(pitcher, player_name, pitch_type)) |>
  filter(n >= 250) |> mutate(group = group(pitch_type)) |> inner_join(scale, by = "group") |>
  mutate(stuff_plus = round(100 + 10 * (g - mu) / sigma))
cat("2026 median grade by group (should sit near 100):\n")
print(as.data.frame(g |> summarise(median = median(stuff_plus), rows = n(), .by = group)))
set.seed(3)
write_csv(g |> slice_sample(n = 25) |> select(pitcher, player_name, pitch_type, stuff_plus, n),
          file.path(app, "tests", "fixtures", "stuff_v2_parity.csv"))
