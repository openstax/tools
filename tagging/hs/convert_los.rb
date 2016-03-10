#!/usr/bin/env ruby

require 'roo'
require 'axlsx'

OUTPUT_HEADERS = ['Old LO', 'New LO']

class Array
  alias_method :blank?, :empty?
end

def convert_lo(lo)
  matches = /\A\w+-?ch(\d+)-?s(\d+)-?lo(\d+)\z/.match lo
  return '' if matches.nil?

  "#{matches[1].to_i}-#{matches[2].to_i}-#{matches[3].to_i}"
end

if ARGV.length != 2
  puts 'Usage: hs/convert_los.rb input_spreadsheet output_spreadsheet'
  puts 'Writes an xlsx file with name output_spreadsheet containing the LO\'s in'
  puts 'input_spreadsheet converted to the new format'
  abort
end

input_book = Roo::Excelx.new(ARGV[0])

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: 'LO\'s') do |output_sheet|
    bold = output_sheet.styles.add_style b: true
    output_sheet.add_row OUTPUT_HEADERS, style: bold

    input_book.each_row_streaming(offset: 1, pad_cells: true) do |row|
      lo_cell = row[0]
      next if lo_cell.nil?
      lo = lo_cell.value
      next if lo.nil? || lo.empty?

      output_sheet.add_row [lo, convert_lo(lo)]
    end
  end

  if package.serialize(ARGV[1])
    puts 'Wrote output file'
  else
    puts 'ERROR: Failed to write output file'
  end
end
