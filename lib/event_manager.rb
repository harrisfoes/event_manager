require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,'0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip 

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials' 
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def extract_contacts(id, phone_number)

  clean_number = phone_number.gsub(/\D/, '')
  valid_number = false

  if clean_number.length == 10
    valid_number = true
  elsif clean_number.length == 11 and clean_number[0].to_i == 1
    clean_number = clean_number[1..]
    valid_number = true
  end 

  {id: id, raw: phone_number, clean: clean_number, validity: valid_number}
  
end

def write_contacts_to_file(contacts)

  puts "Writing contacts to file"

  Dir.mkdir('contacts') unless Dir.exists?('contacts')

  CSV.open('contacts/contacts.csv', 'w', write_headers: true, headers: ["ID", "Raw Phone Number", "Cleaned Phone Number", "Validity"]) do |csv|
    contacts.each do |contact|
      csv<< [contact[:id], contact[:raw], contact[:clean], contact[:validity]]
    end
  end

  puts "Contacts file created"

end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contacts = [] 
registered_time = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = row[:homephone]
  date_registered = row[:regdate]

  zipcode = clean_zipcode(row[:zipcode])
  
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  # save_thank_you_letter(id, form_letter)

  # contacts << extract_contacts(id, phone_number)

  #time average
  formatted_date = DateTime.strptime(date_registered ,"%m/%d/%Y %H:%M")
  registered_time << formatted_date.hour.to_i 

end
 
# write_contacts_to_file(contacts)

#time average
hour_counts = registered_time.tally
max_count = hour_counts.values.max
most_frequent_hours = hour_counts.select { |hour, count| count == max_count }
puts "Most frequent time of registration is: #{most_frequent_hours}"

