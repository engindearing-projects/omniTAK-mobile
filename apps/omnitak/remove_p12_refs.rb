#!/usr/bin/env ruby
# Remove all p12 file references from project
require 'xcodeproj'

PROJECT_PATH = 'OmniTAKMobile.xcodeproj'

puts "🔧 Removing all p12 file references from project..."
project = Xcodeproj::Project.open(PROJECT_PATH)

removed_count = 0

# Find and remove all p12 references
project.files.to_a.each do |file|
  if file.path && file.path.end_with?('.p12')
    puts "  🗑️  Removing: #{file.path}"

    # Remove from all build phases
    project.targets.each do |target|
      # Resources
      target.resources_build_phase.files.to_a.each do |build_file|
        if build_file.file_ref == file
          target.resources_build_phase.files.delete(build_file)
        end
      end

      # Source files (just in case)
      target.source_build_phase.files.to_a.each do |build_file|
        if build_file.file_ref == file
          target.source_build_phase.files.delete(build_file)
        end
      end
    end

    # Remove the file reference
    file.remove_from_project
    removed_count += 1
  end
end

if removed_count > 0
  project.save
  puts "\n✅ Removed #{removed_count} p12 file reference(s) from project!"
else
  puts "\n✅ No p12 files found in project"
end
