require_relative '../lib/foreman_google/google_compute_adapter'

path = ARGV[0]
zone = ARGV[1]

if path.nil? || zone.nil?
  puts 'Missing argument path or zone'
  puts "Run script like this: bundle exec ruby scripts/cleanup_cloud.rb 'path/to/json' 'zone_name'"
  exit 1
end

client = ForemanGoogle::GoogleComputeAdapter.new auth_json_string: File.read(path)

instances = client.instances(zone)

puts 'Found instances:'
puts 'Nothing found' if instances.empty?

instances.each do |instance|
  puts ">>> Deleting #{instance.name} instance"
  client.delete_instance(zone, instance.name)
end

disks = client.disks(zone)

puts ''
puts 'Found disks:'
puts 'Nothing found' if disks.empty?

disks.each do |disk|
  puts ">>> Deleting #{disk.name} disk"
  client.delete_disk(zone, disk.name)
end

puts ''
puts 'Done.'
