# Organizes a CNX book hash by chapter and section numbers
# Writes the result into the given cnx_book_hash
def map_collection(hash, cnx_book_hash, chapter_number = 0)
  contents = hash['contents']

  if contents.any?{ |entry| entry['id'] == 'subcol' } # Book/Unit (internal node)
    contents.each do |entry|
      next if entry['id'] != 'subcol' # Skip anything not in a chapter (preface/appendix)

      chapter_number = map_collection(entry, cnx_book_hash, chapter_number)
    end
  else # Chapter (leaf)
    chapter_number += 1
    if contents.empty?
      puts "WARNING: Chapter #{chapter_number} is empty!"
      return chapter_number
    end

    section_number = contents.first['title'].start_with?('Introduction') ? 0 : 1

    contents.each do |entry|
      cnx_book_hash[chapter_number][section_number] = entry
      section_number += 1
    end
  end

  return chapter_number
end

# Returns the CNX uuid for a given section hash
def extract_uuid(section_hash)
  section_hash['id'].split('@').first
end
