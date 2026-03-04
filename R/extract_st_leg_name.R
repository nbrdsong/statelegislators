#' Extract state legislator names from messy text
#'
#' Uses a regex lookup table to find state legislators referenced in text, after
#' restricting the search space by state (required) and optionally by year and chamber.
#'
#' @param data A data.frame/data.table or a character vector.
#' @param col_name If `data` is a data.frame/data.table, the column containing text to search.
#' @param state_abbrev Required. Either (a) a column name in `data`, (b) a length-1 value,
#'   or (c) a vector of length `nrow(data)`. Two-letter abbreviations recommended (e.g., `"MI"`).
#' @param year Optional. Either a column name in `data`, a length-1 value, or a vector length
#'   `nrow(data)`. If missing/NA, searches across all years in the state (slower; more ambiguity).
#' @param year_window Integer >= 0. If `year` is provided, includes eligible legislators in the
#'   inclusive range `year - year_window` to `year + year_window`. Default is 3.
#' @param chamber Optional. Either a column name in `data`, a length-1 value, or a vector length
#'   `nrow(data)`. Must match values in `legis_terms$chamber` (e.g., `"House"`, `"Senate"`).
#' @param allow_last_name Logical. If `TRUE`, also attempts matching by last name (in addition to
#'   the main `pattern` regex matching), still restricted by the same state/year/chamber rules.
#'   This can increase recall but will also increase false positives and ambiguous hits.
#' @param people Optional override for the people/pattern table. Defaults to package data `legis_people`.
#' @param terms Optional override for the terms (eligibility) table. Defaults to package data `legis_terms`.
#'
#' @return A data.table with one row per match, including all original columns from `data` plus:
#' \describe{
#'   \item{data_id}{Row number of `data` where the match occurred}
#'   \item{match_source}{`"pattern"` or `"last_name"`}
#'   \item{match_type}{`"unique"` or `"ambiguous"`}
#'   \item{uid}{Unique legislator id (only for unique matches)}
#'   \item{leg_chamber}{Legislator chamber (only for unique matches)}
#'   \item{matched_variant}{For ambiguous pattern matches, the variant regex that matched}
#'   \item{matched_last_name}{For last-name matches, the last name that matched}
#'   \item{candidate_uids}{List-column of candidate uids (length 1 for unique matches)}
#'   \item{state_abbrev_search, year_search, chamber_search}{The context used to restrict the search}
#'   \item{leg_name, leg_first_name, leg_last_name}{Legislator name fields (unique matches)}
#'   \item{leg_klarner_candid, leg_legiscan_people_id, leg_sles_id}{Crosswalk ids (unique matches)}
#' }
#'
#' @export
extractStLegName <- function(data,
														 col_name = NULL,
														 state_abbrev,
														 year = NULL,
														 year_window = 3L,
														 chamber = NULL,
														 allow_last_name = FALSE,
														 people = NULL,
														 terms = NULL) {

	# ---- load defaults (package datasets) if not supplied ----
	if (is.null(people)) {
		people <- tryCatch(get("legis_people", envir = environment(extractStLegName), inherits = TRUE),
											 error = function(e) NULL)
		if (is.null(people)) {
			utils::data("legis_people", package = "statelegislators", envir = environment())
			people <- get("legis_people", envir = environment())
		}
	}
	if (is.null(terms)) {
		terms <- tryCatch(get("legis_terms", envir = environment(extractStLegName), inherits = TRUE),
											error = function(e) NULL)
		if (is.null(terms)) {
			utils::data("legis_terms", package = "statelegislators", envir = environment())
			terms <- get("legis_terms", envir = environment())
		}
	}

	people_dt <- data.table::as.data.table(people)
	terms_dt  <- data.table::as.data.table(terms)

	# ---- helpers ----
	resolve_arg <- function(arg, dt, n, arg_name, required = FALSE) {
		if (missing(arg) || is.null(arg)) {
			if (required) stop(sprintf("`%s` must be specified.", arg_name), call. = FALSE)
			return(rep(NA, n))
		}
		if (length(arg) == 1L && is.character(arg) && arg %in% names(dt)) return(dt[[arg]])
		if (length(arg) == 1L) return(rep(arg, n))
		if (length(arg) == n) return(arg)
		stop(sprintf("`%s` must be a column name in `data`, length 1, or length nrow(data).", arg_name),
				 call. = FALSE)
	}

	split_top_level_alts <- function(pat) {
		if (is.na(pat) || !nzchar(pat)) return(character())
		chars <- strsplit(pat, "", fixed = TRUE)[[1]]

		out <- character()
		buf <- character()
		depth_paren <- 0L
		depth_brack <- 0L
		esc <- FALSE

		for (ch in chars) {
			if (esc) { buf <- c(buf, ch); esc <- FALSE; next }
			if (ch == "\\") { buf <- c(buf, ch); esc <- TRUE; next }

			if (depth_brack > 0L) {
				buf <- c(buf, ch)
				if (ch == "]") depth_brack <- depth_brack - 1L
				next
			}

			if (ch == "[") { depth_brack <- depth_brack + 1L; buf <- c(buf, ch); next }
			if (ch == "(") { depth_paren <- depth_paren + 1L; buf <- c(buf, ch); next }
			if (ch == ")") { depth_paren <- max(depth_paren - 1L, 0L); buf <- c(buf, ch); next }

			if (ch == "|" && depth_paren == 0L && depth_brack == 0L) {
				out <- c(out, paste0(buf, collapse = ""))
				buf <- character()
				next
			}

			buf <- c(buf, ch)
		}

		out <- c(out, paste0(buf, collapse = ""))
		out <- trimws(out)
		out[nzchar(out)]
	}

	collapse_or_na <- function(x) {
		x <- x[!is.na(x) & nzchar(x)]
		x <- unique(x)
		if (!length(x)) NA_character_ else paste(x, collapse = "|")
	}

	last_name_to_regex <- function(ln) {
		ln <- tolower(trimws(ln))
		if (is.na(ln) || !nzchar(ln)) return(NA_character_)

		ln <- gsub("[\u2019`]", "'", ln)
		escape_regex <- function(x) gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x, perl = TRUE)
		esc <- escape_regex(ln)

		# tolerate spacing/hyphens/apostrophes
		esc <- gsub("\\\\ ", "\\\\s+", esc)                         # spaces -> flexible whitespace
		esc <- gsub("-", "[-\\\\s]+", esc, fixed = TRUE)            # hyphen -> hyphen/space
		esc <- gsub("'", "['\u2019]", esc, fixed = TRUE)                 # allow or

		paste0("\\b", esc, "\\b")
	}

	# ---- input to data.table ----
	if (is.character(data) && is.null(dim(data))) {
		dt <- data.table::data.table(text = data)
		if (is.null(col_name)) col_name <- "text"
		data.table::setnames(dt, "text", col_name)
	} else if (is.data.frame(data)) {
		dt <- data.table::as.data.table(data)
		if (is.null(col_name)) stop("When `data` is a data.frame/data.table, `col_name` must be provided.", call. = FALSE)
	} else {
		stop("`data` must be a data.frame/data.table or a character vector.", call. = FALSE)
	}

	if (!col_name %in% names(dt)) stop("`col_name` must name a column in `data`.", call. = FALSE)
	if (!is.character(dt[[col_name]])) stop("`col_name` must refer to a character column.", call. = FALSE)

	n <- nrow(dt)
	dt[, data_id := .I]
	dt[, text_clean := tolower(get(col_name))]

	# required state
	dt[, state__ := toupper(as.character(resolve_arg(state_abbrev, dt, n, "state_abbrev", required = TRUE)))]
	if (anyNA(dt$state__) || any(!nzchar(dt$state__))) {
		stop("`state_abbrev` is required and cannot contain NA/empty values.", call. = FALSE)
	}

	# optional year
	dt[, year__ := suppressWarnings(as.integer(resolve_arg(year, dt, n, "year", required = FALSE)))]

	# optional chamber
	if (is.null(chamber)) {
		dt[, chamber__ := NA_character_]
	} else {
		dt[, chamber__ := as.character(resolve_arg(chamber, dt, n, "chamber", required = FALSE))]
	}

	year_window <- as.integer(year_window)
	if (is.na(year_window) || year_window < 0L) stop("`year_window` must be an integer >= 0.", call. = FALSE)

	allow_last_name <- isTRUE(allow_last_name)

	# ---- split work by context ----
	ctx <- unique(dt[, list(state__, year__, chamber__)])
	res <- vector("list", nrow(ctx))

	for (k in seq_len(nrow(ctx))) {
		s  <- ctx$state__[k]
		y  <- ctx$year__[k]      # may be NA
		ch <- ctx$chamber__[k]   # may be NA

		# rows of text for this context
		sub <- dt[state__ == s]
		if (!is.na(y)) sub <- sub[year__ == y]
		if (!is.na(ch) && nzchar(ch)) sub <- sub[chamber__ == ch]
		if (nrow(sub) == 0L) next

		# eligible roster
		roster_terms <- terms_dt[state_abbrev == s]
		if (!is.na(ch) && nzchar(ch)) roster_terms <- roster_terms[chamber == ch]

		if (!is.na(y)) {
			ymin <- y - year_window
			ymax <- y + year_window
			roster_terms <- roster_terms[year >= ymin & year <= ymax]
		}

		if (nrow(roster_terms) == 0L) next

		# dedupe to uidxchamber (important if year is missing or year_window > 0)
		roster_u <- unique(roster_terms[, list(uid, chamber)])

		roster <- people_dt[roster_u, on = list(uid, chamber), nomatch = 0L]
		roster <- roster[!is.na(pattern) & nzchar(pattern)]
		if (nrow(roster) == 0L) next

		# ---- pattern-based: compute ambiguous variants within THIS roster ----
		pat <- unique(roster[, list(uid, chamber, pattern)])
		pat[, variants := lapply(pattern, split_top_level_alts)]
		long <- pat[, list(variant = unlist(variants, use.names = FALSE)), by = list(uid, chamber)]
		long[, variant := trimws(variant)]
		long <- long[!is.na(variant) & nzchar(variant)]
		long[, variant_key := tolower(variant)]
		long <- unique(long, by = c("uid","chamber","variant_key"))

		ambig_keys <- long[, list(n_uids = data.table::uniqueN(uid)), by = variant_key][n_uids > 1L, variant_key]

		safe_pat <- long[!variant_key %in% ambig_keys,
										 list(pattern_safe = collapse_or_na(variant)),
										 by = list(uid, chamber)][!is.na(pattern_safe)]

		ambig_map <- long[variant_key %in% ambig_keys,
											list(matched_variant = variant[1L],
												candidate_uids = list(sort(unique(uid)))),
											by = variant_key]

		out_unique_pat <- data.table::rbindlist(lapply(seq_len(nrow(safe_pat)), function(i) {
			uid_i <- safe_pat$uid[i]
			ch_i  <- safe_pat$chamber[i]
			pat_i <- safe_pat$pattern_safe[i]

			hit <- stringi::stri_detect_regex(sub$text_clean, pat_i)
			if (!any(hit, na.rm = TRUE)) return(NULL)

			data.table::data.table(
				data_id = sub$data_id[hit],
				match_source = "pattern",
				match_type = "unique",
				uid = uid_i,
				chamber = ch_i,
				matched_variant = NA_character_,
				matched_last_name = NA_character_,
				candidate_uids = rep(list(uid_i), sum(hit, na.rm = TRUE)),
				state_abbrev_search = s,
				year_search = y,
				chamber_search = ch
			)
		}), fill = TRUE)

		out_ambig_pat <- data.table::rbindlist(lapply(seq_len(nrow(ambig_map)), function(i) {
			v_i <- ambig_map$matched_variant[i]
			c_i <- ambig_map$candidate_uids[[i]]

			hit <- stringi::stri_detect_regex(sub$text_clean, v_i)
			if (!any(hit, na.rm = TRUE)) return(NULL)

			data.table::data.table(
				data_id = sub$data_id[hit],
				match_source = "pattern",
				match_type = "ambiguous",
				uid = NA_character_,
				chamber = NA_character_,
				matched_variant = v_i,
				matched_last_name = NA_character_,
				candidate_uids = rep(list(c_i), sum(hit, na.rm = TRUE)),
				state_abbrev_search = s,
				year_search = y,
				chamber_search = ch
			)
		}), fill = TRUE)

		# ---- optional last-name matches (still roster-restricted) ----
		out_last <- NULL
		if (allow_last_name) {
			roster_ln <- unique(roster[!is.na(last_name) & nzchar(last_name),
																 list(uid, chamber,
																 	last_name_key = tolower(trimws(last_name)),
																 	last_name_raw = tolower(trimws(last_name)))])

			if (nrow(roster_ln)) {
				ln_map <- roster_ln[, list(
					n_candidates = data.table::uniqueN(uid),
					candidate_uids = list(sort(unique(uid))),
					candidate_pairs = list(unique(.SD[, list(uid, chamber)])),
					last_name_raw = last_name_raw[1L]
				), by = last_name_key]

				out_last <- data.table::rbindlist(lapply(seq_len(nrow(ln_map)), function(i) {
					rx <- last_name_to_regex(ln_map$last_name_raw[i])
					if (is.na(rx)) return(NULL)

					hit <- stringi::stri_detect_regex(sub$text_clean, rx)
					if (!any(hit, na.rm = TRUE)) return(NULL)

					cand_uids  <- ln_map$candidate_uids[[i]]
					cand_pairs <- ln_map$candidate_pairs[[i]]

					if (ln_map$n_candidates[i] == 1L) {
						uid_i <- cand_pairs$uid[1L]
						ch_i  <- cand_pairs$chamber[1L]
						data.table::data.table(
							data_id = sub$data_id[hit],
							match_source = "last_name",
							match_type = "unique",
							uid = uid_i,
							chamber = ch_i,
							matched_variant = NA_character_,
							matched_last_name = ln_map$last_name_raw[i],
							candidate_uids = rep(list(uid_i), sum(hit, na.rm = TRUE)),
							state_abbrev_search = s,
							year_search = y,
							chamber_search = ch
						)
					} else {
						data.table::data.table(
							data_id = sub$data_id[hit],
							match_source = "last_name",
							match_type = "ambiguous",
							uid = NA_character_,
							chamber = NA_character_,
							matched_variant = NA_character_,
							matched_last_name = ln_map$last_name_raw[i],
							candidate_uids = rep(list(cand_uids), sum(hit, na.rm = TRUE)),
							state_abbrev_search = s,
							year_search = y,
							chamber_search = ch
						)
					}
				}), fill = TRUE)
			}
		}

		combined <- data.table::rbindlist(list(out_unique_pat, out_ambig_pat, out_last), fill = TRUE)
		if (nrow(combined) == 0L) next

		# Prefer pattern over last_name when both produce the same unique (data_id, uid)
		uniq <- combined[match_type == "unique"]
		if (nrow(uniq)) {
			uniq[, source_rank := data.table::fifelse(match_source == "pattern", 1L, 2L)]
			data.table::setorder(uniq, data_id, uid, source_rank)
			uniq <- uniq[, .SD[1L], by = list(data_id, uid)]
			uniq[, source_rank := NULL]
		}

		amb <- combined[match_type == "ambiguous"]
		if (nrow(amb)) {
			amb <- unique(amb, by = c("data_id","match_source","matched_variant","matched_last_name"))
		}

		res[[k]] <- data.table::rbindlist(list(uniq, amb), fill = TRUE)
	}

	hits <- data.table::rbindlist(res, fill = TRUE)
	if (nrow(hits) == 0L) return(hits)

	# ---- attach legislator metadata for unique hits ----
	meta <- people_dt[, list(uid, chamber,
												name, first_name, last_name,
												klarner_candid, legiscan_people_id, sles_id)]
	hits <- merge(hits, meta, by = c("uid","chamber"), all.x = TRUE)

	# rename legislator fields to avoid colliding with user data columns
	data.table::setnames(
		hits,
		old = c("chamber","name","first_name","last_name","klarner_candid","legiscan_people_id","sles_id"),
		new = c("leg_chamber","leg_name","leg_first_name","leg_last_name",
						"leg_klarner_candid","leg_legiscan_people_id","leg_sles_id")
	)

	# ---- add original columns back (drop internals and avoid name collisions) ----
	orig <- dt[, setdiff(names(dt), c("text_clean","state__","year__","chamber__")), with = FALSE]

	overlap <- intersect(setdiff(names(orig), "data_id"), names(hits))
	if (length(overlap)) {
		warning(sprintf(
			"Dropping %d column(s) from input `data` that would collide with output: %s",
			length(overlap), paste(overlap, collapse = ", ")
		), call. = FALSE)
		orig[, (overlap) := NULL]
	}

	out <- merge(hits, orig, by = "data_id", all.x = TRUE)
	data.table::setorder(out, data_id, match_type, match_source, uid)

	out
}
