#!/usr/bin/env ruby

require 'rubyXL'
require 'axlsx'
require 'httparty'
require 'json'

OUTPUT_HEADERS = [
  'book', 'chapter', 'section', 'lo', 'id', 'cnxmod', 'ost-type', 'dok', 'blooms', 'art', 'time',
  'display', 'requires-choices?', 'question', 'detailed-solution', 'correct-answer', 'a',
  'feedback-a', 'b', 'feedback-b', 'c', 'feedback-c', 'd', 'feedback-d'
]

BOOK_TAG_MAP = lambda do |book, chapter|
  book = book.downcase

  case book
  when 'econ'
    case chapter.to_i
    when 1, 2, 3, 4, 5, 33, 34
      'stax-econ,stax-micro,stax-macro'
    when 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
      'stax-econ,stax-micro'
    when 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
      'stax-econ,stax-macro'
    end
  else
    "stax-#{book}"
  end
end

TRUE_VALUES = ['true', 't', 'yes', 'y', '1']
FALSE_VALUES = ['false', 'f', 'no', 'n', '0']

class Array
  alias_method :blank?, :empty?
end

def map_collection(hash, cnx_id_map, chapter_number = 0)
  contents = hash['contents']
  chapter_number += 1 if contents.none?{ |hash| hash['id'] == 'subcol' }

  page_number = nil
  contents.each do |entry|
    if entry['id'] == 'subcol'
      chapter_number = map_collection(entry, cnx_id_map, chapter_number)
    else
      page_number ||= entry['title'].start_with?('Introduction') ? 0 : 1
      cnx_id_map[chapter_number][page_number] = entry['id'].split('@').first
      page_number += 1
    end
  end

  return chapter_number
end

def convert_row(row, cnx_id_map)
  full_lo = row[1]
  full_lo_matches = /\A(\w+)ch(\d+)-?s(\d+)-lo(\d+)\z/.match full_lo
  book_original = full_lo_matches[1]
  chapter = full_lo_matches[2]
  book = BOOK_TAG_MAP.call(book_original, chapter)
  section = full_lo_matches[3]
  lo = full_lo_matches[4]

  full_id = row[0]
  id = /\ACNX_CC_[\w]+_(\d+)\z/.match(full_id)[1]

  cnxmod = cnx_id_map[full_lo_matches[2].to_i][full_lo_matches[3].to_i] || ''

  type = 'concept-coach'

  full_dok = row[5]
  dok = /\Adok(\d+)\z/.match(full_dok)[1]

  full_blooms = row[6]
  blooms = /\Ablooms-(\d+)\z/.match(full_blooms)[1]

  art = row[7].downcase[0]

  full_time = row[8]
  time = /\Atime-(\w+)\z/.match(full_time)[1]

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

  text_columns = row.slice(11..-1)

  [book, chapter, section, lo, id, cnxmod, type, dok, blooms, art, time, display, req_choices] + \
  text_columns.map{ |text| text.to_s.gsub(/\\?_/, '\_') }
end

if ARGV.length < 2 || ARGV.length > 3
  puts 'Usage: convert.rb input_filename output_filename [book_cnx_url]'
  puts 'Only the first sheet of the input spreadsheet will be used'
  puts 'If a book URL is specified, the chapter/section for each exercise'
  puts 'will be used to pull the page UUID according to the book structure'
  abort
end

book_cnx_url = ARGV[2]
cnx_id_map = Hash.new{ |hash, key| hash[key] = {} }
unless book_cnx_url.nil?
  response = HTTParty.get("#{book_cnx_url.chomp('.json')}.json").to_hash
  puts "Using module UUIDs for #{response['title']}"
  map_collection(response['tree'], cnx_id_map)
end

input_sheet = RubyXL::Parser.parse(ARGV[0]).worksheets[0]

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: input_sheet.sheet_name || 'Assessments') do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    input_sheet.each_with_index do |row, index|
      next if index == 0

      values = 0.upto(row.size - 1).collect do |index|
        (row[index] || OpenStruct.new).value
      end
      next if values.compact.blank?

      begin
        output_sheet.add_row convert_row(values, cnx_id_map)
      rescue
        puts "WARNING: Due to an error, skipped row ##{index + 1} containing #{values.inspect}"
      end
    end
  end

  if package.serialize(ARGV[1])
    puts 'Conversion done'
  else
    puts 'ERROR: Failed to write output file'
  end
end
