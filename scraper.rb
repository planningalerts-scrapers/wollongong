require "epathway_scraper"

EpathwayScraper.scrape_and_save(
  "http://epathway.wollongong.nsw.gov.au/ePathway/Production",
  list_type: :advertising, state: "NSW"
)
