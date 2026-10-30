# parity_fixture.R
# 25 sampled full-season 2026 grades for the app's test_stuff_plus.R. Run after export_v2.R.
#   Rscript scripts/parity_fixture.R <app_dir>

suppressMessages({ library(tidyverse); source("R/scale.R") })
app <- commandArgs(trailingOnly = TRUE)[1]
sc    <- readRDS("outputs/scored_2026.rds")
scale <- read_csv("models/stuff_v2_scale.csv", show_col_types = FALSE)
g <- sc |> summarise(n = n(), g = mean(pred), .by = c(pitcher, player_name, pitch_type)) |>
  filter(n >= 250) |> mutate(group = stuff_group(pitch_type)) |> inner_join(scale, by = "group") |>
  mutate(stuff_plus = to_stuff_plus(g, mu, sigma))
cat("2026 median grade by group (should sit near 100):\n")
print(as.data.frame(g |> summarise(median = median(stuff_plus), rows = n(), .by = group)))
set.seed(3)
write_csv(g |> slice_sample(n = 25) |> select(pitcher, player_name, pitch_type, stuff_plus, n),
          file.path(app, "tests", "fixtures", "stuff_v2_parity.csv"))
