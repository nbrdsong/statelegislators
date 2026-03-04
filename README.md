# statelegislators

**Extract State Legislator Names from Messy Text**

---

## Overview

`statelegislators` is an R package that identifies U.S. state legislators referenced in text documents. It matches names using regular expressions and curated lookup tables, restricted by state, year (1969-2024), and chamber. Ambiguous matches (where multiple legislators share similar names) are automatically flagged instead of guessed.

---

## Features

- **Identify legislators from text** using regular expressions matching name variants.
- **Constrain search by state, year, and chamber** for high-precision results.
- **Flag ambiguous matches**—never silently guesses when two legislators have the same name.
- **Support for both House and Senate** for all 50 states (1969–present). Note: some states in some years have incomplete data.
- **Customizable matching pipeline** (optional: last-name-only matching).
- **Exported datasets**: `legis_people`, `legis_terms` for reproducible matching.

---

## Data Sources

This package uses legislator metadata derived from:

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

- **Last-name-only matching**:  
  Set `allow_last_name = TRUE` to match last names even without first names present (may increase ambiguity).

```r
results <- extractStLegName(text, state_abbrev = "MI", year = 2023, allow_last_name = TRUE)
```

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

MIT License. See [LICENSE](LICENSE).

---

## Citation

If you use this package in published work, please cite:

> Nicholas Birdsong. statelegislators: Extract State Legislator Names from Messy Text. GitHub. 2024.

---

## Maintainer

Nicholas Birdsong (github@nicholasbirdsong.com)

