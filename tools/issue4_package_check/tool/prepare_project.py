"""Create a disposable standalone native/web runner without personal config."""
import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def prepare(destination):
    destination = destination.expanduser().resolve()
    if destination.exists():
        raise ValueError('Destination already exists; choose a new directory (nothing overwritten).')
    subprocess.run(['flutter', 'create', '--empty', '--platforms=android,ios,web',
                    '--project-name=yorisoi_package_check', '--org=dev.yorisoi.issue4',
                    str(destination)], check=True)
    for folder in ['lib', 'test', 'tool', 'assets', 'test_python']:
        shutil.copytree(ROOT / folder, destination / folder, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for name in ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', 'dart_test.yaml', '.gitignore', 'README.md']:
        source = ROOT / name
        if source.exists():
            shutil.copy2(source, destination / name)
    android = destination / 'android/app/src/main/AndroidManifest.xml'
    namespace = 'http://schemas.android.com/apk/res/android'
    ET.register_namespace('android', namespace)
    tree = ET.parse(android)
    manifest = tree.getroot()
    for name in ['android.permission.INTERNET', 'android.permission.RECORD_AUDIO']:
        ET.SubElement(manifest, 'uses-permission', {f'{{{namespace}}}name': name})
    queries = manifest.find('queries')
    if queries is None:
        queries = ET.SubElement(manifest, 'queries')
    intent = ET.SubElement(queries, 'intent')
    ET.SubElement(intent, 'action', {f'{{{namespace}}}name': 'android.speech.RecognitionService'})
    tree.write(android, encoding='utf-8', xml_declaration=True)
    gradle = destination / 'android/app/build.gradle.kts'
    if not gradle.exists():
        raise ValueError('Expected current Flutter Kotlin Gradle template; inspect runner manually.')
    gradle.write_text(gradle.read_text().replace('minSdk = flutter.minSdkVersion', 'minSdk = 24'))
    info = destination / 'ios/Runner/Info.plist'
    with info.open('rb') as file:
        data = plistlib.load(file)
    data['NSMicrophoneUsageDescription'] = 'Record a short utterance for the Yorisoi speech test.'
    data['NSSpeechRecognitionUsageDescription'] = 'Transcribe Japanese for the Yorisoi speech test.'
    with info.open('wb') as file:
        plistlib.dump(data, file)
    project = destination / 'ios/Runner.xcodeproj/project.pbxproj'
    project.write_text(re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;',
                             'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', project.read_text()))
    podfile = destination / 'ios/Podfile'
    if podfile.exists():
        text = podfile.read_text()
        if re.search(r'^#?\s*platform :ios,', text, re.M):
            text = re.sub(r'^#?\s*platform :ios,.*$', "platform :ios, '15.0'", text, flags=re.M)
        else:
            text = "platform :ios, '15.0'\n" + text
        podfile.write_text(text)
    subprocess.run(['flutter', 'pub', 'get'], cwd=destination, check=True)
    print('Prepared:', destination)
    print('Android ID: dev.yorisoi.issue4.yorisoi_package_check; iOS bundle: dev.yorisoi.issue4.yorisoiPackageCheck (verify before Firebase registration).')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    try:
        prepare(parser.parse_args().destination)
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Preparation failed: {error}\n')
