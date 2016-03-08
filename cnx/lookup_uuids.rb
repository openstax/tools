#!/usr/bin/env ruby

require 'axlsx'
require 'httparty'
require 'json'

OUTPUT_HEADERS = ['Chapter', 'Section', 'UUID', 'Title']

def map_collection(hash, cnx_id_map, chapter_number = 0)
  contents = hash['contents']
  chapter_number += 1 if contents.none?{ |hash| hash['id'] == 'subcol' }

  page_number = nil
  contents.each do |entry|
    if entry['id'] == 'subcol'
      chapter_number = map_collection(entry, cnx_id_map, chapter_number)
    else
      page_number ||= entry['title'].start_with?('Introduction') ? 0 : 1
      cnx_id_map[chapter_number][page_number] = [entry['id'].split('@').first, entry['title']]
      page_number += 1
    end
  end

  return chapter_number
end

if ARGV.length != 2
  puts 'Usage: lookup_uuids.rb cnx_book_archive_url output_spreadsheet'
  puts 'Writes an xlsx file with name output_spreadsheet containing a list of CNX'
  puts 'chapter/section numbers and their module UUIDs for the given cnx_book_archive_url'
  abort
end

cnx_book_archive_url = ARGV[0]
output_filename = ARGV[1]

cnx_id_map = Hash.new{ |hash, key| hash[key] = {} }
response = HTTParty.get("#{cnx_book_archive_url.chomp('.html').chomp('.json')}.json").to_hash
puts "Using module UUIDs for #{response['title']}"
map_collection(response['tree'], cnx_id_map)

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: "UUID's") do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    cnx_id_map.each do |chapter_number, sections|
      sections.each do |section_number, uuid_title|
        output_sheet.add_row [chapter_number, section_number] + uuid_title
      end
    end
  end

  if package.serialize(output_filename)
    puts 'Wrote output file'
  else
    puts 'ERROR: Failed to write output file'
  end
end
