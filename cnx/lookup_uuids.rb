#!/usr/bin/env ruby

require 'axlsx'
require 'httparty'
require 'json'
require_relative 'lib/map_collection'

OUTPUT_HEADERS = ['UUID', 'Chapter', 'Section', 'Title']

if ARGV.length != 2
  puts 'Usage: lookup_uuids.rb cnx_book_archive_url output_spreadsheet'
  puts 'Writes an xlsx file with name output_spreadsheet containing a list of CNX module'
  puts 'UUID\'s, chapter/section numbers and titles for the given cnx_book_archive_url'
  abort
end

cnx_book_archive_url = ARGV[0]
output_filename = ARGV[1]

cnx_book_hash = Hash.new{ |hash, key| hash[key] = {} }
response = HTTParty.get("#{cnx_book_archive_url.chomp('.html').chomp('.json')}.json").to_hash
puts "Using module UUIDs for #{response['title']}"
map_collection(response['tree'], cnx_book_hash)

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: "UUID's") do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    cnx_book_hash.each do |chapter_number, section_hashes|
      section_hashes.each do |section_number, section_hash|
        uuid = extract_uuid(section_hash)
        title = section_hash['title']
        output_sheet.add_row [uuid, chapter_number, section_number, title]
      end
    end
  end

  if package.serialize(output_filename)
    puts 'Wrote output file'
  else
    puts 'ERROR: Failed to write output file'
  end
end
