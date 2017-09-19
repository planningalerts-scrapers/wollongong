require "mechanize"
require 'scraperwiki'

# This is using the ePathway system.

class WollongongScraper
  attr_reader :agent

  def initialize
    @agent = Mechanize.new
  end

  def extract_urls_from_page(page)
    content = page.at('table.ContentPanel')
    if content
      content.search('tr')[1..-1].map do |app|
        (page.uri + app.search('td')[0].at('a')["href"]).to_s
      end
    else
      []
    end
  end

  # The main url for the planning system which can be reached directly without getting a stupid session timed out error
  def enquiry_url
    "http://epathway.wollongong.nsw.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx"
  end

  # Returns a list of URLs for all the applications on exhibition
  def urls
    # Get the main page and ask for the list of DAs on exhibition
    page = agent.get(enquiry_url)
    form = page.forms.first
    form.radiobuttons[0].click
    page = form.submit(form.button_with(:value => /Save and Continue/))

    page_label = page.at('#ctl00_MainBodyContent_mPagingControl_pageNumberLabel')
    if page_label.nil?
      # If we can't find the label assume there is only one page of results
      number_of_pages = 1
    elsif page_label.inner_text =~ /Page \d+ of (\d+)/
      number_of_pages = $~[1].to_i
    else
      raise "Unexpected form for number of pages"
    end
    urls = []
    (1..number_of_pages).each do |page_no|
      # Don't refetch the first page
      if page_no > 1
        page = agent.get("http://epathway.wollongong.nsw.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquirySummaryView.aspx?PageNumber=#{page_no}")
      end
      # Get a list of urls on this page
      urls += extract_urls_from_page(page)
    end
    urls
  end

  def applications
    urls.map do |url|
      # Get application page with a referrer or we get an error page
      page = agent.get(url, [], URI.parse(enquiry_url))

      results = page.search('#ctl00_MainBodyContent_group_122').search('div.field')

      council_reference = results.search('span[contains("Application Number")] ~ td').text
      date_received     = Date.strptime(results.search('span[contains("Lodgement Date")] ~ td').text, '%d/%m/%Y').to_s
      description       = results.search('span[contains("Proposal")] ~ td').text

      address = page.search('#ctl00_MainBodyContent_group_124').search('tr.ContentPanel').search('span.ContentText')[0].text.strip

      record = {
        "council_reference" => council_reference,
        "address" => address,
        "description" => description,
        "info_url" => enquiry_url,
        "comment_url" => 'mailto:council@wollongong.nsw.gov.au',
        "date_scraped" => Date.today.to_s,
        "date_received" => date_received
      }
      #p record
      if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
        puts "Saving record " + record['council_reference'] + " - " + record['address']
        ScraperWiki.save_sqlite(['council_reference'], record)
      else
        puts "Skipping already saved record " + record['council_reference']
      end
    end
  end
end

WollongongScraper.new.applications
