testthat::test_that("MI extdata doc yields House and Senate matches", {
	path <- system.file("extdata", "MI2003.txt", package = "statelegislators")
	testthat::expect_true(nzchar(path))

	txt <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

	yr <- 2023L

	out_house  <- extractStLegName(txt, state_abbrev = "MI", year = yr, chamber = "House")
	out_senate <- extractStLegName(txt, state_abbrev = "MI", year = yr, chamber = "Senate")
	out_both   <- extractStLegName(txt, state_abbrev = "MI", year = yr)

	testthat::expect_gt(nrow(out_house),  0)
	testthat::expect_gt(nrow(out_senate), 0)
	testthat::expect_gt(nrow(out_both),   0)
})

testthat::test_that("MI extdata doc works with allow_last_name = TRUE", {
	path <- system.file("extdata", "MI2003.txt", package = "statelegislators")
	testthat::expect_true(nzchar(path))

	txt <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
	yr <- 2023L

	out_house_pat <- extractStLegName(txt, state_abbrev = "MI", year = yr, chamber = "House")
	out_house_ln  <- extractStLegName(txt, state_abbrev = "MI", year = yr, chamber = "House", allow_last_name = TRUE)

	testthat::expect_gt(nrow(out_house_ln), 0)
	testthat::expect_true(all(out_house_ln[match_type == "unique", leg_chamber] == "House"))
	testthat::expect_gte(nrow(out_house_ln), nrow(out_house_pat))

	# Optional sanity: only these sources should appear
	testthat::expect_true(all(out_house_ln$match_source %in% c("pattern", "last_name")))
})
