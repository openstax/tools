# Organizes a CNX book hash by chapter and section numbers
# Writes the result into the given cnx_book_hash
def map_collection(hash, cnx_book_hash, chapter_number = 0)
  contents = hash['contents']
  chapter_number += 1 if contents.none?{ |entry| entry['id'] == 'subcol' }

  section_number = nil
  contents.each do |entry|
    if entry['id'] == 'subcol'
      chapter_number = map_collection(entry, cnx_book_hash, chapter_number)
    else
      section_number ||= entry['title'].start_with?('Introduction') ? 0 : 1
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
