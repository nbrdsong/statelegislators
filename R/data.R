#' State legislator people table
#'
#' One row per `uid` × `chamber`, containing the regex `pattern` and stable identifiers.
#'
#' @format A data.frame/data.table with columns:
#' \describe{
#'   \item{uid}{Unique legislator identifier}
#'   \item{chamber}{Legislative chamber}
#'   \item{pattern}{Regex alternation of name variants}
#'   \item{name, first_name, last_name}{Name fields}
#'   \item{klarner_candid, legiscan_people_id, sles_id}{Crosswalk identifiers}
#' }
"legis_people"

#' State legislator terms table
#'
#' One row per legislator-year of service used to restrict matching by context.
#'
#' @format A data.frame/data.table with columns:
#' \describe{
#'   \item{uid}{Unique legislator identifier}
#'   \item{state_abbrev}{Two-letter state abbreviation}
#'   \item{chamber}{Legislative chamber}
#'   \item{year}{Service year}
#' }
"legis_terms"
