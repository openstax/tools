# OpenStax Tools

Generic tools and scripts for OpenStax-related tasks

## CNX

### lookup_uuids.rb

This executable ruby script can lookup CNX module UUID's in a given CNX book archive url.

First clone the repo, navigate to the cnx folder
and run `bundle install` to install the required libraries:

```sh
git clone https://github.com/openstax/tools.git
cd tools/cnx
gem install bundler
bundle install
```

In case of errors, make sure you have Xcode and the Xcode command-line tools installed.

Then run the following command to lookup CNX module UUID's:

```sh
bundle exec lookup_uuids.rb cnx_book_archive_url output_spreadsheet
```

Example:

```sh
bundle exec ./lookup_uuids.rb http://archive.cnx.org/contents/031da8d3-b525-429c-80cf-6c8ed997733a@9.4 uuids.xlsx
```

## Tagging

### convert.rb

This executable ruby script can convert one of our spreadsheets to the "ideal" format.
Only the first worksheet in the input excel file is converted.

First clone the repo, navigate to the tagging folder
and run `bundle install` to install the required libraries:

```sh
git clone https://github.com/openstax/tools.git
cd tools/tagging
gem install bundler
bundle install
```

In case of errors, make sure you have Xcode and the Xcode command-line tools installed.

Then run the following command to convert a CC spreadsheet to the ideal format:

```sh
bundle exec cc/convert.rb input_spreadsheet output_spreadsheet cnx_archive_url
```

Or to convert a HS spreadsheet to the ideal format:

```sh
bundle exec hs/convert.rb input_spreadsheet output_spreadsheet cnx_archive_url
```

`cnx_archive_url` is optional. Specifying it will allow the script to get module ID's from CNX.
It can be obtained by adding `archive` at the beginning of a cnx url.

Example:

```sh
bundle exec cc/convert.rb input.xlsx output.xlsx http://archive.cnx.org/contents/031da8d3-b525-429c-80cf-6c8ed997733a@9.4
```
