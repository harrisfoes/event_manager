require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

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

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = row[:homephone]

  zipcode = clean_zipcode(row[:zipcode])
  
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  #save_thank_you_letter(id, form_letter)

  clean_number = phone_number.gsub(/\D/, '')
  valid_number = false
  p clean_number.length
  p clean_number[0]
  if clean_number.length == 10
    valid_number = true
  elsif clean_number.length == 11 and clean_number[0].to_i == 1
    p "log, this number was cleaned up #{clean_number}"
    clean_number = clean_number[1..]
    valid_number = true
  end 
  p "#{clean_number} is #{valid_number ? "valid" : "invalid" }"
  #if the phone number is less than 10 digits, assume that it is a bad number
  #if the phone number is 10 digits, assume that it is good
  #if the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10
  #if the number is 11 digits and the first number is not 1 then it is a bad number
  #if the phone is more than 11, assume that it is bad
end
 
