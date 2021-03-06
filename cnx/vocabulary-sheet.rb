#!/usr/bin/env ruby

require_relative 'lib/book'
require 'optparse'
require 'axlsx'
require 'json'
require 'roo'

# Roo doesn't currently read the comment cells with MATHML properly.
# It takes the first matching `./text/r/t` using at_xpath, when it really needs the last
# https://github.com/roo-rb/roo/blob/1586ef279162f55a4e3b3e692d57b2b4ae4c8b34/lib/roo/excelx/comments.rb#L16
# To obtain the mathml it's necessary to:
# doc=Roo::Excelx.new('vocabulary.xlsx')
# sheet = x.sheet_for('Terms')
# ex=Roo::Excelx::Extractor.new(sheet.comments_files.first)
# ex.send(:doc).xpath('//comments/commentList/comment').first.xpath('./text/r').last

PROTECTION_PASSWORD = 'openstax'

options = {}
ARGV << '-h' if ARGV.empty?
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("--cnx-url [STRING]", "CNX Book archive url")         { |url| options[:cnx_url] = url }
  opts.on("--chapters 1,2,3,4", Array, "Chapters to extract")   { |chp| options[:chapters] = chp }
  opts.on("--lo-xlsx [PATH]", "Path to a spreadsheet with LOs") { |lo | options[:lo_xlsx] = lo }
  opts.on("--output  [PATH]",  "Output spreadsheet")            { |out| options[:out] = out }
  opts.on("--distractors [Number]", Integer, "Number of distractor columns to include (defaults to 3)") { |n|
    options[:distractors] = n
  }
  opts.on_tail("-h", "--help", "Show this message")             { puts opts; exit }
end.parse!

[:cnx_url].each do |opt|
  unless options.has_key?(opt)
    puts "Required option --#{opt} missing."
    exit
  end
end
options[:distractors] ||= 3

puts "Performing task with options: #{options.inspect}"

book = CNX::Book.fetch(options[:cnx_url])
chapters = if options[:chapters]
             book.select{|chapter| options[:chapters].include?(chapter.number.to_s) }
           else
             book.to_a
           end

def protect_worksheet(sheet)
    sheet.sheet_protection.password = PROTECTION_PASSWORD
    sheet.sheet_protection.format_cells   = false
    sheet.sheet_protection.format_rows    = false
    sheet.sheet_protection.format_columns = false
end

Axlsx::Package.new do |package|
  cs_row_num = 0

  package.workbook.add_worksheet(name: "Terms") do |sheet|
    protect_worksheet(sheet)
    bold = sheet.styles.add_style b: true
    unlocked = sheet.styles.add_style locked: false
    center = sheet.styles.add_style alignment: {horizontal: :center}
    sheet.add_row(['Book', 'Vocab #', 'Module', 'Module UUID', 'Term', 'LO'] +
                  options[:distractors].times.map{|n| "Distractor #{n+1}" } +
                  ['Definition'], style: bold)

    chapters.each do | chapter |
      puts "Adding chapter # #{chapter.number}"
      chapter.each do | section |
        section.glossary_terms.each do | gt |
          if gt.inner_html
            sheet.add_comment ref: "E#{cs_row_num+2}", author: 'MATH',
                              visible: false, text: gt.inner_html
          end
          row = [
            book.title, cs_row_num+=1, "#{chapter.number}-#{section.number}",
            section.uuid, gt.term, ''
          ] + ([''] * options[:distractors]) + [ gt.definition ]
          sheet.add_row(row)
        end
      end
    end

    sheet.col_style 1, center, row_offset: 1
    sheet.col_style 2, center, row_offset: 1
    5.upto(options[:distractors] + 5){ |col|
      sheet.col_style( col, unlocked, row_offset: 1 )
    }

    last_distractor = Axlsx.col_ref(options[:distractors] + 5)
    # validation for distractors
    sheet.add_data_validation("$G$2:$#{last_distractor}$#{cs_row_num+1}", {
      :type => :list,
      :formula1 => "$E$2:$E$#{cs_row_num+1}",
      :showDropDown => false,
      :showErrorMessage => true,
      :errorTitle => '',
      :error => 'Please use the dropdown selector to choose a valid term',
      :errorStyle => :stop,
      :showInputMessage => false})

    sheet.sheet_view.pane do |pane|
      pane.top_left_cell = "A2"
      pane.state = :frozen
      pane.y_split = 1
      pane.active_pane = :bottom_right
    end

    # Hide the book and module UUID columns
    sheet.column_info[0].hidden = true
    sheet.column_info[3].hidden = true
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
      protect_worksheet(sheet)
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

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A2"
        pane.state = :frozen
        pane.y_split = 1
        pane.active_pane = :bottom_right
      end

      # Add validation on LO column
      package.workbook.sheet_by_name('Terms')
        .add_data_validation("$F$2:$F$#{cs_row_num+1}", {
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

  # Show the first sheet when opened
  package.workbook.add_view active_tab: 0

  dest_file = options[:out] || "vocabulary.xlsx"
  if package.serialize(dest_file)
    puts "Wrote spreadsheet to #{dest_file}"
  else
    puts "ERROR: Failed to write spreadsheet to #{dest_file}"
  end
end
