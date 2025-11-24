#!/usr/bin/env ruby
require 'fileutils'
require 'xcodeproj'

puts "🔧 Reorganizing Xcode project..."

# Check if xcodeproj gem is installed
begin
  require 'xcodeproj'
rescue LoadError
  puts "❌ xcodeproj gem not found. Installing..."
  system("gem install xcodeproj")
  require 'xcodeproj'
end

project_path = 'OmniTAKMobile.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first
puts "📱 Target: #{target.name}"

# Create main group structure
main_group = project.main_group

# Clear existing file references (but keep frameworks, products, etc.)
main_group.clear

# Create group hierarchy
groups = {
  'Core' => main_group.new_group('Core', 'OmniTAKMobile/Core'),
  'Services' => main_group.new_group('Services', 'OmniTAKMobile/Services'),
  'Managers' => main_group.new_group('Managers', 'OmniTAKMobile/Managers'),
  'Views' => main_group.new_group('Views', 'OmniTAKMobile/Views'),
  'Models' => main_group.new_group('Models', 'OmniTAKMobile/Models'),
  'Map' => main_group.new_group('Map', 'OmniTAKMobile/Map'),
  'CoT' => main_group.new_group('CoT', 'OmniTAKMobile/CoT'),
  'Utilities' => main_group.new_group('Utilities', 'OmniTAKMobile/Utilities'),
  'UI' => main_group.new_group('UI', 'OmniTAKMobile/UI'),
  'Resources' => main_group.new_group('Resources', 'OmniTAKMobile/Resources')
}

# Create Map subgroups
groups['Map/Controllers'] = groups['Map'].new_group('Controllers', 'OmniTAKMobile/Map/Controllers')
groups['Map/Markers'] = groups['Map'].new_group('Markers', 'OmniTAKMobile/Map/Markers')
groups['Map/Overlays'] = groups['Map'].new_group('Overlays', 'OmniTAKMobile/Map/Overlays')
groups['Map/TileSources'] = groups['Map'].new_group('TileSources', 'OmniTAKMobile/Map/TileSources')

# Create CoT subgroups
groups['CoT/Generators'] = groups['CoT'].new_group('Generators', 'OmniTAKMobile/CoT/Generators')
groups['CoT/Parsers'] = groups['CoT'].new_group('Parsers', 'OmniTAKMobile/CoT/Parsers')

# Create Utilities subgroups
groups['Utilities/Converters'] = groups['Utilities'].new_group('Converters', 'OmniTAKMobile/Utilities/Converters')
groups['Utilities/Parsers'] = groups['Utilities'].new_group('Parsers', 'OmniTAKMobile/Utilities/Parsers')
groups['Utilities/Integration'] = groups['Utilities'].new_group('Integration', 'OmniTAKMobile/Utilities/Integration')

# Create UI subgroups
groups['UI/Components'] = groups['UI'].new_group('Components', 'OmniTAKMobile/UI/Components')

# Add files recursively
def add_files_to_group(group, directory, target)
  return unless Dir.exist?(directory)
  
  Dir.foreach(directory) do |item|
    next if item == '.' || item == '..'
    
    path = File.join(directory, item)
    
    if File.directory?(path)
      # Skip creating subgroups, we handle them explicitly
      next
    elsif item.end_with?('.swift')
      file_ref = group.new_reference(path)
      target.add_file_references([file_ref])
      puts "  ✓ Added #{item} to #{group.name}"
    end
  end
end

# Add files to appropriate groups
puts "\n📁 Adding files to groups..."

groups.each do |path, group|
  dir_path = "OmniTAKMobile/#{path}"
  add_files_to_group(group, dir_path, target) if Dir.exist?(dir_path)
end

# Save project
puts "\n💾 Saving project..."
project.save

puts "✅ Done! Project reorganized successfully!"
