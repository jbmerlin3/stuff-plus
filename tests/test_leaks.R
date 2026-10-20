library(tidyverse)
source("R/target.R")

# Each check stops the script if the leak it targets is present
p <- readRDS("data/pitches_clean.rds") |>
  mutate(outcome = outcome(events, description))
message("Outcome mapped for ", round(100 * mean(!is.na(p$outcome)), 2), "% of pitches")
p <- p |> filter(!is.na(outcome))

folds <- assign_folds(p)
p <- p |> left_join(folds, by = "pitcher")

# 1. No pitcher in two folds, and nobody left without one
stopifnot(!anyNA(p$fold),
          p |> distinct(pitcher, fold) |> count(pitcher) |> pull(n) |> max() == 1)
message("1. every pitcher in exactly one fold")

for (k in 1:5) {
  train <- p |> filter(fold != k)
  held  <- p |> filter(fold == k)
  tab   <- rv_table(train)

  # 2. The training rows share no pitcher with the held-out fold
  stopifnot(length(intersect(train$pitcher, held$pitcher)) == 0)

  # 3. The held-out pitchers would have moved the table. If they would not,
  #    check 2 proves nothing about this table
  leaky <- rv_table(p)
  moved <- tab |> inner_join(leaky, by = c("outcome", "balls", "strikes")) |>
    summarise(max_move = max(abs(rv.x - rv.y))) |> pull(max_move)
  stopifnot(moved > 0)

  # 4. Every held-out pitch finds a value, so none is silently dropped
  stopifnot(!anyNA(left_join(held, tab, by = c("outcome", "balls", "strikes"))$rv))
  message("fold ", k, ": no shared pitchers, table moves up to ",
          signif(moved, 2), " runs without them, every pitch valued")
}
message("ALL LEAK TESTS PASS")
