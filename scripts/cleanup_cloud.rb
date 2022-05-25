require 'json'
require 'google-cloud-compute'

path = ARGV[0]
@zone = ARGV[1]

if path.nil? || @zone.nil?
  puts 'Missing argument path or zone'
  puts "Run script like this: bundle exec ruby scripts/cleanup_cloud.rb 'path/to/json' 'zone_name'"
  exit 1
end

@auth_json = JSON.parse(File.read(path))

def resource_client(resource_name)
  ::Google::Cloud::Compute.public_send(resource_name) do |config|
    config.credentials = @auth_json
  end
end

def list(resource_name)
  response = resource_client(resource_name).list(project: @auth_json['project_id'], zone: @zone).response
  response.items
rescue ::Google::Cloud::Error => e
  puts "ERROR: #{e}"
end

def delete(resource_name, **opts)
  resource_client(resource_name).delete(project: @auth_json['project_id'], zone: @zone, **opts)
rescue ::Google::Cloud::Error => e
  puts "ERROR: #{e}"
end

instances = list('instances')

puts 'Deleting instances:'
puts 'Nothing found' if instances.empty?

instances.each do |instance|
  puts ">>> Deleting #{instance.name} instance"
  delete('instances', instance: instance.name)
end

disks = list('disks')

puts ''
puts 'Deleting disks:'
puts 'Nothing found' if disks.empty?

disks.each do |disk|
  puts ">>> Deleting #{disk.name} disk"
  delete('disks', disk: disk.name)
end

puts ''
puts 'Done.'
