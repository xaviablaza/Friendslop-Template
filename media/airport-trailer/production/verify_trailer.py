#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from array import array
import concurrent.futures, hashlib, json, math, subprocess
P=Path(__file__).resolve().parent
V=P/'airport-baggage-expanded-trailer-vertical.mp4'
S=json.loads((P/'storyboard-final.json').read_text())
C=json.loads((P/'coverage-plan.json').read_text())
required=set(C['required_features']);features={f for s in S for f in s.get('features',[])}
assert not required-features,required-features
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_format','-show_streams','-of','json',str(V)],text=True))
v=next(x for x in probe['streams'] if x['codec_type']=='video');a=next(x for x in probe['streams'] if x['codec_type']=='audio')
assert v['width']==1080 and v['height']==1920 and v['pix_fmt']=='yuv420p' and v['r_frame_rate']=='24/1'
assert int(v['nb_read_frames'])==sum(round(s['duration']*24) for s in S)
assert a['sample_rate']=='48000' and a['channels']==2
r=subprocess.run(['ffmpeg','-v','error','-i',str(V),'-f','null','-'],capture_output=True,text=True)
assert r.returncode==0 and not r.stderr.strip(),r.stderr
pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(V),'-vn','-f','s16le','-ac','2','-ar','48000','-'])
samples=array('h');samples.frombytes(pcm)
peak=max(abs(x) for x in samples);rms=math.sqrt(sum(x*x for x in samples)/len(samples));clips=sum(abs(x)>=32767 for x in samples)
assert peak>1000 and rms>100 and clips==0,(peak,rms,clips)
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13)
def grab(pair):
 i,s=pair;p=P/f'final-review-{i:02d}.jpg'
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(s['edit_start']+s['duration']*.5),'-i',str(V),'-frames:v','1','-q:v','2',str(p)],check=True)
 return p
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:imgs=list(pool.map(grab,enumerate(S)))
sheets=[]
for start in range(0,len(S),6):
 im=Image.new('RGB',(1080,1320),'#0a121a');d=ImageDraw.Draw(im)
 for j,p in enumerate(imgs[start:start+6]):
  thumb=Image.open(p);thumb.thumbnail((360,640));x=(j%3)*360;y=(j//3)*660
  im.paste(thumb,(x,y));d.text((x+6,y+642),f'{start+j:02d} {S[start+j]["id"]}',font=F,fill='white')
 out=P/f'final-review-sheet-{start//6+1:02d}.jpg';im.save(out,quality=92);sheets.append(str(out))
features_at={f:[{'scene':s['id'],'start':s['edit_start'],'end':s['edit_end']} for s in S if f in s.get('features',[])] for f in sorted(features)}
report={'passed_media_checks':True,'video':str(V),'source_revision':C['source_revision'],'sha256':hashlib.sha256(V.read_bytes()).hexdigest(),'duration_seconds':float(probe['format']['duration']),'file_bytes':V.stat().st_size,'shots':len(S),'expected_features':len(required),'covered_features':len(required&features),'missing_features':sorted(required-features),'dimensions':[v['width'],v['height']],'frames':v['nb_read_frames'],'audio':{'sample_rate':a['sample_rate'],'channels':a['channels'],'decoded_pcm_peak':peak,'rms':rms,'clipped_samples':clips},'full_decode_stderr':r.stderr,'feature_timecodes':features_at,'review_sheets':sheets,'visual_review':'Exact final-file shot midpoint images prepared for human/agent inspection; not inferred from render success.'}
(P/'final-verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:val for k,val in report.items() if k not in ['feature_timecodes','visual_review']},indent=2))
