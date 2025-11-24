#!/usr/bin/env ruby
# Remove p12 without loading/saving entire project
require 'fileutils'

puts "🧹 Cleaning derived data..."
system('rm -rf ~/Library/Developer/Xcode/DerivedData/OmniTAKMobile-*')

puts "🔧 Removing p12 references from project file..."
project_file = 'OmniTAKMobile.xcodeproj/project.pbxproj'
content = File.read(project_file)

# Remove lines containing p12 references
original_lines = content.lines.count
content = content.lines.reject { |line| line.include?('.p12') }.join

new_lines = content.lines.count
File.write(project_file, content)

puts "✅ Removed #{original_lines - new_lines} lines containing p12 references"
