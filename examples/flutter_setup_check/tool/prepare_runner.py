"""Create a new disposable runner for the Issue 3 package; never overwrites work."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess

source = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('destination', type=Path)
args = parser.parse_args()
target = args.destination.expanduser().resolve()
if target.exists():
    parser.exit(1, 'Choose a new destination; existing files are not overwritten.\n')
subprocess.run(['flutter', 'create', '--empty', '--platforms=android,ios,web',
                '--org=dev.yorisoi.issue3', '--project-name=yorisoi_flutter_setup_check', str(target)], check=True)
for name in ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', '.gitignore', 'README.md']:
    if (source / name).exists():
        shutil.copy2(source / name, target / name)
for folder in ['lib', 'test']:
    shutil.copytree(source / folder, target / folder, dirs_exist_ok=True)
gradle = target / 'android/app/build.gradle.kts'
if not gradle.exists():
    parser.exit(1, 'Expected Flutter Kotlin Gradle template; inspect generated runner.\n')
gradle.write_text(gradle.read_text().replace('minSdk = flutter.minSdkVersion', 'minSdk = 24'))
project = target / 'ios/Runner.xcodeproj/project.pbxproj'
project.write_text(re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', project.read_text()))
podfile = target / 'ios/Podfile'
if podfile.exists():
    text = podfile.read_text()
    text = re.sub(r'^#?\s*platform :ios,.*$', "platform :ios, '15.0'", text, flags=re.M) if re.search(r'^#?\s*platform :ios,', text, re.M) else "platform :ios, '15.0'\n" + text
    podfile.write_text(text)
subprocess.run(['flutter', 'pub', 'get'], cwd=target, check=True)
print('Runner ready:', target)
