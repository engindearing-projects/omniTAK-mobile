#!/usr/bin/env ruby
# Clean Xcode Project Reorganizer for Feature Structure
require 'xcodeproj'
require 'set'
require 'pathname'

puts "🚀 Clean Feature-Based Xcode Project Reorganization"
puts "=" * 60

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'
SOURCE_DIR = 'OmniTAKMobile'

# Track added files
$added_files = Set.new

# Open project
puts "\n📂 Opening project..."
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.first

puts "✅ Target: #{target.name}"

# Clear build phase
puts "\n🧹 Clearing old file references..."
target.source_build_phase.clear

# Clear main group
main_group = project.main_group
main_group.clear

# Helper function to recursively add directory as groups
def add_directory_recursive(parent_group, dir_path, target, source_dir)
  return 0 unless Dir.exist?(dir_path)

  count = 0
  dir_name = File.basename(dir_path)

  # Get relative path from source directory
  rel_path = Pathname.new(dir_path).relative_path_from(Pathname.new(File.dirname(source_dir))).to_s

  # Create group for this directory
  group = parent_group.new_group(dir_name, rel_path)

  # Process entries in this directory
  Dir.entries(dir_path).sort.each do |entry|
    next if entry.start_with?('.')

    full_path = File.join(dir_path, entry)

    if File.directory?(full_path)
      # Recursively add subdirectory
      count += add_directory_recursive(group, full_path, target, source_dir)
    elsif entry =~ /\.(swift|h|m|mm|metal)$/
      # Add source file
      abs_path = File.absolute_path(full_path)
      next if $added_files.include?(abs_path)

      file_ref = group.new_file(full_path)
      target.add_file_references([file_ref])
      $added_files.add(abs_path)
      count += 1

      print "." if count % 20 == 0
    end
  end

  count
end

# Create top-level structure
puts "\n📁 Creating group structure and adding files..."

total = 0

# Add each top-level directory
['Core', 'Features', 'Shared', 'CoT', 'Storage', 'Utilities', 'Resources'].each do |dir|
  dir_path = File.join(SOURCE_DIR, dir)
  if Dir.exist?(dir_path)
    puts "\n  📂 Processing #{dir}..."
    total += add_directory_recursive(main_group, dir_path, target, SOURCE_DIR)
  end
end

# Add Assets
assets_path = File.join(SOURCE_DIR, 'Assets.xcassets')
if File.exist?(assets_path)
  puts "\n  📦 Adding Assets.xcassets..."
  assets_ref = main_group.new_reference(assets_path)
  target.resources_build_phase.add_file_reference(assets_ref)
end

# Add Info.plist if exists
info_plist_path = File.join(SOURCE_DIR, 'Info.plist')
if File.exist?(info_plist_path)
  info_ref = main_group.new_reference(info_plist_path)
end

puts "\n\n✅ Added #{total} source files"

# Save
puts "\n💾 Saving project..."
project.save

puts "\n✨ Reorganization complete!"
puts "=" * 60
puts "\n📊 Summary:"
puts "  • #{total} source files"
puts "  • Feature-based folder structure"
puts "\n🔨 Ready to build!"
