ActionView::Base.field_error_proc = Proc.new do |html_tag, _instance|
  doc = Nokogiri::HTML::DocumentFragment.parse(html_tag)
  doc.children.each do |node|
    if node.element?
      existing = node['class'].to_s
      node['class'] = "#{existing} field_with_errors".strip
    end
  end
  doc.to_html.html_safe
end