#!/usr/bin/env ruby
# Simpler approach - no paths on groups
require 'xcodeproj'
require 'set'

puts "🚀 Simple Feature Reorganization"
puts "=" * 60

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'
SOURCE_DIR = 'OmniTAKMobile'

$added = Set.new

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.first

puts "✅ Target: #{target.name}"
puts "\n🧹 Clearing..."

target.source_build_phase.clear
main_group = project.main_group
main_group.clear

# Recursively add directories - DON'T set paths on groups!
def add_dir(parent, dir, target)
  return 0 unless Dir.exist?(dir)

  count = 0
  name = File.basename(dir)

  # Create group WITHOUT path parameter
  group = parent.new_group(name)

  Dir.entries(dir).sort.each do |item|
    next if item.start_with?('.')
    full = File.join(dir, item)

    if File.directory?(full)
      count += add_dir(group, full, target)
    elsif item =~ /\.(swift|h|m|mm|metal)$/
      abs = File.absolute_path(full)
      next if $added.include?(abs)

      # Use ABSOLUTE path
      ref = group.new_file(abs)
      target.add_file_references([ref])
      $added.add(abs)
      count += 1
      print "." if count % 20 == 0
    end
  end

  count
end

puts "\n📁 Adding files..."
total = 0

['Core', 'Features', 'Shared', 'CoT', 'Storage', 'Utilities', 'Resources'].each do |d|
  path = File.join(SOURCE_DIR, d)
  total += add_dir(main_group, path, target) if Dir.exist?(path)
end

# Assets
assets_path = File.join(SOURCE_DIR, 'Assets.xcassets')
if File.exist?(assets_path)
  assets = main_group.new_reference(File.absolute_path(assets_path))
  target.resources_build_phase.add_file_reference(assets)
end

puts "\n\n✅ #{total} files"
puts "\n💾 Saving..."
project.save

puts "\n✨ Done!"
