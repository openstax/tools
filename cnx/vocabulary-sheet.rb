#!/usr/bin/env ruby

require 'axlsx'
require 'httparty'
require 'json'
require 'optparse'
require_relative 'lib/book'
require 'pry'

options = {}
ARGV << '-h' if ARGV.empty?
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("-u", "--cnx-url [STRING]", "CNX Book archive url")  { |url| options[:url] = url }
  opts.on("-c", "--chapters 1,2,3,4", Array, "Chapters to extract")   { |chp| options[:chapters] = chp }
  opts.on("-o", "--output  [STRING]",  "Output spreadsheet")   { |out| options[:out] = out }
  opts.on_tail("-h", "--help", "Show this message")  { puts opts; exit }
end.parse!

OUTPUT_HEADERS = ['Vocab #', 'Module', 'Term', 'Distractor 1', 'Distractor 2', 'Distractor 3', 'Definition']

book = CNX::Book.fetch(options[:url])

Axlsx::Package.new do |package|
  package.workbook.add_worksheet(name: "Terms") do |sheet|
    bold = sheet.styles.add_style b: true
    center = sheet.styles.add_style alignment: {horizontal: :center}
    sheet.add_row OUTPUT_HEADERS, style: bold
    row_num = 0
    chapters = if options[:chapters]
                 book.select{|chapter| options[:chapters].include?(chapter.number.to_s) }
               else
                 book.to_a
               end

    chapters.each do | chapter |
      chapter.each do | section |
        section.glossary_terms.each do | gt |
          row = [
            row_num+=1,
            "#{chapter.number}-#{section.number}",
            gt.term,
            '', '', '',
            gt.definition
          ]
          sheet.add_row(row)
        end
      end
    end

    sheet.col_style 0, center, row_offset: 1
    sheet.col_style 1, center, row_offset: 1

    sheet.add_data_validation("$D$2:$F$#{row_num+1}", {
      :type => :list,
      :formula1 => "$C$2:$C$#{row_num+1}",
      :showDropDown => false,
      :showErrorMessage => true,
      :errorTitle => '',
      :error => 'Please use the dropdown selector to choose a valid term',
      :errorStyle => :stop,
      :showInputMessage => false})
  end

  if package.serialize(options[:out] || "vocabulary.xlsx")
    puts 'Wrote spreadsheet'
  else
    puts 'ERROR: Failed to write spreadsheet'
  end
end
