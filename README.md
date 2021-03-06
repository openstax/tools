# OpenStax Tools

Generic tools and scripts for OpenStax-related tasks

## Installation

This repository is composed of several subprojects.

To install the dependencies for ruby projects, first clone the main repository
then navigate to the appropriate subproject folder and run `bundle install`:

```sh
git clone https://github.com/openstax/tools.git
cd tools/project
gem install bundler
bundle install
```

In case of errors, make sure you have Xcode and the Xcode command-line tools installed.

## Subprojects

### CNX

#### lookup_uuids.rb

From the cnx folder, run the following command to lookup CNX module UUID's in a collection:

```sh
bundle exec ./lookup_uuids.rb cnx_book_archive_url output_spreadsheet
```

Example:

```sh
bundle exec ./lookup_uuids.rb http://archive.cnx.org/contents/031da8d3-b525-429c-80cf-6c8ed997733a@9.4 uuids.xlsx
```

### vocabulary-sheet.rb

From the cnx folder, run the following command to extract vocabulary terms from glossary sections of a CNX book

```sh
bundle exec ./vocabulary-sheet.rb --chapters 45,46,47 --cnx-url http://cnx.org/contents/185cbf87-c72e-48f5-b51e-f14f21b5eabd --lo-xlsx ../lo.xlsx --output ../Biology-chapters-45-47.xlsx
```

### Tagging

#### lookup_exercises.rb

From the tagging folder, run the following command to lookup exercises associated with an HS book:

```sh
bundle exec hs/lookup_exercises.rb hs_book_name output_spreadsheet [exercises_base_url]
```

Example:

```sh
bundle exec hs/lookup_exercises.rb k12phys exercises.xlsx
```

#### convert_spreadsheet.rb

From the tagging folder, run the following command to convert a CC spreadsheet to the ideal format:

```sh
bundle exec cc/convert_spreadsheet.rb input_spreadsheet output_spreadsheet cnx_archive_url
```

Or to convert a HS spreadsheet to the ideal format, also from the tagging folder:

```sh
bundle exec hs/convert_spreadsheet.rb input_spreadsheet output_spreadsheet cnx_archive_url
```

`cnx_archive_url` is optional. Specifying it will allow the script to get module ID's from CNX.
It can be obtained by adding `archive` to the beginning of a cnx url.

Example:

```sh
bundle exec cc/convert_spreadsheet.rb input.xlsx output.xlsx http://archive.cnx.org/contents/031da8d3-b525-429c-80cf-6c8ed997733a@9.4
```

#### map_exercises.rb

From the tagging folder, run the following command to map exercises
in an HS book to the corresponding Col book:

```sh
bundle exec hs/map_exercises.rb hs_book_name input_spreadsheet output_spreadsheet [exercises_base_url]
```

The input spreadsheet must contain a mapping of LO's and/or module chapter.section, with the
entry for the origin book in the first column and the entry for the destination book
in the second column.

The output spreadsheet contains a list of exercise numbers in the first column and a list of tags
that will be associated with those exercises in the other columns.

Example:

```sh
bundle exec hs/map_exercises.rb k12phys physmap.xlsx phystags.xlsx https://exercises.openstax.org
```

#### copy_exercises.rb

From the tagging folder, run the following command
to copy exercises to a derived copy of the same book:

```sh
bundle exec cc/copy_exercises.rb orig_book_name dest_book_name output_spreadsheet [exercises_base_url]
```

The output spreadsheet contains a list of exercise numbers in the first column and a cnxmod tag
that will be associated with those exercises in the second column.

Example:

```sh
bundle exec cc/copy_exercises.rb phys phys-courseware phystags.xlsx https://exercises.openstax.org
```
