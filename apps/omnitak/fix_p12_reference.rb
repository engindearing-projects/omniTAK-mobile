#!/usr/bin/env ruby
# Fix missing p12 reference
require 'xcodeproj'

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'

puts "🔧 Fixing p12 file reference..."
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find and remove the missing p12 reference
project.files.each do |file|
  if file.path && file.path.include?('omnitak-mobile.p12')
    puts "  ⚠️  Found reference to: #{file.path}"

    # Remove from build phases
    project.targets.each do |target|
      target.resources_build_phase.files.each do |build_file|
        if build_file.file_ref == file
          puts "  🗑️  Removing from resources build phase"
          target.resources_build_phase.files.delete(build_file)
        end
      end
    end

    # Remove the file reference
    puts "  🗑️  Removing file reference"
    file.remove_from_project
  end
end

# Check if iphone-tak-cert.p12 exists and add it
if File.exist?('iphone-tak-cert.p12')
  puts "  ✅ Found iphone-tak-cert.p12, adding to project..."

  # Find or create Resources group
  resources_group = project.main_group['Resources']
  if resources_group.nil?
    resources_group = project.main_group.new_group('Resources', 'OmniTAKMobile/Resources')
  end

  # Add the file
  file_ref = resources_group.new_reference('iphone-tak-cert.p12')
  project.targets.first.resources_build_phase.add_file_reference(file_ref)
  puts "  ✅ Added iphone-tak-cert.p12 to project"
end

# Also remove duplicate Assets.xcassets warning
puts "\n🔧 Fixing duplicate Assets.xcassets..."
assets_refs = []
project.files.each do |file|
  if file.path && file.path.include?('Assets.xcassets')
    assets_refs << file
  end
end

if assets_refs.count > 1
  puts "  ⚠️  Found #{assets_refs.count} Assets.xcassets references"
  # Keep only the first one in resources build phase
  kept = false
  project.targets.each do |target|
    to_remove = []
    target.resources_build_phase.files.each do |build_file|
      if build_file.file_ref && build_file.file_ref.path && build_file.file_ref.path.include?('Assets.xcassets')
        if kept
          to_remove << build_file
        else
          kept = true
        end
      end
    end
    to_remove.each do |bf|
      puts "  🗑️  Removing duplicate Assets.xcassets from resources"
      target.resources_build_phase.files.delete(bf)
    end
  end
end

project.save
puts "\n✅ Project fixed!"
