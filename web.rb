require 'async'
require 'cgi'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'sinatra'
require 'time'

Pinboard = "https://feeds.pinboard.in/rss/"

LENGTH_REQUEST_TIMEOUT = 1

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
    attributes[:author] = author.join(' | ')
  end
  attributes[:date] = Time.parse(attributes[:date]).strftime("%a, %-e %b %Y %T %z")
  uri = URI(attributes[:link])
  begin
    Net::HTTP.start(uri.host, read_timeout: LENGTH_REQUEST_TIMEOUT) { |http|
      attributes[:length] = http.head(uri.path)['Content-Length']
    }
  rescue
  end
  attributes[:length] ||= '1'
  return attributes
end

get '/*' do
  details = params['splat'].join('/')
  pinboard_response = URI.open(Pinboard + details).read
  rss = Nokogiri::XML(pinboard_response)
  header = parse_children(rss.at_xpath('//xmlns:channel'))
  elements = Async do
    rss.xpath('//xmlns:items/rdf:Seq/rdf:li').map { |elem|
      audio_path = elem.attributes.values.first
      item = rss.at_xpath(%Q|//xmlns:item[@rdf:about="#{audio_path}"]|)
      Async { item_data(item) }
    }
  end.wait.map &:wait
  headers "Content-Type" => "text/xml; charset=utf-8"

  Nokogiri::XML::Builder.new { |xml|
    xml.rss(
      'xmlns:atom' => "http://www.w3.org/2005/Atom",
      'xmlns:itunes' => "http://www.itunes.com/dtds/podcast-1.0.dtd",
      'version' => "2.0"
    ) {
      xml.channel {
        xml.title header[:title]
        xml.description header[:description]
        xml.link header[:link]
        xml.language 'en-us'

        elements.each do |element|
          xml.item {
            xml.title element[:title]
            xml['itunes'].author element[:author] if element[:author]
            xml.enclosure(
              url: element[:link],
              length: element[:length],
              type: "audio/mpeg",
            )
            xml.description element[:description]
            xml.pubDate element[:date]
          }
        end
      }
    }
  }.to_xml
end
