#!/usr/bin/env ruby

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target not found' unless runner

extension = project.targets.find { |target| target.name == 'NotificationServiceExtension' }
extension ||= project.new_target(
  :app_extension,
  'NotificationServiceExtension',
  :ios,
  runner.deployment_target || '15.0'
)

group = project.main_group.find_subpath('NotificationServiceExtension', true)
group.set_source_tree('<group>')
group.path = 'NotificationServiceExtension'

swift = group.files.find { |file| file.path == 'NotificationService.swift' }
swift ||= group.new_file('NotificationService.swift')
plist = group.files.find { |file| file.path == 'Info.plist' }
plist ||= group.new_file('Info.plist')

unless extension.source_build_phase.files_references.include?(swift)
  extension.source_build_phase.add_file_reference(swift)
end

runner_team = runner.build_configurations
  .map { |config| config.build_settings['DEVELOPMENT_TEAM'] }
  .compact
  .find { |team| !team.empty? }

extension.build_configurations.each do |config|
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'NotificationServiceExtension/Info.plist'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = runner.deployment_target || '15.0'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.flashship.driver.NotificationServiceExtension'
  config.build_settings['PRODUCT_MODULE_NAME'] = 'NotificationServiceExtension'
  config.build_settings['PRODUCT_NAME'] = 'NotificationServiceExtension'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['DEVELOPMENT_TEAM'] = runner_team if runner_team
end

unless runner.dependencies.any? { |dependency| dependency.target == extension }
  runner.add_dependency(extension)
end

embed = runner.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' }
embed ||= runner.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
unless embed.files_references.include?(extension.product_reference)
  embed.add_file_reference(extension.product_reference, true)
end

# Flutter's `Thin Binary` script mutates Runner.app. Embedding the appex after
# that phase creates an Xcode dependency cycle through ProcessInfoPlist/
# CodeSign. Keep the standard app-extension copy phase immediately before it.
phases = runner.build_phases
phases.delete(embed)
thin_index = phases.index { |phase| phase.display_name == 'Thin Binary' }
phases.insert(thin_index || phases.length, embed)

project.save
puts 'NotificationServiceExtension target is configured.'
