require 'yaml'
require 'freshbooks'

config = YAML::load_file(File.join(__dir__, 'config.yml'))
freshbooks_subdomain = config['freshbooks_subdomain']
freshbooks_auth_token = config['freshbooks_auth_token']

FreshBooks::Base.establish_connection(freshbooks_subdomain, freshbooks_auth_token)

time_entries = FreshBooks::TimeEntry.list
time_entries.each {|t|
  puts "Deleting #{t.time_entry_id} on #{t.date} (#{t.hours})"
  t.delete
}
