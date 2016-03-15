require_relative 'map_collection'
require 'hashie/mash'
require 'oga'

# Download chapters/sections from a CNX book and parse out
# items of interest (currently only glossary terms)
module CNX

  module Book

    # Main entry point.  Call with a url of a CNX book
    def self.fetch(url)
      # Regex turns a URL like http://cnx.org/contents/GFy_h8cu into http://archive.cnx.org/contents/GFy_h8cu.json
      # while still working if it's passed an already valid url like: archive.cnx.org/contents/GFy_h8cu.json
      url.sub!(/^.*(cnx\.org.*)(:?\.\w{4})*$/, 'http://archive.\1.json')

      Book.new( HTTParty.get(url).to_hash )
    end

    class GlossaryTerm < Hashie::Mash
    end

    class Section < Hashie::Mash

      def initialize(number, attrs)
        super(attrs)
        self.number = number
      end

      def url
        "http://archive.cnx.org/contents/#{self.id}.html"
      end

      def contents
        @contents ||= Oga.parse_html(HTTParty.get(url).body)
      end

      def glossary_terms
        Enumerator.new do |terms|
          contents.css('[data-type="glossary"] .definition').each do | term |
            terms << GlossaryTerm.new(term: term.css('dt').text, definition: term.css('dd').text)
          end
        end
      end
    end

    class Chapter
      include Enumerable
      attr_reader :number

      def initialize(number, sections)
        @number = number; @sections = sections
      end

      def each
        @sections.each{ |number, attrs| yield Section.new(number, attrs) }
      end
    end

    class Book
      include Enumerable

      attr_reader :title

      def initialize(response)
        @toc = Hash.new{ |hash, key| hash[key] = {} }
        map_collection(response['tree'], @toc )
        @title = response['title']
      end

      def each
        @toc.each{ |chapter_number, section_hashes| yield Chapter.new(chapter_number, section_hashes) }
      end

    end

  end
end
