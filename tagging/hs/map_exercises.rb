#!/usr/bin/env ruby

require 'roo'
require 'axlsx'
require 'httparty'
require_relative '../../cnx/lib/book'

OUTPUT_HEADERS = ['Exercises', 'New Tags']

BOOK_MAP = {
  'k12phys' => {
    col_name: 'stax-phys',
    col_uuid: '334f8b61-30eb-4475-8e05-5260a4866b4b' # Change me
  },
  'apbio' => {
    col_name: 'stax-bio',
    col_uuid: '334f8b61-30eb-4475-8e05-5260a4866b4b' # Change me
  }
}

class Array
  alias_method :blank?, :empty?
end

if ARGV.length < 3 || ARGV.length > 4
  puts 'Usage: cc/map_exercises.rb hs_book_name input_spreadsheet output_spreadsheet [exercises_base_url]'
  puts 'Takes as input a spreadsheet with the following columns:'
  puts '1. Origin LO or book location (chapter.section)'
  puts '2. Target LO or book location'
  puts 'Writes an xlsx file with name output_spreadsheet containing a list of Exercise UID\'s'
  puts 'and the tags that will be associated with those exercises'
  abort
end

hs_book_name = ARGV[0]
col_book_name = BOOK_MAP[hs_book_name][:col_name]
col_book_uuid = BOOK_MAP[hs_book_name][:col_uuid]
input_filename = ARGV[1]
output_filename = ARGV[2]
exercises_base_url = ARGV[3] || 'https://exercises.openstax.org'

tag_map = Hash.new{ |hash, key| hash[key] = Hash.new{ |hash, key| hash[key] = {} } }

input_sheet = Roo::Excelx.new(input_filename)
input_sheet.each_row_streaming(offset: 1, pad_cells: true) do |row|
  values = 0.upto(row.size - 1).map{ |index| (row[index] || OpenStruct.new).value }
  next if values.compact.blank?

  origins = values[0].split(',')
  destinations = values[1].split(',')

  orig_matches = origins.map do |origin|
    /(\d+)-(\d+)-(\d+)/.match(origin) || /(\d+).(\d+)/.match(origin) || \
      raise "Invalid Origin: #{origin}"
  end

  dest_matches = destinations.map do |destination|
    /(\d+)-(\d+)-(\d+)/.match(destination) || /(\d+).(\d+)/.match(destination) || \
      raise "Invalid Destination: #{destination}"
  end

  book_url = "https://archive.cnx.org/contents/#{col_book_uuid}"
  dest_book = CNX::Book.new(book_url)

  orig_matches.each do |orig_match|
    orig_chapter = orig_match[1]
    orig_section = orig_match[2]
    orig_lo = orig_match[3]

    dest_tags = dest_matches.flat_map do |dest_match|
      dest_chapter = dest_match[1]
      dest_section = dest_match[2]
      dest_lo = dest_match[3]

      dest_uuid = dest_book[dest_chapter][dest_section].id
      dest_uuid_tag = "cnxmod:#{dest_uuid}"

      next [dest_uuid_tag] if dest_lo.nil?

      dest_lo_tag = "lo:#{col_book_name}:#{dest_chapter}-#{dest_section}-#{dest_lo}"
      [dest_uuid_tag, dest_lo_tag]
    end.uniq

    if orig_lo.nil?
      tag_map[orig_chapter][orig_section].default = dest_tags
    else
      tag_map[orig_chapter][orig_section][orig_lo] = dest_tags
    end
  end
end

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: 'Map') do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    book_map.each do |chapter_num, chapter_map|
      chapter_map.each do |section_num, section_map|
        section_tag = "#{hs_book_name}-ch%02d-s%02d" % [chapter_num, section_num]
        lo_regex = Regexp.new "\A#{section_tag}-lo(\\d+)\z"
        exercises_hash = HTTParty.get("#{exercises_base_url}/api/exercises?q=tag:#{section_tag}")
                                 .to_hash
        grouped_exercises = exercises_hash['items'].group_by do |exercise_hash|
          exercise_hash['tags'].map{ |tag| lo_regex.match(tag).try(:[], 1) }.compact.sort
        end

        grouped_exercises.each do |lo_numbers, exercises|
          exercise_numbers = exercises.map{ |exercise| exercise['number'] }.join(',')
          new_tags = lo_numbers.flat_map{ |lo_number| section_map[lo_number] }.uniq.join(',')
          output_sheet.add_row [exercise_numbers, new_tags]
        end
      end
    end
  end

  if package.serialize(output_filename)
    puts 'Wrote exercise mapping file'
  else
    puts 'ERROR: Failed to write exercises mapping file'
  end
end
