#!/usr/bin/env ruby

require 'roo'
require 'axlsx'
require 'httparty'
require 'json'
require_relative '../cnx/lib/map_collection'

OUTPUT_HEADERS = [
  'book', 'chapter', 'section', 'lo', 'id', 'cnxmod', 'ost-type', 'dok', 'blooms', 'art', 'time',
  'display', 'requires-choices?', 'list', 'question', 'detailed-solution', 'correct-answer', 'a',
  'feedback-a', 'b', 'feedback-b', 'c', 'feedback-c', 'd', 'feedback-d'
]

BOOK_TAG_MAP = lambda do |book, chapter|
  book = book.downcase

  case book
  when 'cph'
    'stax-phys'
  when 'bfm'
    'stax-bio'
  when 'soc2e'
    'stax-soc'
  when 'econ'
    case chapter.to_i
    when 1, 2, 3, 4, 5, 33, 34
      'stax-econ,stax-micro,stax-macro'
    when 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
      'stax-econ,stax-micro'
    when 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
      'stax-econ,stax-macro'
    end
  when 'cob'
    'stax-cbio'
  else
    "stax-#{book}"
  end
end

TRUE_VALUES = ['true', 't', 'yes', 'y', '1']
FALSE_VALUES = ['false', 'f', 'no', 'n', '0']

class Array
  alias_method :blank?, :empty?
end

def convert_row(row, cnx_book_hash)
  full_lo = row[1]
  full_lo_matches = /\A(\w+)ch(\d+)-?s(\d+)-lo(\d+)\z/i.match full_lo
  book_original = full_lo_matches[1]
  chapter = full_lo_matches[2].to_i
  book = BOOK_TAG_MAP.call(book_original, chapter)
  section = full_lo_matches[3].to_i
  lo = full_lo_matches[4]

  full_id = row[0]
  id = /\ACNX_CC_[\w]+_(\d+)\z/i.match(full_id)[1]

  cnxmod = extract_uuid(cnx_book_hash[chapter][section]) || ''

  type = 'concept-coach'

  full_dok = row[5]
  dok = /\Adok(\d+)\z/i.match(full_dok)[1]

  full_blooms = row[6]
  blooms = /\Ablooms-(\d+)\z/i.match(full_blooms)[1]

  art = row[7].downcase[0]

  full_time = row[8]
  time = /\Atime-(\w+)\z/i.match(full_time)[1]

  display = 'multiple-choice'

  full_displays = row[9].split(/,|\r?\n/).map(&:strip)
  if full_displays.include?('display-simple-mc')
    req_choices = 'y'
    if row.length < 19
      first_answer = row[14].to_s.strip.chomp('.').downcase
      second_answer = row[16].to_s.strip.chomp('.').downcase
      display = 'true-false' \
        if TRUE_VALUES.include?(first_answer) && FALSE_VALUES.include?(second_answer)
    end
  elsif full_displays.include?('display-free-response')
    req_choices = 'n'
  else
    req_choices = ''
  end

  list = "#{book_original.capitalize} Chapter #{"%02d" % chapter}"

  text_columns = row.slice(11..-1)

  [book, chapter, section, lo, id, cnxmod, type,
   dok, blooms, art, time, display, req_choices, list] + \
  text_columns.map{ |text| text.to_s.gsub(/(?:\\?_){3,}/){ |match| match.gsub(/\\?_/, '\_') } }
end

if ARGV.length < 2 || ARGV.length > 3
  puts 'Usage: convert.rb input_filename output_filename [book_cnx_url]'
  puts 'Only the first sheet of the input spreadsheet will be used'
  puts 'If a book URL is specified, the chapter/section for each exercise'
  puts 'will be used to pull the page UUID according to the book structure'
  abort
end

book_cnx_url = ARGV[2]
cnx_book_hash = Hash.new{ |hash, key| hash[key] = {} }
unless book_cnx_url.nil?
  response = HTTParty.get("#{book_cnx_url.chomp('.html').chomp('.json')}.json").to_hash
  puts "Using module UUIDs for #{response['title']}"
  map_collection(response['tree'], cnx_book_hash)
end

input_book = Roo::Excelx.new(ARGV[0])

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: input_book.default_sheet || 'Assessments') do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    input_book.each_row_streaming(offset: 1, pad_cells: true).each_with_index do |row, row_index|
      values = 0.upto(row.size - 1).collect do |index|
        # Hack until Roo's new version with proper typecasting is released
        val = (row[index] || OpenStruct.new).value
        Integer(val, 10) rescue val
      end
      next if values.compact.blank?

      begin
        output_sheet.add_row convert_row(values, cnx_book_hash)
      rescue
        puts "WARNING: Due to an error, skipped row ##{row_index + 2} containing #{values.inspect}"
      end
    end
  end

  if package.serialize(ARGV[1])
    puts 'Conversion done'
  else
    puts 'ERROR: Failed to write output file'
  end
end
