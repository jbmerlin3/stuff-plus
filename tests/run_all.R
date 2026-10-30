# run_all.R
# Run every test file in its own R process from the repo root and report PASS, FAIL or SKIP.
#   Rscript tests/run_all.R
# Tests that read data/ are skipped when it isn't there.

if (!dir.exists("R") || !dir.exists("tests")) stop("run this from the repo root", call. = FALSE)

files <- sort(list.files("tests", pattern = "^test_.*\\.R$", full.names = TRUE))
has_data <- file.exists("data/pitches_clean.rds")
rscript <- file.path(R.home("bin"), "Rscript")
needs_data <- function(f) any(grepl("data/", readLines(f, warn = FALSE), fixed = TRUE))

status <- vapply(files, function(f) {
  name <- sub("\\.R$", "", basename(f))
  if (!has_data && needs_data(f)) {
    cat(sprintf("  SKIP  %-20s (no data/)\n", name))
    return("skip")
  }
  t0  <- Sys.time()
  out <- suppressWarnings(system2(rscript, f, stdout = TRUE, stderr = TRUE))
  rc  <- attr(out, "status"); if (is.null(rc)) rc <- 0L
  cat(sprintf("  %s  %-20s %5.1fs\n", if (rc == 0L) "PASS" else "FAIL", name,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (rc != 0L) cat(paste0("        ", tail(out, 15)), sep = "\n")
  if (rc == 0L) "pass" else "fail"
}, character(1))

cat(sprintf("\n%d passed, %d failed, %d skipped\n",
            sum(status == "pass"), sum(status == "fail"), sum(status == "skip")))
quit(status = if (any(status == "fail")) 1 else 0)
