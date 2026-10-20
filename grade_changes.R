# Which 2026 grades move most when the app's Stuff+ column switches from the
# previous source (a FanGraphs full-season export) to v2, and why.
# Writes outputs/grade_changes_2026.md. Reads only 2026 scores already made.
suppressMessages({ library(tidyverse); source("R/validity.R") })
old_path <- "/Users/jonathanmerlin/statcast-arsenal-app-docs/fg_stuff/fg_stuff_2026-03-26_2026-09-27.csv"
sc    <- readRDS("outputs/scored_2026.rds")
scale <- read_csv("models/stuff_v2_scale.csv", show_col_types = FALSE)

new <- sc |>
  summarise(n = n(), g = mean(pred), whiff = 100 * sum(description %in% WHIFF) / sum(description %in% SWING),
            velo = mean(release_speed), ivb = mean(ivb), hb = mean(hb), rel_ht = mean(release_ht),
            gap = mean(velo_gap), axis = mean(axis_diff, na.rm = TRUE),
            .by = c(pitcher, player_name, pitch_type)) |>
  filter(n >= 250) |>
  mutate(v2 = round(100 + 10 * (g - scale$mu) / scale$sigma))

# Old column as the app built it: FA is FF; SL covered SL, ST and SV; CU and KC
# cross-filled (the app folds KC into CU); FO folded into FS
old <- read_csv(old_path, show_col_types = FALSE) |>
  select(pitcher = MLBAMID, starts_with("Stf+ ")) |>
  pivot_longer(-pitcher, names_to = "code", values_to = "old", names_prefix = "Stf\\+ ", values_drop_na = TRUE) |>
  mutate(code = recode(code, FA = "FF", KC = "CU", FO = "FS")) |>
  summarise(old = round(first(old)), .by = c(pitcher, code))
d <- new |> mutate(code = if_else(pitch_type %in% c("ST", "SV"), "SL", pitch_type)) |>
  inner_join(old, by = c("pitcher", "code")) |> mutate(change = v2 - old)

# Why: the two inputs furthest from this pitch type's 2026 median (in SDs),
# and the actual whiff rate against the type median
z <- d |> mutate(across(c(velo, ivb, hb, rel_ht, gap, axis), \(x) (x - median(x)) / sd(x), .names = "z_{.col}"),
                 whiff_med = median(whiff), .by = pitch_type)
label <- c(velo = "velo", ivb = "IVB", hb = "HB", rel_ht = "release height", gap = "velo gap", axis = "axis differential")
why <- function(r) {
  zs <- unlist(r[paste0("z_", names(label))]); top <- order(-abs(zs))[1:2]
  paste0(paste(sprintf("%s %s (%+.1f SD)", label[top], ifelse(zs[top] > 0, "high", "low"), zs[top]), collapse = ", "),
         sprintf("; actual whiff %.0f%% vs type median %.0f%%", r$whiff, r$whiff_med))
}
z$why <- vapply(seq_len(nrow(z)), \(i) why(z[i, ]), "")
# The scales differ (the old column centred each pitch type on 100; v2 is
# league-wide, so sinkers sit low), so the fair move is RANK within pitch type.
# Reality check: which rank is closer to the pitch's actual whiff rank?
z <- z |> mutate(pct_old = round(100 * percent_rank(old)), pct_v2 = round(100 * percent_rank(v2)),
                 pct_whiff = round(100 * percent_rank(whiff)), .by = pitch_type) |>
  mutate(rank_move = pct_v2 - pct_old,
         sides_with = if_else(abs(pct_v2 - pct_whiff) < abs(pct_old - pct_whiff), "v2", "previous"))
rk <- function(x) x |> transmute(Pitcher = player_name, Pitch = pitch_type, `Old pct` = pct_old, `v2 pct` = pct_v2,
                                 `Whiff pct` = pct_whiff, `Reality sides with` = sides_with, Why = why)
rup <- z |> filter(n() >= 20, .by = pitch_type) |> arrange(-rank_move) |> head(12)
rdn <- z |> filter(n() >= 20, .by = pitch_type) |> arrange(rank_move) |> head(12)
fmt <- function(x) x |> transmute(Pitcher = player_name, Pitch = pitch_type, Old = old, v2, Change = sprintf("%+d", change), n, Why = why)
up <- z |> arrange(-change) |> head(15); down <- z |> arrange(change) |> head(15)

md <- c("# 2026 Stuff+ grades: previous column vs v2", "",
        sprintf("%d pitcher-pitch types with 250+ pitches in both. Rank agreement (Spearman) %.2f; mean absolute change %.1f points.",
                nrow(z), cor(z$v2, z$old, method = "spearman"), mean(abs(z$change))), "",
        "Previous = the FanGraphs full-season export the app used (its SL covers ST). v2 = this model, full season, both sides 50/50.",
        "'Why' = the two inputs furthest from that pitch type's 2026 median, and the pitch's actual 2026 whiff per swing.", "",
        "## Biggest risers", "", knitr::kable(fmt(up)), "", "## Biggest fallers", "", knitr::kable(fmt(down)), "",
        "## Biggest moves within pitch type (percentile among the same pitch type)", "",
        "Raw changes above mix two things: the scale (the old column centred each pitch type on 100; v2 is league-wide, so sinkers sit low) and the judgment. These tables remove the scale.", "",
        "### Rose most", "", knitr::kable(rk(rup)), "", "### Fell most", "", knitr::kable(rk(rdn)), "",
        sprintf("Across all %d rows, where the two ranks differ by 20+ points, reality (actual whiff rank) sides with v2 in %d and the previous column in %d.",
                nrow(z), sum(abs(z$rank_move) >= 20 & z$sides_with == "v2", na.rm = TRUE), sum(abs(z$rank_move) >= 20 & z$sides_with == "previous", na.rm = TRUE)), "",
        "## Does reality side with v2 or the old column?", "",
        sprintf("Correlation with actual 2026 whiff per swing among these %d rows, within pitch type: v2 %.2f, previous %.2f.",
                nrow(z), within_r(mutate(z, game_year = 2026), v2, whiff), within_r(mutate(z, game_year = 2026), old, whiff)))
writeLines(md, "outputs/grade_changes_2026.md"); cat(md, sep = "\n")
