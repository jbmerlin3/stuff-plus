# scale.R
# Display scale: 100 is the average pitch within its group, 10 points one SD within the group.
# The model and every validation number use raw predictions.

library(tidyverse)

stuff_group <- function(pitch_type) case_when(
  pitch_type %in% c("FF", "SI", "FC")              ~ "fastball",
  pitch_type %in% c("CH", "FS", "FO")              ~ "offspeed",
  pitch_type == "SL"                               ~ "hard breaker",
  pitch_type %in% c("ST", "SV", "CU", "KC")        ~ "soft breaker")

# mu over all pitches; sigma across pitcher, season and pitch type rows with 100+ pitches
scale_constants <- function(scored) {
  dsc <- scored |> mutate(group = stuff_group(pitch_type))
  dsg <- dsc |> summarise(n = n(), g = mean(pred), .by = c(pitcher, game_year, pitch_type, group))
  dsc |> summarise(mu = mean(pred), pitches = n(), .by = group) |>
    left_join(dsg |> filter(n >= 100) |> summarise(sigma = sd(g), pitch_types = n(), .by = group), by = "group") |>
    arrange(group)
}

# The app folds these labels, so the grades it reads must use the same ones
app_label <- function(pitch_type) case_when(
  pitch_type == "KC" ~ "CU",
  pitch_type == "FO" ~ "FS",
  TRUE               ~ pitch_type)

to_stuff_plus <- function(g, mu, sigma) round(100 + 10 * (g - mu) / sigma)
