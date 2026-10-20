# Rscript run_shot.R dry    -> small slice, structure only, no grades printed
# Rscript run_shot.R shot   -> the one pre-registered run (PREREG.md)
suppressMessages({ source("R/cv.R"); source("R/gates.R"); source("R/known.R"); source("R/reported.R") })
mode <- commandArgs(trailingOnly = TRUE)[1]
stopifnot(mode %in% c("dry", "shot"))
out <- file.path("outputs", mode); dir.create(out, recursive = TRUE, showWarnings = FALSE)

p <- prep_pitches()

if (mode == "dry") {
  # Known-answer pitchers plus 400 random others, so every function has data
  set.seed(3)
  keep <- union(p$pitcher[p$player_name %in% KNOWN$player_name], sample(unique(p$pitcher), 400))
  p <- p |> filter(pitcher %in% keep)
  oof <- run_cv(p)
  cat("rows in:", nrow(p), " rows scored:", nrow(oof), "\n")
  cat("missing per input:\n"); print(colSums(is.na(oof[, INPUTS_CH])))
  cat("input ranges:\n"); print(round(sapply(oof[, setdiff(INPUTS_CH, "same_side")], range, na.rm = TRUE), 1))
  cat("share of pitches where the two sides differ:", round(mean(oof$pred_same != oof$pred_opp), 3), "\n")
  cat("pitches per fold:\n"); print(table(oof$fold))
  # Same data, same seed, fit twice: predictions must be identical
  tr <- p |> filter(fold != 1) |> left_join(rv_table(p |> filter(fold != 1)), by = c("outcome", "balls", "strikes"))
  ho <- p |> filter(fold == 1)
  cat("reproducible:", identical(predict(fit_model(tr), xgb.DMatrix(to_matrix(ho))),
                                 predict(fit_model(tr), xgb.DMatrix(to_matrix(ho)))), "\n")
  # Run every later step, report only that it ran
  steps <- list(gates = \() run_gates(oof), linear = \() run_cv(p, fit_linear, score_linear),
                ch_fallback = \() run_cv(p, \(d) fit_model(d, inputs = INPUTS_CH),
                                         \(m, d) score_both_sides(m, d, INPUTS_CH)),
                stab = \() split_half(oof), location = \() location_check(oof), by_type = \() by_type(oof),
                final = \() { f <- final_fit(p); explain_pitch(f$model, p, "Strider, Spencer", "FF", 2023) })
  for (s in names(steps)) cat(s, ":", tryCatch({ steps[[s]](); "ran" }, error = \(e) conditionMessage(e)), "\n")
  quit(save = "no")
}

# ---- The shot ---------------------------------------------------------------
oof <- run_cv(p);  g <- run_gates(oof);  inputs <- INPUTS
saveRDS(oof, file.path(out, "oof.rds")); saveRDS(g, file.path(out, "gates.rds"))
cat("\n=== GATES ===\n"); print(g$pass)
cat("gate 1:\n"); print(round(g$gate1, 4)); cat("gate 2:\n"); print(g$gate2)
cat("gate 3:\n"); print(round(g$gate3, 4)); print(g$gate3_types)
cat("gate 4:\n"); print(g$gate4 |> select(player_name, pitch_type, game_year, list, pct, hit))

# 7a, amendment 6: only if gate 3 fails with CH among the misses. One try
ch_miss <- any(g$gate3_types$pitch_type == "CH" & g$gate3_types$r <= 0)
if (!g$pass["gate3"] && ch_miss) {
  inputs <- INPUTS_CH
  oof <- run_cv(p, \(d) fit_model(d, inputs = inputs), \(m, d) score_both_sides(m, d, inputs))
  g <- run_gates(oof); saveRDS(g, file.path(out, "gates_ch_fallback.rds"))
  cat("\n=== CHANGEUP FALLBACK USED ===\n"); print(g$pass)
}
cat("\nVERDICT:", if (all(g$pass)) "PASS" else "FAIL", "\n"); gc()

# Reported, after the verdict. Depth 6 can only veto
g6 <- run_gates(run_cv(p, \(d) fit_model(d, depth = 6, inputs = inputs), \(m, d) score_both_sides(m, d, inputs))); gc()
cat("depth 6:", if (identical(g6$pass, g$pass)) "RESOLVED" else "UNRESOLVED", "\n"); print(g6$pass)
lin <- run_gates(run_cv(p, fit_linear, score_linear)); gc()
cat("linear baseline, gate 1 and gate 3:\n"); print(round(rbind(gate1 = lin$gate1, gate3 = lin$gate3), 4))
fin <- final_fit(p, inputs); gc()
bt  <- by_type(oof) |> mutate(stuff_plus = 100 + 10 * (mean_pred - fin$mu) / fin$sigma)
ex  <- map(list(c("Strider, Spencer", "FF", 2023), c("Ohtani, Shohei", "ST", 2023),
                c("Williams, Devin", "CH", 2023)),
           \(x) explain_pitch(fin$model, p, x[1], x[2], as.integer(x[3]), inputs))
rep <- list(depth6 = g6, linear = lin, stab = split_half(oof), location = location_check(oof),
            by_type = bt, final = fin, examples = ex, inputs = inputs)
saveRDS(rep, file.path(out, "reported.rds"))
print(rep$stab); print(rep$location); print(bt); print(fin$importance); print(ex)
