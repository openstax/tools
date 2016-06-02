#!/usr/bin/env ruby

require 'roo'
require 'axlsx'
require 'httparty'
require 'json'

OUTPUT_HEADERS_WITH_EXERCISES = ['Chapter', 'Section', 'Title', 'UUID', 'Exercise Numbers']

BOOK_UUIDS = {
  'k12phys' => '334f8b61-30eb-4475-8e05-5260a4866b4b',
  'apbio' => 'd52e93f4-8653-4273-86da-3850001c0786'
}

if ARGV.length < 2 || ARGV.length > 3
  puts 'Usage: hs/lookup_exercises.rb hs_book_name output_spreadsheet [exercises_base_url]'
  puts 'Writes an xlsx file with name output_spreadsheet containing a list of CNX module UUID\'s'
  puts 'and the exercises associated with each module for the given hs_book_name'
  puts 'Uses the instance of Exercises at exercises_base_url, or production if not specified'
  abort
end

hs_book_name = ARGV[0]
ARGV[0] = "https://archive-staging-tutor.cnx.org/contents/#{BOOK_UUIDS[hs_book_name]}"
output_filename = ARGV[1]
exercises_base_url = ARGV[2] || 'https://exercises.openstax.org'

Tempfile.open(['uuids', '.xlsx']) do |file|
  ARGV[1] = file.path

  require_relative '../../cnx/lookup_uuids'

  temp_book = Roo::Excelx.new(file.path)

  Axlsx::Package.new do |package|
    package.workbook.add_worksheet(name: 'Exercises') do |output_sheet|
      bold = output_sheet.styles.add_style b: true
      output_sheet.add_row OUTPUT_HEADERS_WITH_EXERCISES, style: bold

      temp_book.each_row_streaming(offset: 1, pad_cells: true) do |row|
        values = 0.upto(row.size - 1).map do |index|
          # Hack until Roo's new version with proper typecasting is released
          val = (row[index] || OpenStruct.new).value
          Integer(val, 10) rescue val
        end
        next if values.compact.empty?

        exercises_tag = "#{hs_book_name}-ch%02d-s%02d" % [values[0], values[1]]
        exercises_hash = HTTParty.get("#{exercises_base_url}/api/exercises?q=tag:#{exercises_tag}")
                                 .to_hash
        exercise_numbers = exercises_hash['items'].map{ |exercise| exercise['number'] }
        output_sheet.add_row values + [exercise_numbers.join(',')]
      end
    end

    if package.serialize(output_filename)
      puts 'Wrote Exercises output file'
    else
      puts 'ERROR: Failed to write Exercises output file'
    end
  end
end
