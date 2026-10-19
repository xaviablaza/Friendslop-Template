#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,concurrent.futures
P=Path(__file__).resolve().parent
S=json.loads((P/'storyboard.json').read_text())
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13)
def frame(pair):
 i,s=pair
 out=P/f'review-{i:02d}.jpg'
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(s['duration']*.5),'-i',str(P/f'shot-{i:02d}.mp4'),'-frames:v','1','-q:v','2',str(out)],check=True)
 return out
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:paths=list(pool.map(frame,enumerate(S)))
for start in range(0,len(S),6):
 sheet=Image.new('RGB',(1080,1320),'#0a121a');d=ImageDraw.Draw(sheet)
 for j,p in enumerate(paths[start:start+6]):
  im=Image.open(p);im.thumbnail((360,640))
  x=(j%3)*360;y=(j//3)*660
  sheet.paste(im,(x,y));d.text((x+6,y+642),f'{start+j:02d} {S[start+j]["id"]}',font=F,fill='white')
 out=P/f'review-sheet-{start//6+1:02d}.jpg';sheet.save(out,quality=92)
 print(out)
