library(tidyverse)
library(xgboost)

# The seven inputs (PREREG.md section 3). No pitch type, count or location
INPUTS <- c("release_speed", "ivb", "hb", "release_ht", "release_side",
            "velo_gap", "same_side")

# Fixed before fitting (section 4). Nothing here is tuned
PARAMS <- list(objective = "reg:squarederror", max_depth = 4, learning_rate = 0.05,
               min_child_weight = 100, subsample = 0.8, colsample_bytree = 1.0)
N_ROUNDS <- 400

# A dense matrix keeps memory flat on 2M+ rows. NA in velo_gap stays NA,
# which XGBoost sends down a learned default branch
to_matrix <- function(df) as.matrix(df[, INPUTS])

fit_model <- function(train, depth = PARAMS$max_depth) {
  set.seed(3)
  dtrain <- xgb.DMatrix(to_matrix(train), label = train$rv)
  xgb.train(params = modifyList(PARAMS, list(max_depth = depth)),
            data = dtrain, nrounds = N_ROUNDS, verbose = 0)
}

# Every pitch scored as if thrown to a same-side and an opposite-side hitter.
# The overall grade is the 50/50 average, so it does not reward the hitters a
# pitcher happened to face (section 5)
score_both_sides <- function(model, df) {
  same <- df |> mutate(same_side = 1L)
  opp  <- df |> mutate(same_side = 0L)
  df |>
    mutate(pred_same = predict(model, xgb.DMatrix(to_matrix(same))),
           pred_opp  = predict(model, xgb.DMatrix(to_matrix(opp))),
           pred      = (pred_same + pred_opp) / 2)
}
