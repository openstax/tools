# OpenStax Tools

Generic tools and scripts for OpenStax-related tasks

## Tagging

### convert.rb

This executable ruby script can convert one of our spreadsheets to the "ideal" format.

First download it to your computer run these commands to set it up
(assumes you have ruby and rubygems already installed):

```sh
gem install rubyXL
gem install axlsx
gem install httparty
chmod +x convert.rb
```

Then run the following command to convert the spreadsheet:

```sh
./convert.rb input_spreadsheet output_spreadsheet cnx_archive_url
```

`cnx_archive_url` is optional. Specifying it will allow the script to get module ID's from CNX.
It can be obtained by adding `archive` at the beginning of a cnx url.

Example:

```sh
./convert.rb input.xlsx output.xlsx http://archive.cnx.org/contents/031da8d3-b525-429c-80cf-6c8ed997733a@9.4
```
