#!/usr/bin/env ruby

require_relative 'lib/book'
require 'optparse'
require 'axlsx'
require 'json'
require 'roo'

require 'pry' # REMOVE!

options = {}
ARGV << '-h' if ARGV.empty?
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("--cnx-url [STRING]", "CNX Book archive url")         { |url| options[:cnx_url] = url }
  opts.on("--chapters 1,2,3,4", Array, "Chapters to extract")   { |chp| options[:chapters] = chp }
  opts.on("--lo-xlsx [PATH]", "Path to a spreadsheet with LOs") { |lo | options[:lo_xlsx] = lo }
  opts.on("--output  [PATH]",  "Output spreadsheet")            { |out| options[:out] = out }
  opts.on_tail("-h", "--help", "Show this message")             { puts opts; exit }
end.parse!

[:cnx_url].each do |opt|
  unless options.has_key?(opt)
    puts "Required option --#{opt} missing."
    exit
  end
end
puts "Performing task with options: #{options.inspect}"

book = CNX::Book.fetch(options[:cnx_url])
chapters = if options[:chapters]
             book.select{|chapter| options[:chapters].include?(chapter.number.to_s) }
           else
             book.to_a
           end

Axlsx::Package.new do |package|
  cs_row_num = 0

  package.workbook.add_worksheet(name: "Terms") do |sheet|
    bold = sheet.styles.add_style b: true
    center = sheet.styles.add_style alignment: {horizontal: :center}
    sheet.add_row(['Vocab #', 'Module', 'Term', 'LO', 'Distractor 1',
                   'Distractor 2', 'Distractor 3', 'Definition'], style: bold)

    chapters.each do | chapter |
      chapter.each do | section |
        section.glossary_terms.each do | gt |
          row = [
            cs_row_num+=1,
            "#{chapter.number}-#{section.number}",
            gt.term,
            '', '', '', '',
            gt.definition
          ]
          sheet.add_row(row)
        end
      end
    end

    sheet.col_style 0, center, row_offset: 1
    sheet.col_style 1, center, row_offset: 1

    sheet.add_data_validation("$E$2:$G$#{cs_row_num+1}", {
      :type => :list,
      :formula1 => "$C$2:$C$#{cs_row_num+1}",
      :showDropDown => false,
      :showErrorMessage => true,
      :errorTitle => '',
      :error => 'Please use the dropdown selector to choose a valid term',
      :errorStyle => :stop,
      :showInputMessage => false})
  end

  # Only create the "LO Map" tab if a lookup spreadsheet was given
  if options[:lo_xlsx]
    los = Hash.new{ |hash, key| hash[key] = [] }
    # Extract and group the chapter_section portion of the LO's
    Roo::Excelx.new(options[:lo_xlsx]).each_row_streaming(offset: 1) do | row |
      next unless row.length > 2 and (lo = row[1].value)
      # Extracts the first two digit pairs, i.e. the '12-23' of '12-23-18'
      chapter_section_part = lo[/(\d+-\d+)/, 0]
      los[ chapter_section_part ].push( [lo, row[2].value] )
    end


    lo_rows = 0
    package.workbook.add_worksheet(name: "LO Map") do |sheet|
      bold = sheet.styles.add_style b: true
      center = sheet.styles.add_style alignment: {horizontal: :center}
      sheet.add_row ['LO', 'LO Text'], style: bold

      chapters.each do | chapter |
        chapter.each do | section |
          prefix = "#{chapter.number}-#{section.number}"
          los[prefix].each do | lo, text |
            sheet.add_row [lo, text]
            lo_rows+=1
          end
        end
      end
      sheet.col_style 0, center, row_offset: 1

      # Add validation on LO column
      package.workbook.sheet_by_name('Terms')
        .add_data_validation("$D$2:$D$#{cs_row_num+1}", {
          :type => :list,
          :formula1 => "'LO Map'!$A$2:$A$#{lo_rows+1}",
          :showDropDown => false,
          :showErrorMessage => true,
          :errorTitle => '',
          :error => 'Please use the dropdown selector to choose a valid LO',
          :errorStyle => :stop,
          :showInputMessage => false})

    end
  end

  if package.serialize(options[:out] || "vocabulary.xlsx")
    puts 'Wrote spreadsheet'
  else
    puts 'ERROR: Failed to write spreadsheet'
  end
end
