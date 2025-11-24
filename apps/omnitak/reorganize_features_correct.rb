#!/usr/bin/env ruby
# Correct Feature-Based Reorganization
require 'xcodeproj'
require 'set'

puts "🚀 Feature-Based Xcode Project Reorganization"
puts "=" * 60

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'
SOURCE_DIR = 'OmniTAKMobile'

$added_files = Set.new

# Open project
puts "\n📂 Opening project..."
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.first

puts "✅ Target: #{target.name}"

# Clear
puts "\n🧹 Clearing old structure..."
target.source_build_phase.clear
main_group = project.main_group
main_group.clear

# Helper to create group
def create_group(parent, name, path)
  group = parent.new_group(name, path)
  puts "  ✓ #{name}"
  group
end

# Helper to add files from directory
def add_files(group, dir, target)
  return 0 unless Dir.exist?(dir)

  count = 0
  Dir.entries(dir).sort.each do |item|
    next if item.start_with?('.')

    full_path = File.join(dir, item)
    next if File.directory?(full_path)
    next unless item =~ /\.(swift|h|m|mm|metal)$/

    abs_path = File.absolute_path(full_path)
    next if $added_files.include?(abs_path)

    # Key: use the actual file path, not group-relative
    file_ref = group.new_reference(full_path)
    target.add_file_references([file_ref])
    $added_files.add(abs_path)
    count += 1

    print "." if count % 20 == 0
  end

  count
end

# Helper to recursively process directories
def process_directory(parent_group, dir, target)
  return 0 unless Dir.exist?(dir)

  count = 0

  # First add files in this directory
  count += add_files(parent_group, dir, target)

  # Then process subdirectories
  Dir.entries(dir).sort.each do |item|
    next if item.start_with?('.')

    full_path = File.join(dir, item)
    next unless File.directory?(full_path)

    # Create subgroup
    subgroup = create_group(parent_group, item, full_path)

    # Recursively process
    count += process_directory(subgroup, full_path, target)
  end

  count
end

# Create structure
puts "\n📁 Creating groups and adding files..."

total = 0

# Core
if Dir.exist?("#{SOURCE_DIR}/Core")
  core = create_group(main_group, 'Core', "#{SOURCE_DIR}/Core")
  total += process_directory(core, "#{SOURCE_DIR}/Core", target)
end

# Features
if Dir.exist?("#{SOURCE_DIR}/Features")
  features = create_group(main_group, 'Features', "#{SOURCE_DIR}/Features")
  total += process_directory(features, "#{SOURCE_DIR}/Features", target)
end

# Shared
if Dir.exist?("#{SOURCE_DIR}/Shared")
  shared = create_group(main_group, 'Shared', "#{SOURCE_DIR}/Shared")
  total += process_directory(shared, "#{SOURCE_DIR}/Shared", target)
end

# CoT
if Dir.exist?("#{SOURCE_DIR}/CoT")
  cot = create_group(main_group, 'CoT', "#{SOURCE_DIR}/CoT")
  total += process_directory(cot, "#{SOURCE_DIR}/CoT", target)
end

# Storage
if Dir.exist?("#{SOURCE_DIR}/Storage")
  storage = create_group(main_group, 'Storage', "#{SOURCE_DIR}/Storage")
  total += process_directory(storage, "#{SOURCE_DIR}/Storage", target)
end

# Utilities
if Dir.exist?("#{SOURCE_DIR}/Utilities")
  utilities = create_group(main_group, 'Utilities', "#{SOURCE_DIR}/Utilities")
  total += process_directory(utilities, "#{SOURCE_DIR}/Utilities", target)
end

# Resources
if Dir.exist?("#{SOURCE_DIR}/Resources")
  resources = create_group(main_group, 'Resources', "#{SOURCE_DIR}/Resources")
  total += process_directory(resources, "#{SOURCE_DIR}/Resources", target)
end

# Assets
if File.exist?("#{SOURCE_DIR}/Assets.xcassets")
  assets = main_group.new_reference("#{SOURCE_DIR}/Assets.xcassets")
  target.resources_build_phase.add_file_reference(assets)
end

# Info.plist
if File.exist?("#{SOURCE_DIR}/Info.plist")
  main_group.new_reference("#{SOURCE_DIR}/Info.plist")
end

puts "\n\n✅ Added #{total} source files"

# Save
puts "\n💾 Saving project..."
project.save

puts "\n✨ Complete!"
puts "=" * 60
puts "\n📊 #{total} files organized"
puts "🔨 Ready to build!"
