#!/usr/bin/env ruby

require 'roo'
require 'axlsx'
require 'httparty'
require_relative '../../cnx/lib/book'

OUTPUT_HEADERS = ['Exercises', 'CNXMOD Tags', 'LO Tags']

BOOK_MAPS = {
  'k12phys' => { col_name: 'stax-phys', col_uuid: '031da8d3-b525-429c-80cf-6c8ed997733a' },
  'apbio' => { col_name: 'stax-bio', col_uuid: '185cbf87-c72e-48f5-b51e-f14f21b5eabd' }
}

class Array
  alias_method :blank?, :empty?
end

if ARGV.length < 3 || ARGV.length > 4
  puts 'Usage: hs/map_exercises.rb hs_book_name input_spreadsheet output_spreadsheet [exercises_base_url]'
  puts 'Takes as input a spreadsheet with the following columns:'
  puts '1. Origin LO or book location (chapter.section)'
  puts '2. Target LO or book location'
  puts 'Writes an xlsx file with name output_spreadsheet containing a list of Exercise numbers'
  puts 'and the tags that will be associated with those exercises'
  abort
end

hs_book_name = ARGV[0]
book_map = BOOK_MAPS[hs_book_name]
raise "Invalid HS book name: #{hs_book_name}" if book_map.nil?

col_book_name = book_map[:col_name]
col_book_uuid = book_map[:col_uuid]

book_url = "https://archive.cnx.org/contents/#{col_book_uuid}"
book = CNX::Book.fetch(book_url)

input_filename = ARGV[1]
output_filename = ARGV[2]
exercises_base_url = ARGV[3] || 'https://exercises.openstax.org'

cnxmod_map = Hash.new{ |hash, key| hash[key] = Hash.new{ |hash, key| hash[key] = Set.new } }
lo_map = Hash.new do |hash, key|
  hash[key] = Hash.new do |hash, key|
    hash[key] = Hash.new{ |hash, key| hash[key] = [] }
  end
end

input_sheet = Roo::Excelx.new(input_filename)
input_sheet.each_row_streaming(offset: 1, pad_cells: true) do |row|
  values = 0.upto(row.size - 1).map{ |index| (row[index] || OpenStruct.new).value.to_s }
  next if values.compact.blank?

  origins = values[0].split(',')
  destinations = values[1].split(',')

  orig_matches = origins.map do |origin|
    /(\d+)-(\d+)-(\d+)/.match(origin) || /(\d+).(\d+)/.match(origin) || \
      raise("Invalid Origin: #{origin}")
  end

  dest_matches = destinations.map do |destination|
    /(\d+)-(\d+)-(\d+)/.match(destination) || /(\d+).(\d+)/.match(destination) || \
      raise("Invalid Destination: #{destination}")
  end

  orig_matches.each do |orig_match|
    orig_chapter = orig_match[1]
    orig_section = orig_match[2]
    orig_lo = orig_match[3]

    dest_matches.each do |dest_match|
      dest_chapter = dest_match[1]
      dest_section = dest_match[2]
      dest_lo = dest_match[3]

      section = book.chapters[dest_chapter.to_i].sections[dest_section.to_i]
      raise "No such chapter/section in #{col_book_name}: #{dest_match[0]}" if section.nil?

      dest_uuid = section.id.split('@').first
      dest_uuid_tag = "cnxmod:#{dest_uuid}"

      cnxmod_map[orig_chapter][orig_section] << dest_uuid_tag

      next if orig_lo.nil? || dest_lo.nil?

      dest_lo_tag = "lo:#{col_book_name}:#{dest_chapter}-#{dest_section}-#{dest_lo}"
      lo_map[orig_chapter][orig_section][orig_lo] << dest_lo_tag
    end
  end
end

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: 'Map') do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    cnxmod_map.each do |chapter_num, chapter_cnxmod_map|
      chapter_lo_map = lo_map[chapter_num]
      chapter_cnxmod_map.each do |section_num, cnxmod_tags_set|
        cnxmod_tags = cnxmod_tags_set.to_a.join(',')
        section_lo_map = chapter_lo_map[section_num]
        section_tag = "#{hs_book_name}-ch%02d-s%02d" % [chapter_num, section_num]
        lo_regex = Regexp.new "\\A#{section_tag}-(?:ap)?lo-?([\\d-]+)\\z"
        exercises_hash = HTTParty.get("#{exercises_base_url}/api/exercises?q=tag:#{section_tag}")
                                 .to_hash
        grouped_exercises = exercises_hash['items'].group_by do |exercise_hash|
          tags = exercise_hash['tags']
          lo_numbers = tags.map do |tag|
            matches = lo_regex.match(tag)
            matches[1].reverse.chomp('0').reverse unless matches.nil?
          end.compact.sort
          puts "WARNING: No LO matching the section tag found in: #{tags.inspect}" \
            if lo_numbers.empty?
          lo_numbers
        end

        grouped_exercises.each do |lo_numbers, exercises|
          exercise_numbers = exercises.map{ |exercise| exercise['number'] }.join(',')
          lo_tags = lo_numbers.flat_map{ |lo_number| section_lo_map[lo_number] }.uniq.join(',')
          output_sheet.add_row [exercise_numbers, cnxmod_tags, lo_tags]
        end
      end
    end
  end

  if package.serialize(output_filename)
    puts "Wrote exercise mapping file #{output_filename}"
  else
    puts "ERROR: Failed to write exercises mapping file #{output_filename}"
  end
end
