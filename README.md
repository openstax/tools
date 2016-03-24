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
that will be associated with those exercises in the second column.

Example:

```sh
bundle exec hs/map_exercises.rb k12phys map.xlsx tags.xlsx https://exercises.openstax.org
```
