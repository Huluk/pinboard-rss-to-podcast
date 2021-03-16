require 'async'
require 'cgi'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'sinatra'
require 'time'

Pinboard = "https://feeds.pinboard.in/rss/"

LENGTH_REQUEST_TIMEOUT = 1

Header = <<-END
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">
  <channel>
    <title>%{title}</title>
    <description>%{description}</description>
    <link>%{link}</link>
    <language>en-us</language>

END

Item = <<-END.freeze
    <item>
      <title>%{title}</title>
      %{optional_author}
      <enclosure url="%{link}" length="%{length}" type="audio/mpeg"/>
      <description>%{description}</description>
      <pubDate>%{date}</pubDate>
    </item>

END

Footer = <<-END
  </channel>
</rss>
END

def esc(str)
  CGI.escapeHTML str
end

def url_esc(str)
  str.to_s.gsub(/&/, "&amp;")
end

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
  if attributes[:title] =~ /\|/
    attributes[:title], *author = attributes[:title].split(/\s*\|\s*/)
    author = esc author.join(' | ')
    attributes[:optional_author] = "<itunes:author>#{author}</itunes:author>"
  else
    attributes[:optional_author] = ''
  end
  attributes[:date] = Time.parse(attributes[:date]).strftime("%a, %e %b %Y %T %z").gsub(/\s\+/, ' ')
  attributes[:title] = esc attributes[:title]
  attributes[:description] = esc attributes[:description]
  uri = URI(attributes[:link])
  begin
    Net::HTTP.start(uri.host, read_timeout: LENGTH_REQUEST_TIMEOUT) { |http|
      attributes[:length] = http.head(uri.path)['Content-Length']
    }
  rescue
  end
  attributes[:length] ||= 1
  attributes[:link] = url_esc attributes[:link]
  return attributes
end

get '/*' do
  details = params['splat'].join('/')
  pinboard_response = URI.open(Pinboard + details).read
  rss = Nokogiri::XML(pinboard_response)
  header = Header % parse_children(rss.at_xpath('//xmlns:channel'))
  elements = Async do
    rss.xpath('//xmlns:items/rdf:Seq/rdf:li').map { |elem|
      audio_path = elem.attributes.values.first
      item = rss.at_xpath(%Q|//xmlns:item[@rdf:about="#{audio_path}"]|)
      Async do
        Item % item_data(item)
      end
    }
  end.wait.map &:wait
  headers "Content-Type" => "text/xml; charset=utf-8"
  header + elements.join("\n") + Footer
end
