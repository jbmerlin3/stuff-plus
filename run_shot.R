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
  cat("missing per input:\n"); print(colSums(is.na(oof[, INPUTS])))
  cat("input ranges:\n"); print(round(sapply(oof[, setdiff(INPUTS, "same_side")], range, na.rm = TRUE), 1))
  cat("share of pitches where the two sides differ:", round(mean(oof$pred_same != oof$pred_opp), 3), "\n")
  cat("pitches per fold:\n"); print(table(oof$fold))
  # Run every later step, report only that it ran
  steps <- list(gates = \() run_gates(oof), linear = \() run_cv(p, fit_linear, score_linear),
                stab = \() split_half(oof), location = \() location_check(oof), by_type = \() by_type(oof),
                final = \() { f <- final_fit(p); explain_pitch(f$model, p, "Strider, Spencer", "FF", 2023) })
  for (s in names(steps)) cat(s, ":", tryCatch({ steps[[s]](); "ran" }, error = \(e) conditionMessage(e)), "\n")
  quit(save = "no")
}

# ---- The shot ---------------------------------------------------------------
oof <- run_cv(p);                                  saveRDS(oof, file.path(out, "oof.rds"))
g   <- run_gates(oof);                             saveRDS(g,   file.path(out, "gates.rds"))
cat("\n=== GATES ===\n"); print(g$pass)
cat("gate 1 (edge over this season's RV):\n"); print(round(g$gate1, 4))
cat("gate 2 (edge by family):\n");              print(g$gate2)
cat("gate 3 (within-type r):\n"); print(round(g$gate3, 4)); print(g$gate3_types)
cat("gate 4 (known answers):\n"); print(g$gate4 |> select(player_name, pitch_type, game_year, list, pct, hit))

# Reported, after the verdict is printed and saved
# 8 GB machine: free each stage before the next
gc()
g6  <- run_gates(run_cv(p, fit = \(d) fit_model(d, depth = 6)));  gc()
cat("\ndepth 6 verdicts (UNRESOLVED if any differ):\n"); print(g6$pass)
lin <- run_gates(run_cv(p, fit_linear, score_linear));             gc()
cat("linear baseline, gate 1 and gate 3:\n"); print(round(rbind(gate1 = lin$gate1, gate3 = lin$gate3), 4))
rep <- list(depth6 = g6, linear = lin, stab = split_half(oof),
            location = location_check(oof), by_type = by_type(oof), final = final_fit(p))
saveRDS(rep, file.path(out, "reported.rds"))
print(rep$stab); print(rep$location); print(rep$by_type); print(rep$final$importance)
