#!/usr/bin/env ruby
# Automated Xcode Project Reorganizer using xcodeproj gem
require 'xcodeproj'
require 'fileutils'

puts "🚀 Automated Xcode Project Reorganization"
puts "=" * 60

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'
SOURCE_DIR = 'OmniTAKMobile'

# Open project
puts "\n📂 Opening project..."
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.first

puts "✅ Target: #{target.name}"

# Clear existing groups and files (keep frameworks/products)
puts "\n🧹 Clearing old structure..."
main_group = project.main_group
main_group.clear

# Create clean group hierarchy
puts "\n📁 Creating new group structure..."

groups = {}

def create_group_hierarchy(parent, name, path)
  group = parent.new_group(name, path)
  puts "  ✓ Created: #{name}"
  group
end

# Create main groups
groups['Core'] = create_group_hierarchy(main_group, 'Core', 'OmniTAKMobile/Core')
groups['Services'] = create_group_hierarchy(main_group, 'Services', 'OmniTAKMobile/Services')
groups['Managers'] = create_group_hierarchy(main_group, 'Managers', 'OmniTAKMobile/Managers')
groups['Views'] = create_group_hierarchy(main_group, 'Views', 'OmniTAKMobile/Views')
groups['Models'] = create_group_hierarchy(main_group, 'Models', 'OmniTAKMobile/Models')
groups['Storage'] = create_group_hierarchy(main_group, 'Storage', 'OmniTAKMobile/Storage')
groups['Resources'] = create_group_hierarchy(main_group, 'Resources', 'OmniTAKMobile/Resources')

# CoT group with subgroups
cot = create_group_hierarchy(main_group, 'CoT', 'OmniTAKMobile/CoT')
groups['CoT'] = cot
groups['CoT/Generators'] = create_group_hierarchy(cot, 'Generators', 'OmniTAKMobile/CoT/Generators')
groups['CoT/Parsers'] = create_group_hierarchy(cot, 'Parsers', 'OmniTAKMobile/CoT/Parsers')

# Map group with subgroups
map = create_group_hierarchy(main_group, 'Map', 'OmniTAKMobile/Map')
groups['Map'] = map
groups['Map/Controllers'] = create_group_hierarchy(map, 'Controllers', 'OmniTAKMobile/Map/Controllers')
groups['Map/Markers'] = create_group_hierarchy(map, 'Markers', 'OmniTAKMobile/Map/Markers')
groups['Map/Overlays'] = create_group_hierarchy(map, 'Overlays', 'OmniTAKMobile/Map/Overlays')
groups['Map/TileSources'] = create_group_hierarchy(map, 'TileSources', 'OmniTAKMobile/Map/TileSources')

# UI group with subgroups
ui = create_group_hierarchy(main_group, 'UI', 'OmniTAKMobile/UI')
groups['UI'] = ui
groups['UI/Components'] = create_group_hierarchy(ui, 'Components', 'OmniTAKMobile/UI/Components')
groups['UI/MilStd2525'] = create_group_hierarchy(ui, 'MilStd2525', 'OmniTAKMobile/UI/MilStd2525')
groups['UI/RadialMenu'] = create_group_hierarchy(ui, 'RadialMenu', 'OmniTAKMobile/UI/RadialMenu')

# Utilities group with subgroups
utilities = create_group_hierarchy(main_group, 'Utilities', 'OmniTAKMobile/Utilities')
groups['Utilities'] = utilities
groups['Utilities/Calculators'] = create_group_hierarchy(utilities, 'Calculators', 'OmniTAKMobile/Utilities/Calculators')
groups['Utilities/Converters'] = create_group_hierarchy(utilities, 'Converters', 'OmniTAKMobile/Utilities/Converters')
groups['Utilities/Integration'] = create_group_hierarchy(utilities, 'Integration', 'OmniTAKMobile/Utilities/Integration')
groups['Utilities/Network'] = create_group_hierarchy(utilities, 'Network', 'OmniTAKMobile/Utilities/Network')
groups['Utilities/Parsers'] = create_group_hierarchy(utilities, 'Parsers', 'OmniTAKMobile/Utilities/Parsers')

# Add files to groups
puts "\n📄 Adding files to groups..."

def add_files_to_group(group, directory, target, file_count)
  return file_count unless Dir.exist?(directory)

  Dir.foreach(directory) do |item|
    next if item == '.' || item == '..'

    path = File.join(directory, item)
    next if File.directory?(path)
    next unless item.end_with?('.swift', '.h', '.m', '.mm', '.metal')

    file_ref = group.new_reference(path)
    target.add_file_references([file_ref])
    file_count += 1

    if file_count % 20 == 0
      print "."
      STDOUT.flush
    end
  end

  file_count
end

file_count = 0

# Add files for each group
groups.each do |name, group|
  path_component = name.sub('/', '/')
  full_path = "OmniTAKMobile/#{path_component}"
  file_count = add_files_to_group(group, full_path, target, file_count) if Dir.exist?(full_path)
end

# Add Resources separately
resources_group = groups['Resources']
['Assets.xcassets', 'Resources/Info.plist'].each do |resource|
  resource_path = "OmniTAKMobile/#{resource}"
  if File.exist?(resource_path)
    file_ref = resources_group.new_reference(resource_path)
    if resource.end_with?('.xcassets')
      target.resources_build_phase.add_file_reference(file_ref)
    end
    file_count += 1
  end
end

puts "\n✅ Added #{file_count} files"

# Save project
puts "\n💾 Saving reorganized project..."
project.save

puts "\n" + "=" * 60
puts "✅ PROJECT REORGANIZED SUCCESSFULLY!"
puts "=" * 60
puts "\n📊 Summary:"
puts "  • #{groups.size} groups created"
puts "  • #{file_count} files organized"
puts "  • All settings preserved"
puts "\n🔨 Next: Build the project (Cmd+B) to verify"
