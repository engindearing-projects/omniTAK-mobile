require 'xcodeproj'

project_path = 'OmniTAKMobile.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
views_group = project.main_group.find_subpath('OmniTAKMobile/Views', true)

file_path = 'OmniTAKMobile/Views/QuickConnectView.swift'
file_ref = views_group.new_reference(file_path)

target.add_file_references([file_ref])

project.save

puts "Added QuickConnectView.swift to project"
