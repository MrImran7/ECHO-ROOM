"""Generate original, quiet PCM audio. No samples or third-party assets."""
from pathlib import Path
import math, wave, struct
ROOT=Path(__file__).resolve().parents[1]/'assets/audio'
RATE=22050
cues={'menu':([330,440],.16),'countdown':([440],.09),'flicker':([80,110,65],.18),
 'correct':([523.25,659.25,783.99],.12),'wrong':([180,140],.11),
 'streak':([523.25,659.25,783.99,1046.5],.13),'complete':([392,523.25,659.25],.17),'mystery':([220,233.08,329.63],.3)}
def save(name,samples):
 with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
  f.setparams((1,2,RATE,0,'NONE','not compressed'))
  f.writeframes(b''.join(struct.pack('<h',round(max(-1,min(1,s))*18000)) for s in samples))
for name,(notes,duration) in cues.items():
 samples=[]
 for freq in notes:
  for i in range(int(duration*RATE)):
   t=i/RATE; envelope=min(1,t/.008)*max(0,1-t/duration)**2
   samples.append(.35*envelope*(math.sin(2*math.pi*freq*t)+.2*math.sin(4*math.pi*freq*t)))
 save(name,samples)
# Frequencies complete integral cycles over 8s, yielding a seamless quiet loop.
save('ambient',[(sum(math.sin(2*math.pi*f*i/RATE) for f in [110,164.875,220])/3)*.14
   *(0.75+0.25*math.cos(2*math.pi*i/(RATE*8))) for i in range(RATE*8)])
