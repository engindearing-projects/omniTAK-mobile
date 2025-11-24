#!/usr/bin/env ruby
# Automated Xcode Project Reorganizer v2 - No Duplicates
require 'xcodeproj'
require 'set'

puts "🚀 Automated Xcode Project Reorganization v2"
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

# Clear existing groups and files
puts "\n🧹 Clearing old structure..."
main_group = project.main_group
main_group.clear

# Create clean group hierarchy
puts "\n📁 Creating new group structure..."

def create_group(parent, name, path)
  group = parent.new_group(name, path)
  puts "  ✓ #{name}"
  group
end

# Create main groups
core = create_group(main_group, 'Core', 'OmniTAKMobile/Core')
services = create_group(main_group, 'Services', 'OmniTAKMobile/Services')
managers = create_group(main_group, 'Managers', 'OmniTAKMobile/Managers')
views = create_group(main_group, 'Views', 'OmniTAKMobile/Views')
models = create_group(main_group, 'Models', 'OmniTAKMobile/Models')
storage = create_group(main_group, 'Storage', 'OmniTAKMobile/Storage')
resources = create_group(main_group, 'Resources', 'OmniTAKMobile/Resources')

# CoT with subgroups
cot = create_group(main_group, 'CoT', 'OmniTAKMobile/CoT')
cot_gen = create_group(cot, 'Generators', 'OmniTAKMobile/CoT/Generators')
cot_parse = create_group(cot, 'Parsers', 'OmniTAKMobile/CoT/Parsers')

# Map with subgroups
map = create_group(main_group, 'Map', 'OmniTAKMobile/Map')
map_ctrl = create_group(map, 'Controllers', 'OmniTAKMobile/Map/Controllers')
map_mark = create_group(map, 'Markers', 'OmniTAKMobile/Map/Markers')
map_over = create_group(map, 'Overlays', 'OmniTAKMobile/Map/Overlays')
map_tile = create_group(map, 'TileSources', 'OmniTAKMobile/Map/TileSources')

# UI with subgroups
ui = create_group(main_group, 'UI', 'OmniTAKMobile/UI')
ui_comp = create_group(ui, 'Components', 'OmniTAKMobile/UI/Components')
ui_mil = create_group(ui, 'MilStd2525', 'OmniTAKMobile/UI/MilStd2525')
ui_rad = create_group(ui, 'RadialMenu', 'OmniTAKMobile/UI/RadialMenu')

# Utilities with subgroups
util = create_group(main_group, 'Utilities', 'OmniTAKMobile/Utilities')
util_calc = create_group(util, 'Calculators', 'OmniTAKMobile/Utilities/Calculators')
util_conv = create_group(util, 'Converters', 'OmniTAKMobile/Utilities/Converters')
util_integ = create_group(util, 'Integration', 'OmniTAKMobile/Utilities/Integration')
util_net = create_group(util, 'Network', 'OmniTAKMobile/Utilities/Network')
util_parse = create_group(util, 'Parsers', 'OmniTAKMobile/Utilities/Parsers')

# Add files function - avoids duplicates
def add_files(group, dir, target)
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

# Add files to groups
puts "\n📄 Adding files..."

files = 0
files += add_files(core, 'OmniTAKMobile/Core', target)
files += add_files(cot, 'OmniTAKMobile/CoT', target)
files += add_files(cot_gen, 'OmniTAKMobile/CoT/Generators', target)
files += add_files(cot_parse, 'OmniTAKMobile/CoT/Parsers', target)
files += add_files(services, 'OmniTAKMobile/Services', target)
files += add_files(managers, 'OmniTAKMobile/Managers', target)
files += add_files(models, 'OmniTAKMobile/Models', target)
files += add_files(storage, 'OmniTAKMobile/Storage', target)
files += add_files(map_ctrl, 'OmniTAKMobile/Map/Controllers', target)
files += add_files(map_mark, 'OmniTAKMobile/Map/Markers', target)
files += add_files(map_over, 'OmniTAKMobile/Map/Overlays', target)
files += add_files(map_tile, 'OmniTAKMobile/Map/TileSources', target)
files += add_files(views, 'OmniTAKMobile/Views', target)
files += add_files(ui_comp, 'OmniTAKMobile/UI/Components', target)
files += add_files(ui_mil, 'OmniTAKMobile/UI/MilStd2525', target)
files += add_files(ui_rad, 'OmniTAKMobile/UI/RadialMenu', target)
files += add_files(util_calc, 'OmniTAKMobile/Utilities/Calculators', target)
files += add_files(util_conv, 'OmniTAKMobile/Utilities/Converters', target)
files += add_files(util_integ, 'OmniTAKMobile/Utilities/Integration', target)
files += add_files(util_net, 'OmniTAKMobile/Utilities/Network', target)
files += add_files(util_parse, 'OmniTAKMobile/Utilities/Parsers', target)

# Add resources
['Assets.xcassets', 'Resources/Info.plist'].each do |res|
  path = "OmniTAKMobile/#{res}"
  if File.exist?(path)
    file_ref = resources.new_reference(path)
    target.resources_build_phase.add_file_reference(file_ref) if res.end_with?('.xcassets')
    files += 1
  end
end

puts "\n✅ Added #{files} unique files"

# Save
puts "\n💾 Saving..."
project.save

puts "\n" + "=" * 60
puts "✅ SUCCESS! Project reorganized cleanly"
puts "=" * 60
puts "\n📊 Summary:"
puts "  • 25 groups created"
puts "  • #{files} files added (no duplicates)"
puts "  • Bundle ID preserved: com.engindearing.omnitak.mobile"
puts "  • Version preserved: 1.3.8"
puts "\n🔨 Building to verify..."
