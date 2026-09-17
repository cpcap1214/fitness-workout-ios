require 'xcodeproj'
# Adds a UI test target only to the disposable project copy made by run_ui_audit.py.
p = Xcodeproj::Project.open(ARGV.fetch(0))
app = p.targets.find { |t| t.name == 'Week 2' }
app.build_configurations.each { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'cpcap.Week-2.WorkoutQA' }
t = p.new_target(:ui_test_bundle, 'WorkoutUITests', :ios, '26.0')
t.add_dependency(app)
t.build_configurations.each do |c|
 c.build_settings.merge!('PRODUCT_NAME' => 'WorkoutUITests', 'TEST_TARGET_NAME' => 'Week 2',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'cpcap.WorkoutUITests', 'GENERATE_INFOPLIST_FILE' => 'YES',
  'SWIFT_VERSION' => '5.0', 'CODE_SIGNING_ALLOWED' => 'NO')
end
t.source_build_phase.add_file_reference(p.main_group.new_file('WorkoutUITests.swift'))
p.save
s = Xcodeproj::XCScheme.new
s.add_build_target(app); s.add_build_target(t); s.set_launch_target(app); s.add_test_target(t)
s.save_as(p.path, 'WorkoutAudit')
