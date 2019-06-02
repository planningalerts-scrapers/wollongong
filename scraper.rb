require "epathway_scraper"

# This is using the ePathway system.

class WollongongScraper
  attr_reader :agent

  def initialize
    @agent = Mechanize.new
  end

  def applications(scraper)
    # Get the main page and ask for the list of DAs on exhibition
    page = agent.get(scraper.base_url)

    page = EpathwayScraper::Page::ListSelect.pick(page, :advertising)

    number_of_pages = EpathwayScraper::Page::Index.extract_total_number_of_pages(page)

    (1..number_of_pages).each do |page_no|
      # Don't refetch the first page
      if page_no > 1
        page = agent.get("http://epathway.wollongong.nsw.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquirySummaryView.aspx?PageNumber=#{page_no}")
      end
      content = page.at('table.ContentPanel')
      # Get a list of urls on this page
      EpathwayScraper::Table.extract_table_data_and_urls(content).map do |row|
        # Get application page with a referrer or we get an error page
        page = agent.get(row[:url], [], URI.parse(scraper.base_url))

        data = EpathwayScraper::Page::Detail.scrape(page)

        record = {
          "council_reference" => data[:council_reference],
          "address" => data[:address],
          "description" => data[:description],
          "info_url" => scraper.base_url,
          "date_scraped" => Date.today.to_s,
          "date_received" => data[:date_received],
          "on_notice_from" => data[:on_notice_from],
          "on_notice_to" => data[:on_notice_to]
        }

        EpathwayScraper.save(record)
      end
    end
  end
end

scraper = EpathwayScraper::Scraper.new(
  "http://epathway.wollongong.nsw.gov.au/ePathway/Production"
)

WollongongScraper.new.applications(scraper)
