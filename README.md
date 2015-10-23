# OpenStax Tools

Generic tools and scripts for OpenStax-related tasks

## Tagging

### convert.rb

This executable ruby script can convert one of our spreadsheets to the "ideal" format.
Only the first worksheet in the input excel file is converted.

First download it to your computer run these commands to set it up
(assumes you have ruby and rubygems already installed):

```sh
chmod +x convert.rb
gem install bundler
bundle install
```

In case of errors, make sure you have Xcode and the Xcode command-line tools installed.

Then run the following command to convert the spreadsheet:

```sh
bundle exec ./convert.rb input_spreadsheet output_spreadsheet cnx_archive_url
```

`cnx_archive_url` is optional. Specifying it will allow the script to get module ID's from CNX.
It can be obtained by adding `archive` at the beginning of a cnx url.

Example:

```sh
bundle exec ./convert.rb input.xlsx output.xlsx http://archive.cnx.org/contents/031da8d3-b525-429c-80cf-6c8ed997733a@9.4
```
