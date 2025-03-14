require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

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

  puts "Extracting and cleaning contacts..."

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

  Dir.mkdir('data') unless Dir.exists?('data')

  CSV.open('data/contacts.csv', 'w', write_headers: true, headers: ["ID", "Raw Phone Number", "Cleaned Phone Number", "Validity"]) do |csv|
    contacts.each do |contact|
      csv<< [contact[:id], contact[:raw], contact[:clean], contact[:validity]]
    end
  end

  puts "Contacts file created"

end

def write_time_most_registered(times_registered)

  hour_counts = times_registered.tally
  max_count = hour_counts.values.max
  most_frequent_hours = hour_counts.select { |hour, count| count == max_count }

  puts "Max number of registrants in a given time: #{max_count} registrants"
  puts "They registered at hour(s): #{most_frequent_hours.keys.join(" and ")}"

  #put it in data folder create a new file
  Dir.mkdir('data') unless Dir.exists?('data')
  File.open('data/most_frequent_hours.txt', 'w') do |file|
    file.puts "Max number of registrants in a given time: #{max_count} times"
    file.puts "They registered at hour(s): #{most_frequent_hours.keys.join(" and ")}"
  end
end

def write_days_most_registered(days_registered)

  days_wday = days_registered.map do |day| 
    DAYS[day]  
  end

  days_counts = days_wday.tally

  max_counts = days_counts.values.max
  most_frequent_days = days_counts.select { |day, count| count == max_counts}

  puts "Max number of registrants in a given day: #{max_counts} registrants"
  puts "They registered on #{most_frequent_days.keys.join(" and ")}"

  Dir.mkdir('data') unless Dir.exists?('data')
  File.open('data/most_frequent_weekdays.txt', 'w') do |file|
    file.puts "Max number of registrants in a given day: #{max_counts} registrants"
    file.puts "They registered on #{most_frequent_days.keys.join(" and ")}"
  end
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
times_registered = []
days_registered = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = row[:homephone]
  date_registered = row[:regdate]

  zipcode = clean_zipcode(row[:zipcode])
  
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  contacts << extract_contacts(id, phone_number)

  puts "Extracting dates..."
  formatted_date = DateTime.strptime(date_registered ,"%m/%d/%Y %H:%M")
  times_registered << formatted_date.hour.to_i 
  days_registered << formatted_date.wday
end
 
write_contacts_to_file(contacts)

write_time_most_registered(times_registered)

write_days_most_registered(days_registered)

