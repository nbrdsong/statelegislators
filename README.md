# statelegislators

**Extract State Legislator Names from Text**

---

## Overview

`statelegislators` is an R package that identifies U.S. state legislators referenced in text documents. It matches names using regular expressions and lookup tables, restricted by state, year (or year window), and chamber.

---

## Features

- **Identify legislators from text** using regular expressions matching name variants.
- **Connects identifiers from several datasets** which facilitates analysis of state legislator-level data.
- **Constrain search by state, year, and chamber** for high-precision results.
- **Flag ambiguous matches**—never silently guesses when two legislators have the same name.
- **Support for both House and Senate** for all 50 states (1969–2024). Note: some states in some years have incomplete data.
- **Customizable matching pipeline** (optional: last-name-only matching which may be appropriate for some data sources).
- **Exported datasets**: `legis_people`, `legis_terms` for reproducible matching.

---

## Data Sources

This package uses data from:

- Klarner, Carl. 2018. *State Legislative Election Returns, 1967-2016*.
- LegiScan
- Bucchianeri, Peter; Volden, Craig; Wiseman, Alan E. 2024. "Replication Data for: Legislative Effectiveness in the American States". [Harvard Dataverse](https://doi.org/10.7910/DVN/NT7H5O)
- Manual cleaning and additions where missing data or errors were detected.

See the package documentation and data preparation scripts in `data-raw/` for further details.

---

## Installation

```r
# Install from GitHub
remotes::install_github("nbrdsong/statelegislators")
# Or, if using devtools:
devtools::install_github("nbrdsong/statelegislators")
```
---

## Basic Usage

```r
library(statelegislators)

# Load example text document (included with package)
path <- system.file("extdata", "MI2003.txt", package = "statelegislators")
text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Extract Michigan House matches for 2023
results_house <- extractStLegName(text, state_abbrev = "MI", year = 2023, chamber = "House")

# Extract Senate matches
results_senate <- extractStLegName(text, state_abbrev = "MI", year = 2023, chamber = "Senate")

# See ambiguous matches explicitly flagged
results <- extractStLegName(text, state_abbrev = "MI", year = 2023)
subset(results, match_type == "ambiguous")
```

---

## Example Output

Each row includes:
- `data_id` (input text row)
- `uid` (unique legislator ID)
- `leg_name`, `leg_first_name`, `leg_last_name`
- `state_abbrev`, `year`, `leg_chamber`
- `match_type` ("unique" / "ambiguous")
- `candidate_uids` (possible matches for ambiguous names)
- All original columns from your input

---

## Custom Options

- **`state_abbrev`**: Two-letter state abbreviation (e.g., `"MI"`). *Required*. Limits the search to legislators from a specific state.

- **`year`**: Year of legislative session. *Optional*. Restricts matching to legislators active in a particular year.

- **`year_window`**: Integer. Includes legislators active from `year - year_window` to `year + year_window`. Default is 3. Useful if the exact document year is uncertain or for capturing legislators who served around the target date.

- **`chamber`**: `"House"`, `"Senate"`, or `"Both"`. *Optional*. Limits matches to the chosen chamber (helps avoid false positives when a name appears in both chambers).

- **`allow_last_name`**: Logical. If `TRUE`, allows matching based on last name only (may increase recall but can lead to false positives and more ambiguous matches). Default is `FALSE`.

- **`people`**, **`terms`**: Custom lookup tables for users who want to supply alternative legislator datasets (default: package-shipped lookup tables).

---

## Data

- `legis_people`: Contains regex patterns and metadata for all legislators.
- `legis_terms`: Defines eligibility (by state/year/chamber).

---

## Contributing / Issues

Found a bug? Want to contribute a new feature or typo correction table?  
[Open an issue](https://github.com/nbrdsong/statelegislators/issues) or submit a pull request!

---

## License

MIT License.

---

## Citation

If you use this package in published work, please cite:

> Nicholas Birdsong. statelegislators: Extract State Legislator Names from Text. GitHub. 2026.

---

## Maintainer

Nicholas Birdsong (github@nicholasbirdsong.com)

