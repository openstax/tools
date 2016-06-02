#!/usr/bin/env ruby

require 'roo'
require 'axlsx'
require 'httparty'
require_relative '../../cnx/lib/book'

OUTPUT_HEADERS = ['Exercises', 'CNXMOD Tag']

BOOK_UUIDS = {
  'phys' => '031da8d3-b525-429c-80cf-6c8ed997733a',
  'phys-courseware' => '405335a3-7cff-4df2-a9ad-29062a4af261'
}


if ARGV.length < 3 || ARGV.length > 4
  puts 'Usage: hs/copy_exercises.rb orig_book_name dest_book_name output_spreadsheet [exercises_base_url]'
  puts 'Takes as input 2 book names, 1 filename and 1 optional url:'
  puts '1. Origin book name (e.g. phys)'
  puts '2. Destination book name (e.g. phys-courseware)'
  puts '3. Output spreadsheet filename (e.g. phystags.xlsx)'
  puts '4. (Optional) Exercises base url (e.g. https://exercises.openstax.org)'
  puts 'Writes in the output xlsx spreadsheet a list of Exercise numbers'
  puts 'and the tags that will be associated with those exercises'
  abort
end

orig_book_name = ARGV[0]
orig_book_uuid = BOOK_UUIDS[orig_book_name]
raise "Invalid origin book name: #{orig_book_name}" if orig_book_uuid.nil?

dest_book_name = ARGV[1]
dest_book_uuid = BOOK_UUIDS[dest_book_name]
raise "Invalid destination book name: #{dest_book_name}" if dest_book_uuid.nil?

output_filename = ARGV[2]
exercises_base_url = ARGV[3] || 'https://exercises.openstax.org'

orig_book_url = "https://archive.cnx.org/contents/#{orig_book_uuid}"
dest_book_url = "https://archive.cnx.org/contents/#{dest_book_uuid}"

orig_book = CNX::Book.fetch(orig_book_url)
dest_book = CNX::Book.fetch(dest_book_url)

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: 'New Tags') do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    orig_book.chapters.each_with_index do |orig_chapter, chapter_index|
      orig_chapter.sections.each_with_index do |orig_section, section_index|
        dest_section = dest_book.chapters[chapter_index].sections[section_index]

        if dest_section.nil?
          puts "WARNING: Skipped section \"#{orig_section.title}\" from #{orig_book_name
                } because it has no correspondence in #{dest_book_name}"
          next
        end

        orig_cnxmod_tag = "context-cnxmod:#{orig_section.uuid}"
        dest_cnxmod_tag = "context-cnxmod:#{dest_section.uuid}"

        exercises_url = "#{exercises_base_url}/api/exercises?q=tag:\"#{orig_cnxmod_tag}\""
        exercises_hash = HTTParty.get(exercises_url).to_hash
        exercise_numbers = exercises_hash['items'].map{ |exercise| exercise['number'] }
        next if exercise_numbers.empty?

        output_sheet.add_row [exercise_numbers.join(','), dest_cnxmod_tag],
                             types: [:string, :string]
      end
    end
  end

  if package.serialize(output_filename)
    puts "Wrote exercise tags spreadsheet #{output_filename}"
  else
    puts "ERROR: Failed to write exercises tags spreadsheet #{output_filename}"
  end
end
