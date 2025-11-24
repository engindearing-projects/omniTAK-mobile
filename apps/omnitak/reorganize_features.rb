#!/usr/bin/env ruby
# Feature-Based Xcode Project Reorganizer
require 'xcodeproj'
require 'set'

puts "🚀 Feature-Based Xcode Project Reorganization"
puts "=" * 60

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'
SOURCE_DIR = 'OmniTAKMobile'

# Track added files to avoid duplicates
$added_files = Set.new

# Open project
puts "\n📂 Opening project..."
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.first

puts "✅ Target: #{target.name}"

# Clear existing groups and files from compile sources
puts "\n🧹 Clearing old file references..."
target.source_build_phase.clear
main_group = project.main_group
main_group.clear

# Helper to create groups
def create_group(parent, name, path = nil)
  group = parent.new_group(name, path)
  puts "  ✓ #{name}"
  group
end

# Helper to add files recursively
def add_files_recursively(group, dir, target)
  return 0 unless Dir.exist?(dir)

  count = 0

  Dir.entries(dir).sort.each do |item|
    next if item.start_with?('.')

    path = File.join(dir, item)

    if File.directory?(path)
      # Create subgroup and recurse
      subgroup = group.new_group(item, path)
      count += add_files_recursively(subgroup, path, target)
    elsif item =~ /\.(swift|h|m|mm|metal)$/
      # Skip if already added
      abs_path = File.absolute_path(path)
      next if $added_files.include?(abs_path)

      file_ref = group.new_reference(path)
      target.add_file_references([file_ref])
      $added_files.add(abs_path)
      count += 1

      print "." if count % 20 == 0
    end
  end

  count
end

# Create main groups
puts "\n📁 Creating group structure..."

# Core
core = create_group(main_group, 'Core', "#{SOURCE_DIR}/Core")

# Features (organized by domain)
features = create_group(main_group, 'Features', "#{SOURCE_DIR}/Features")

# Shared components
shared = create_group(main_group, 'Shared', "#{SOURCE_DIR}/Shared")

# CoT
cot = create_group(main_group, 'CoT', "#{SOURCE_DIR}/CoT")

# Storage
storage = create_group(main_group, 'Storage', "#{SOURCE_DIR}/Storage")

# Utilities
utilities = create_group(main_group, 'Utilities', "#{SOURCE_DIR}/Utilities")

# Resources
resources = create_group(main_group, 'Resources', "#{SOURCE_DIR}/Resources")

# Assets
assets = main_group.new_reference("#{SOURCE_DIR}/Assets.xcassets")

# Info.plist
info_plist = main_group.new_reference("#{SOURCE_DIR}/Info.plist") if File.exist?("#{SOURCE_DIR}/Info.plist")

# Add files
puts "\n📄 Adding files..."

total = 0
total += add_files_recursively(core, "#{SOURCE_DIR}/Core", target)
total += add_files_recursively(features, "#{SOURCE_DIR}/Features", target)
total += add_files_recursively(shared, "#{SOURCE_DIR}/Shared", target)
total += add_files_recursively(cot, "#{SOURCE_DIR}/CoT", target)
total += add_files_recursively(storage, "#{SOURCE_DIR}/Storage", target)
total += add_files_recursively(utilities, "#{SOURCE_DIR}/Utilities", target)

# Add resources if exist
if Dir.exist?("#{SOURCE_DIR}/Resources")
  Dir.entries("#{SOURCE_DIR}/Resources").each do |item|
    next if item.start_with?('.')
    path = File.join("#{SOURCE_DIR}/Resources", item)
    next if File.directory?(path) && item == "Documentation"

    if File.directory?(path)
      subgroup = resources.new_group(item, path)
      add_files_recursively(subgroup, path, target)
    elsif item =~ /\.(swift|h|m|mm|metal)$/
      abs_path = File.absolute_path(path)
      next if $added_files.include?(abs_path)

      file_ref = resources.new_reference(path)
      target.add_file_references([file_ref])
      $added_files.add(abs_path)
      total += 1
    end
  end
end

puts "\n\n✅ Added #{total} source files"

# Add resources to build phases
puts "\n📦 Adding resources to build phases..."
target.resources_build_phase.add_file_reference(assets) if assets

# Save project
puts "\n💾 Saving project..."
project.save

puts "\n✨ Reorganization complete!"
puts "=" * 60
puts "\n📊 Summary:"
puts "  • #{total} source files organized"
puts "  • Feature-based structure created"
puts "  • Groups: Core, Features, Shared, CoT, Storage, Utilities, Resources"
puts "\n🔨 Next: Build the project to verify everything works!"
