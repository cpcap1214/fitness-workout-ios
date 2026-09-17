"""Run the UI audit in a disposable project and separate app container.
Usage: python3 scripts/tests/run_ui_audit.py SIMULATOR_UDID
Requires Xcode and Ruby's xcodeproj gem. No production app data is reset.
"""
import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('device')
parser.add_argument('--large-text', action='store_true')
args = parser.parse_args()

root = pathlib.Path(__file__).resolve().parents[2]
stage = pathlib.Path(tempfile.mkdtemp(prefix='fitness-ui-audit-'))
for name in ('Week 2', 'Week 2.xcodeproj'):
    shutil.copytree(root / name, stage / name)
shutil.copy(root / 'scripts/tests/WorkoutUITests.swift', stage / 'WorkoutUITests.swift')
(stage / 'Week 2/Week_2App.swift').write_text('''import SwiftUI
@main struct AuditApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("reset-audit") {
            let store = WorkoutPlanStore()
            store.archive = WorkoutArchive(plans: WorkoutPlanStore.presetTemplates, presetVersion: 2)
            UserDefaults.standard.removeObject(forKey: "fitness.favoriteExerciseIDs")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView().dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("large-text") ? .accessibility3 : .large)
        }
    }
}
''')
subprocess.run(['ruby', str(root / 'scripts/tests/PrepareAudit.rb'), str(stage / 'Week 2.xcodeproj')], check=True)
print(f'Audit workspace: {stage}', flush=True)
command = ['xcodebuild', '-project', str(stage / 'Week 2.xcodeproj'), '-scheme', 'WorkoutAudit',
           '-destination', f'platform=iOS Simulator,id={args.device}', '-derivedDataPath', str(stage / 'build'),
           '-resultBundlePath', str(stage / 'audit.xcresult'), '-collect-test-diagnostics', 'never', 'test']
previous_size = None
try:
    if args.large_text:
        previous_size = subprocess.check_output(['xcrun', 'simctl', 'ui', args.device, 'content_size'], text=True).strip()
        subprocess.run(['xcrun', 'simctl', 'ui', args.device, 'content_size', 'accessibility-extra-large'], check=True)
        command.insert(-1, '-only-testing:WorkoutUITests/WorkoutUITests/testLargeText')
    subprocess.run(command, check=True)
finally:
    if previous_size:
        subprocess.run(['xcrun', 'simctl', 'ui', args.device, 'content_size', previous_size], check=True)
