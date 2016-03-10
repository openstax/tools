#!/usr/bin/env ruby

require 'roo'
require 'axlsx'
require 'httparty'
require 'json'
require_relative '../../cnx/lib/map_collection'

OUTPUT_HEADERS = [
  'book', 'chapter', 'section', 'lo', 'id', 'cnxmod', 'ost-type', 'dok', 'blooms', 'art', 'time',
  'display', 'requires-choices?', 'list', 'question', 'detailed-solution', 'correct-answer', 'a',
  'feedback-a', 'b', 'feedback-b', 'c', 'feedback-c', 'd', 'feedback-d'
]

TRUE_VALUES = ['true', 't', 'yes', 'y', '1']
FALSE_VALUES = ['false', 'f', 'no', 'n', '0']

class Array
  alias_method :blank?, :empty?
end

def convert_row(row, cnx_book_hash)
  book = row[0]

  chapter_matches = /\Ach(\d+)\z/i.match row[1]
  chapter = chapter_matches[1].to_i

  section_matches = /\As(\d+)\z/i.match row[2]
  section = section_matches[1].to_i

  lo_matches = /lo(\d+)\z/i.match row[3]
  lo = lo_matches[1]

  id = row[4]

  cnxmod = extract_uuid(cnx_book_hash[chapter][section]) || ''

  type = row[5]

  full_dok = row[7]
  dok = /\Adok(\d+)\z/i.match(full_dok)[1]

  full_blooms = row[10]
  blooms = /\Ablooms-(\d+)\z/i.match(full_blooms)[1]

  text_columns = row.slice(11..-1)
  art_columns = text_columns.slice(1..2) + text_columns.slice(4..-1)

  art = art_columns.any?{ |text| /!\[.+\]\(.+\)/.match text.to_s } ? 'y' : 'n'

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

  [book, chapter, section, lo, id, cnxmod, type, dok, blooms, art, time, display, req_choices] + \
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
        puts "WARNING: Due to an error, skipped row ##{row_index + 1} containing #{values.inspect}"
      end
    end
  end

  if package.serialize(ARGV[1])
    puts 'Conversion done'
  else
    puts 'ERROR: Failed to write output file'
  end
end
