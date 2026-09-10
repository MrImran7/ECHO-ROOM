#!/usr/bin/env python3
"""Generate native hosts using the installed stable Flutter templates.

Preserves all Dart code/assets/tests and any existing native host. This avoids
shipping unverified hand-written Gradle wrappers or Xcode project files.
"""
from pathlib import Path
import argparse, json, plistlib, shutil, subprocess, tempfile, sys
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--skip-pub',action='store_true')
args=p.parse_args()
flutter=shutil.which('flutter')
if not flutter:
 sys.exit('Flutter was not found on PATH. Install the stable Flutter SDK and run flutter doctor first.')
def run(*args,cwd=ROOT):
 subprocess.run([flutter,*args],cwd=cwd,check=True)
run('--version')
need_android=not (ROOT/'android/gradlew').exists()
need_ios=not (ROOT/'ios/Runner.xcodeproj/project.pbxproj').exists()
if need_android or need_ios:
 with tempfile.TemporaryDirectory(prefix='echo-room-hosts-') as temp:
  host=Path(temp)/'echo_room'
  run('create','--no-pub','--platforms=android,ios','--project-name','echo_room','--org','com.imran.games',str(host))
  for platform,needed in [('android',need_android),('ios',need_ios)]:
   if needed:
    if (ROOT/platform).exists():
     sys.exit(f'{platform}/ exists but is incomplete. Move it aside to preserve your edits, then retry.')
    shutil.copytree(host/platform,ROOT/platform)
  if (host/'.metadata').exists() and not (ROOT/'.metadata').exists():
   shutil.copy2(host/'.metadata',ROOT/'.metadata')
# Set product display names without requesting any app permissions.
manifest=ROOT/'android/app/src/main/AndroidManifest.xml'
text=manifest.read_text().replace('android:label="echo_room"','android:label="Echo Room"')
manifest.write_text(text)
# The current shared_preferences Android implementation requires API 24+.
for build in [ROOT/'android/app/build.gradle.kts', ROOT/'android/app/build.gradle']:
 if build.exists():
  text=build.read_text().replace('minSdk = flutter.minSdkVersion','minSdk = 24').replace('minSdkVersion flutter.minSdkVersion','minSdkVersion 24')
  build.write_text(text)
plist=ROOT/'ios/Runner/Info.plist'
with plist.open('rb') as f: info=plistlib.load(f)
info['CFBundleDisplayName']='Echo Room'
info['CFBundleName']='Echo Room'
info['UISupportedInterfaceOrientations']=['UIInterfaceOrientationPortrait']
info['UISupportedInterfaceOrientations~ipad']=['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown']
with plist.open('wb') as f: plistlib.dump(info,f,sort_keys=False)
# Generate app icons from the original geometric icon bundled in the source.
icon=ROOT/'assets/images/app_icon.png'
if icon.exists():
 try:
  from PIL import Image
  im=Image.open(icon)
  for density,size in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.items():
   dest=ROOT/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
   dest.parent.mkdir(parents=True,exist_ok=True); im.resize((size,size),Image.Resampling.LANCZOS).save(dest)
  aset=ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
  contents=json.loads((aset/'Contents.json').read_text())
  for entry in contents['images']:
   if 'filename' not in entry: continue
   size=round(float(entry['size'].split('x')[0])*float(entry.get('scale','1x').removesuffix('x')))
   im.resize((size,size),Image.Resampling.LANCZOS).convert('RGB').save(aset/entry['filename'])
 except ImportError:
  print('Optional: install Pillow and rerun bootstrap to replace generated launcher icons.')
if not args.skip_pub: run('pub','get')
print('Native hosts ready. Run flutter analyze, flutter test, then flutter run.')
