#!/usr/bin/env ruby
require 'xcodeproj'

puts "🔧 Adding XCFramework to project..."

project = Xcodeproj::Project.open('OmniTAKMobile.xcodeproj')
target = project.targets.first

# Find or create Frameworks group
frameworks_group = project.main_group['Frameworks']
if frameworks_group.nil?
  frameworks_group = project.main_group.new_group('Frameworks')
end

# Add XCFramework
xcframework_path = 'OmniTAKMobile.xcframework'
if File.exist?(xcframework_path)
  puts "  ✓ Found #{xcframework_path}"

  # Add file reference
  xcframework_ref = frameworks_group.new_file(xcframework_path)

  # Add to frameworks build phase
  target.frameworks_build_phase.add_file_reference(xcframework_ref)

  puts "  ✓ Added XCFramework to project"

  project.save
  puts "\n✅ Done!"
else
  puts "  ❌ XCFramework not found at #{xcframework_path}"
end
