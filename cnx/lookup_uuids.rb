#!/usr/bin/env ruby

require 'axlsx'
require_relative 'lib/book'

OUTPUT_HEADERS = ['Chapter', 'Section', 'Title', 'UUID']

if ARGV.length != 2
  puts 'Usage: ./lookup_uuids.rb cnx_book_url output_spreadsheet'
  puts 'Writes an xlsx file with name output_spreadsheet containing a list of CNX module'
  puts 'chapter/section numbers, titles and UUID\'s for the given cnx_book_url'
  abort
end

cnx_book_url = ARGV[0]
output_filename = ARGV[1]

book = CNX::Book.fetch(cnx_book_url)

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: "UUID's") do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    book.each do |chapter|
      chapter.each do |section|
        output_sheet.add_row [chapter.number, section.number, section.title, section.uuid]
      end
    end
  end

  if package.serialize(output_filename)
    puts 'Wrote UUID\'s'
  else
    puts 'ERROR: Failed to write UUID\'s'
  end
end
