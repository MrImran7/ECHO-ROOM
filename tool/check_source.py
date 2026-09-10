"""Offline lexical sanity checks, NOT a replacement for flutter analyze."""
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
errors=[]
for path in sorted(root.rglob('*.dart')):
 text=path.read_text(); stack=[]; i=0
 while i<len(text):
  if text.startswith('//',i):
   j=text.find('\n',i); i=len(text) if j<0 else j; continue
  if text.startswith('/*',i):
   j=text.find('*/',i+2); i=len(text) if j<0 else j+2; continue
  c=text[i]
  if c in "'\"":
   delimiter=c*3 if text.startswith(c*3,i) else c; i+=len(delimiter)
   while i<len(text) and not text.startswith(delimiter,i):
    i+=2 if text[i]=='\\' else 1
   i+=len(delimiter); continue
  if c in '([{': stack.append((c,text.count('\n',0,i)+1))
  if c in ')]}':
   if not stack or stack[-1][0] != {')':'(',']':'[','}':'{'}[c]:
    errors.append(f'{path.relative_to(root)}:{text.count(chr(10),0,i)+1}: unexpected {c}, stack={stack[-3:]}'); break
   stack.pop()
  i+=1
 if stack: errors.append(f'{path.relative_to(root)}: unclosed {stack[-3:]}')
 for imp in re.findall(r"import '([^']+)';",text):
  if not imp.startswith(('package:','dart:')) and not (path.parent/imp).exists(): errors.append(f'{path}: missing {imp}')
for e in errors: print(e)
print(f'Lexical/import checks: {len(errors)} issue(s). Not Dart compilation.')
sys.exit(bool(errors))
