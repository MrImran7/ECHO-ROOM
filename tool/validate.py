#!/usr/bin/env python3
"""Run all required quality gates; exit nonzero on any failure."""
from pathlib import Path
import argparse, shutil, subprocess, sys, json, datetime
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--ios',action='store_true'); args=p.parse_args()
flutter=shutil.which('flutter')
commands=[['pub','get'],['analyze'],['test'],['build','apk','--debug']]
# Formatting is a separate Dart command, not a Flutter subcommand.
if shutil.which('dart'):
 subprocess.run(['dart','format','.'],cwd=root,check=True)
else:
 print('dart format .: BLOCKED (Dart SDK is not installed).',flush=True)
if args.ios: commands.append(['build','ios','--simulator','--debug'])
results=[]
if flutter:
 subprocess.run([sys.executable,str(root/'tool/bootstrap.py'),'--skip-pub'],cwd=root,check=True)
for command in commands:
 print('\n> flutter '+' '.join(command),flush=True)
 if not flutter:
  result={'command':'flutter '+' '.join(command),'status':'BLOCKED','reason':'Flutter SDK is not installed on PATH.'}
 else:
  run=subprocess.run([flutter,*command],cwd=root)
  result={'command':'flutter '+' '.join(command),'status':'PASS' if run.returncode==0 else 'FAIL','exitCode':run.returncode}
 results.append(result); print(result,flush=True)
report={'recordedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks':results}
(root/'validation-results.json').write_text(json.dumps(report,indent=2))
sys.exit(0 if all(r['status']=='PASS' for r in results) else 1)
