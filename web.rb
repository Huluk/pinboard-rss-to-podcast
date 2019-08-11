require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'net/http'

Pinboard = "https://feeds.pinboard.in/rss/"

Header = <<END
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>%{title}</title>
    <description>%{description}</description>
    <link>%{link}</link>
    <language>en-us</language>

END

Item = <<END
    <item>
      <title>%{title}</title>
      <enclosure url="%{link}" length="%{length}" type="audio/mpeg"/>
      <description>%{description}</description>
      <pubDate>%{date}</pubDate>
    </item>

END

Footer = <<END
  </channel>
</rss>
END

def parse_children(node)
  node
    .children
    .to_a
    .find_all { |it| it.kind_of? Nokogiri::XML::Node }
    .map { |elem| [elem.name.to_sym, elem.content] }
    .to_h
end

def item_data(item)
	attributes = {description: ''}.merge parse_children(item)
  attributes[:title].sub!(/^\[priv\] /, '') # remove private marker
  uri = URI(attributes[:link])
  attributes[:length] =
    Net::HTTP.new(uri.host).request_head(uri.path)['Content-Length']
  return attributes
end

get '/*' do
  details = params['splat'].join('/')
  pinboard_response = open(Pinboard + details).read
  rss = Nokogiri::XML(pinboard_response)
  header = Header % parse_children(rss.at_xpath('//xmlns:channel'))
  elements = rss.xpath('//xmlns:items/rdf:Seq/rdf:li').map { |elem|
    audio_path = elem.attributes.values.first
    item = rss.at_xpath(%Q|//xmlns:item[@rdf:about="#{audio_path}"]|)
    Item % item_data(item)
  }
  header + elements.join("\n") + Footer
end
