# This script uses eval on the given string
# Do not use it with strings from untrusted sources
# Usage:
# err = <<-ERR
# (paste full rspec error string here, starting on "expected")
# ERR
# require 'diff'
# o1, o2, r1, r2 = diff(err)
#
# o1 and o2 will contain the objects being compared, extracted from the string
# r1 will contain which elements are in o2 but not in o1
# r2 (if present) will contain which elements are in o1 but not in o2
# r2 is omitted if using expect().to include()

require 'rails'
require 'rspec'

METHOD_PATTERN = / to (\w+) /
SYMBOL_HASHROCKET_PATTERN = /:(\w+)\s*=>\s*/
STRING_HASHROCKET_PATTERN = /:?("[^"]+")\s*=>\s*/
HASH_PATTERN = /\(a hash including ([^()]+)\)/
COLLECTION_INCLUDING_PATTERN = /\(a collection including ([^()]+)\)/
COLLECTION_EXACTLY_PATTERN = /\(a collection containing exactly ([^()]+)\)/
ASSOCIATION_PATTERN = /#<ActiveRecord::(?:Association)?Relation \[([^\[\]]+)\]>/
OBJECT_PATTERN = /#<([^\s:]+(?:::[^\s:]+)*)(?::0x[0-9a-f]+)? ([^<>]+)>/
VARIABLE_STRING_PATTERN = /@\w+=("[^"]+")/
VARIABLE_OTHER_PATTERN = /@\w+=([^\s]+)/
SPLIT_PATTERN = / to \w+ /

class Match
end

def incl(o1, o2)
  oo1 = case o1
  when RSpec::Matchers::BuiltIn::Include, RSpec::Matchers::BuiltIn::ContainExactly
    expected = o1.expected
    expected.is_a?(Array) && expected.one? && Hash === expected.first ? expected.first : expected
  else
    o1
  end

  oo2 = case o2
  when RSpec::Matchers::BuiltIn::Include, RSpec::Matchers::BuiltIn::ContainExactly
    expected = o2.expected
    expected.is_a?(Array) && expected.one? && Hash === expected.first ? expected.first : expected
  else
    o2
  end

  match = if o1.is_a?(RSpec::Matchers::BuiltIn::BaseMatcher)
    o1.matches?(o2)
  elsif o2.is_a?(RSpec::Matchers::BuiltIn::BaseMatcher)
    o2.matches?(o1)
  elsif o1.is_a?(RSpec::Mocks::ArgumentMatchers::KindOf)
    o1 === o2
  elsif o2.is_a?(RSpec::Mocks::ArgumentMatchers::KindOf)
    o2 === o1
  else
    o1 == o2
  end

  return Match if match

  if oo1.is_a?(Hash) && oo2.is_a?(Hash)
    {}.tap do |hh|
      oo2.each do |key, value|
        result = incl(oo1[key], value)

        hh[key] = result unless Match.equal?(result)
      end
    end.tap { |hh| return Match if hh.empty? }
  elsif oo1.is_a?(Array) && oo2.is_a?(Array)
    match_any = o1.is_a?(RSpec::Matchers::BuiltIn::Include) ||
                o1.is_a?(RSpec::Matchers::BuiltIn::ContainExactly) ||
                o2.is_a?(RSpec::Matchers::BuiltIn::Include) ||
                o2.is_a?(RSpec::Matchers::BuiltIn::ContainExactly)

    oo2.each_with_index.map do |value, ii|
      if match_any
        oo1.any? { |oo1v| Match.equal?(incl(oo1v, value)) } ? Match : value
      else
        incl(oo1[ii], value)
      end
    end.reject { |oo2v| Match.equal?(oo2v) }.tap { |aa| return Match if aa.empty? }
  else
    o2
  end
end

def diff(str)
  str = str.split('Diff:').first

  method = METHOD_PATTERN.match(str)[1]

  str = str.sub(/\s*expected\s+/, '').gsub('[secure]', '"[secure]"')

  while !SYMBOL_HASHROCKET_PATTERN.match(str).nil? || !STRING_HASHROCKET_PATTERN.match(str).nil? do
    str.gsub!(SYMBOL_HASHROCKET_PATTERN, '\1: ')
    str.gsub!(STRING_HASHROCKET_PATTERN, '\1: ')
  end

  while !HASH_PATTERN.match(str).nil? ||
        !COLLECTION_INCLUDING_PATTERN.match(str).nil? ||
        !COLLECTION_EXACTLY_PATTERN.match(str).nil? do
    str.gsub!(HASH_PATTERN, '#<RSpec::Matchers::BuiltIn::Include \1>')
    str.gsub!(COLLECTION_INCLUDING_PATTERN, '#<RSpec::Matchers::BuiltIn::Include \1>')
    str.gsub!(COLLECTION_EXACTLY_PATTERN, '#<RSpec::Matchers::BuiltIn::ContainExactly \1>')
  end

  str.gsub!(' and ', ', ')

  while !OBJECT_PATTERN.match(str).nil? do
    str.gsub!(ASSOCIATION_PATTERN, '[\1]')
    str.gsub!(OBJECT_PATTERN, '\1.new(\2)')
    str.gsub!(VARIABLE_STRING_PATTERN, '\1')
    str.gsub!(VARIABLE_OTHER_PATTERN, '\1')
  end

  o1, o2 = str.split(SPLIT_PATTERN).map { |str| eval str }

  r1 = incl(o1, o2)
  puts "+ #{r1.inspect}"

  r2 = nil
  if method != 'include'
    r2 = incl(o2, o1)
    puts "- #{r2.inspect}"
  end

  [ o1, o2, r1, r2 ]
end
