xml.instruct!
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  [ root_url, timeline_url, sakes_url, contact_url, privacy_url, terms_url ].each do |page_url|
    xml.url do
      xml.loc page_url
    end
  end

  @sakes.each do |sake|
    xml.url do
      xml.loc sake_url(sake)
      xml.lastmod sake.updated_at.iso8601
    end
  end

  @sake_logs.each do |sake_log|
    xml.url do
      xml.loc sake_log_url(sake_log)
      xml.lastmod sake_log.updated_at.iso8601
    end
  end
end
