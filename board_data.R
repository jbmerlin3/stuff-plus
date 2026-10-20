# 2026 leaderboard data for the review page: v2 grades, splits, the previous
# app column for the delta, and the inputs. Reads only scores already made.
suppressMessages({ library(tidyverse); source("R/validity.R") })
out <- commandArgs(trailingOnly = TRUE)[1]
sc <- readRDS("outputs/scored_2026.rds")
scale <- read_csv("models/stuff_v2_scale.csv", show_col_types = FALSE)
group <- function(pt) case_when(pt %in% c("FF", "SI", "FC") ~ "fastball", pt %in% c("CH", "FS") ~ "offspeed",
                                pt == "SL" ~ "hard breaker", pt %in% c("ST", "SV", "CU") ~ "soft breaker")

new <- sc |>
  summarise(n = n(), g = mean(pred),
            gR = mean(if (first(p_throws) == "R") pred_same else pred_opp),
            gL = mean(if (first(p_throws) == "L") pred_same else pred_opp),
            whiff = 100 * sum(description %in% WHIFF) / sum(description %in% SWING),
            velo = mean(release_speed), ivb = mean(ivb), hb = mean(hb),
            gap = mean(velo_gap), axis = mean(axis_diff, na.rm = TRUE),
            .by = c(pitcher, player_name, p_throws, pitch_type)) |>
  filter(n >= 50) |>
  mutate(group = group(pitch_type)) |> inner_join(scale, by = "group") |>
  mutate(across(c(g, gR, gL), \(x) round(100 + 10 * (x - mu) / sigma)), v2 = g, vsR = gR, vsL = gL)

old <- read_csv("/Users/jonathanmerlin/statcast-arsenal-app-docs/fg_stuff/fg_stuff_2026-03-26_2026-09-27.csv",
                show_col_types = FALSE) |>
  select(pitcher = MLBAMID, starts_with("Stf+ ")) |>
  pivot_longer(-pitcher, names_to = "code", values_to = "prev", values_drop_na = TRUE) |>
  mutate(code = sub("Stf+ ", "", code, fixed = TRUE),
         code = recode(code, FA = "FF", KC = "CU", FO = "FS")) |>
  summarise(prev = round(first(prev)), .by = c(pitcher, code))

d <- new |>
  mutate(code = if_else(pitch_type %in% c("ST", "SV"), "SL", pitch_type)) |>
  left_join(old, by = c("pitcher", "code")) |>
  mutate(delta = v2 - prev,
         pct_v2 = round(100 * percent_rank(v2)),
         pct_prev = ifelse(is.na(prev), NA, round(100 * percent_rank(prev))),
         whiff_pct = round(100 * percent_rank(whiff)), .by = pitch_type) |>
  mutate(rank_delta = pct_v2 - pct_prev,
         name = sub("^(.*), (.*)$", "\\2 \\1", player_name)) |>
  transmute(name, hand = p_throws, type = pitch_type, v2, pct = pct_v2, vsR, vsL, prev, delta, rank_delta, n,
            whiff = round(whiff, 1), whiff_pct, velo = round(velo, 1), ivb = round(ivb, 1),
            hb = round(hb, 1), gap = round(gap, 1), axis = round(axis))
cat(nrow(d), "rows;", sum(!is.na(d$prev)), "with a previous grade\n"); print(table(d$type))
jsonlite::write_json(d, out, na = "null", digits = NA)
