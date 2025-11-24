#!/usr/bin/env ruby
# Feature-Based Xcode Project Reorganizer - Fixed
require 'xcodeproj'
require 'set'

puts "🚀 Feature-Based Xcode Project Reorganization (Fixed)"
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

# Helper to create groups (path should NOT include group name)
def create_group(parent, name, path)
  group = parent.new_group(name, path)
  puts "  ✓ #{name}"
  group
end

# Helper to add files from a directory (non-recursive, flat)
def add_files_flat(group, dir, target)
  return 0 unless Dir.exist?(dir)

  count = 0

  Dir.entries(dir).sort.each do |item|
    next if item.start_with?('.')

    path = File.join(dir, item)
    next if File.directory?(path)
    next unless item =~ /\.(swift|h|m|mm|metal)$/

    # Skip if already added
    abs_path = File.absolute_path(path)
    next if $added_files.include?(abs_path)

    file_ref = group.new_reference(path)
    target.add_file_references([file_ref])
    $added_files.add(abs_path)
    count += 1

    print "." if count % 20 == 0
  end

  count
end

# Helper to add subdirectories as groups
def add_subdirs_as_groups(parent_group, dir, target)
  return 0 unless Dir.exist?(dir)

  count = 0

  Dir.entries(dir).sort.each do |item|
    next if item.start_with?('.')

    path = File.join(dir, item)
    next unless File.directory?(path)

    # Create group for this subdirectory
    subgroup = parent_group.new_group(item, path)

    # Add files from this subdirectory
    count += add_files_flat(subgroup, path, target)

    # Check for nested subdirectories
    Dir.entries(path).each do |subitem|
      next if subitem.start_with?('.')
      subpath = File.join(path, subitem)
      if File.directory?(subpath)
        # Create nested group
        nested_group = subgroup.new_group(subitem, subpath)
        count += add_files_flat(nested_group, subpath, target)
      end
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

# Core
total += add_subdirs_as_groups(core, "#{SOURCE_DIR}/Core", target)

# Features (each feature as a group)
total += add_subdirs_as_groups(features, "#{SOURCE_DIR}/Features", target)

# Shared
total += add_subdirs_as_groups(shared, "#{SOURCE_DIR}/Shared", target)

# CoT
total += add_files_flat(cot, "#{SOURCE_DIR}/CoT", target)
total += add_subdirs_as_groups(cot, "#{SOURCE_DIR}/CoT", target)

# Storage
total += add_files_flat(storage, "#{SOURCE_DIR}/Storage", target)

# Utilities
total += add_subdirs_as_groups(utilities, "#{SOURCE_DIR}/Utilities", target)

# Resources
if Dir.exist?("#{SOURCE_DIR}/Resources")
  total += add_files_flat(resources, "#{SOURCE_DIR}/Resources", target)

  Dir.entries("#{SOURCE_DIR}/Resources").each do |item|
    next if item.start_with?('.')
    path = File.join("#{SOURCE_DIR}/Resources", item)
    if File.directory?(path)
      subgroup = resources.new_group(item, path)
      total += add_files_flat(subgroup, path, target)
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
