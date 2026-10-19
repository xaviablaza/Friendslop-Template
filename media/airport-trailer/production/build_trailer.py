#!/usr/bin/env python3
"""Editable trailer compositor: genuine game pixels + external graphics/score."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from array import array
import argparse, concurrent.futures, hashlib, json, math, random, subprocess, wave

OUT = Path(__file__).resolve().parent
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FPS = 24
NAVY, GOLD, MINT, WHITE, MUTED = '#101c27', '#e2c77d', '#80dccb', '#f2f5f4', '#a4b6c6'

def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)

def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)

def text(draw, value, xy, size, fill=WHITE, bold=False, width=968, gap=10):
    x,y=xy
    for line in value.split('\n'):
        assert draw.textlength(line,font=font(size,bold))<=width,(value,size)
        draw.text((x,y),line,font=font(size,bold),fill=fill)
        y+=size+gap

def poster(s,i,total):
    im=Image.new('RGB',(1080,1920),NAVY)
    d=ImageDraw.Draw(im)
    accent=MINT if s.get('care') else GOLD
    for y in range(0,1920,96):
        d.line([(1035,y),(1080,y+45)],fill='#1c303c',width=12)
    d.rectangle((48,48,55,78),fill=accent)
    text(d,'CHECKED CHAOS / AIRPORT BAGGAGE',(74,48),22,MUTED,True)
    text(d,f'{i+1:02d}',(965,48),22,accent,True,width=80)
    text(d,s['title'],(48,112),64,WHITE,True,gap=5)
    d.line((48,286,1032,286),fill='#344650',width=2)
    text(d,s.get('tag','ACTUAL PROTOTYPE GAMEPLAY'),(48,306),19,accent,True)
    if s.get('end'):
        text(d,'WHO IS ON\nYOUR SHIFT?',(48,540),82,WHITE,True,gap=16)
        text(d,'SCAN. SORT.\nLOOK OUT FOR EACH OTHER.',(48,910),40,accent,True,gap=16)
        text(d,s['copy'],(48,1250),29,WHITE,gap=18)
        text(d,'IN DEVELOPMENT / NO RELEASE DATE ANNOUNCED',(48,1550),20,MUTED,True)
    elif s.get('coop'):
        text(d,'PLAYER 1',(48,352),21,GOLD,True)
        text(d,'PLAYER 2',(48,974),21,MINT,True)
        text(d,s['copy'],(48,1640),29,WHITE,gap=14)
    else:
        if len(s.get('panes',[]))>1:
            text(d,s.get('detail_label','DETAIL / SAME LIVE GAMEPLAY FRAME'),(48,1014),20,accent,True)
        text(d,s['copy'],(48,1550),34,WHITE,gap=18)
    if not s.get('coop'):
        d.rectangle((48,1800,1032,1803),fill='#344650')
        d.rectangle((48,1800,48+round(984*(i+1)/total),1803),fill=accent)
    text(d,'AUTOMATED GAMEPLAY / SCRIPTED SCENARIOS',(48,1880),17,MUTED,True)
    p=OUT/f'card-{i:02d}.png'; im.save(p); return p

def render(pair):
    i,s,total=pair
    p=poster(s,i,total)
    out=OUT/f'shot-{i:02d}.mp4'
    frames=round(s['duration']*FPS)
    cmd=['ffmpeg','-hide_banner','-loglevel','error','-y']
    if s.get('end'):
        cmd+=['-loop','1','-framerate',str(FPS),'-i',str(p),'-vf',f'fade=t=in:st=0:d=0.2,fade=t=out:st={s["duration"]-.5}:d=0.5']
    else:
        source=Path(s['source']); assert source.is_file(),source
        assert s.get('rate',1)>0
        cmd+=['-ss',str(s['start']),'-i',str(source),'-loop','1','-framerate',str(FPS),'-i',str(p)]
        panes=s['panes']; n=len(panes)
        graph=[f'[0:v]setpts=(PTS-STARTPTS)/{s.get("rate",1)},fps={FPS},split={n}'+''.join(f'[s{j}]' for j in range(n))] if n>1 else [f'[0:v]setpts=(PTS-STARTPTS)/{s.get("rate",1)},fps={FPS}[s0]']
        base='1:v'
        for j,pane in enumerate(panes):
            x,y,w,h=pane['crop']; px,py,pw,ph=pane['rect']
            graph.append(f'[s{j}]crop={w}:{h}:{x}:{y},scale={pw}:{ph}:force_original_aspect_ratio=decrease:force_divisible_by=2,pad={pw}:{ph}:(ow-iw)/2:(oh-ih)/2:color=0x101c27,setsar=1[p{j}]')
            graph.append(f'[{base}][p{j}]overlay={px}:{py}:shortest=1[b{j}]')
            base=f'b{j}'
        cmd+=['-filter_complex_threads','1','-filter_complex',';'.join(graph),'-map',f'[{base}]']
    run(cmd+['-frames:v',str(frames),'-an','-c:v','libx264','-preset','veryfast','-threads','2','-crf','21','-pix_fmt','yuv420p',str(out)])
    return out

def score(duration,scenes):
    sr=24000; n=round(duration*sr); mix=array('f',[0])*n; rng=random.Random(3317)
    def add(start,length,fn,amp):
        pos=round(start*sr)
        if pos<0 or pos>=n:return
        for j in range(min(round(length*sr),n-pos)):
            mix[pos+j]+=amp*fn(j/sr)
    beat=60/120
    for b in range(math.ceil(duration/beat)):
        t=b*beat
        care=any(s.get('care') and s['edit_start']<=t<s['edit_end'] for s in scenes)
        gain=.52 if care else 1
        add(t,.25,lambda x:math.sin(2*math.pi*(44*x+1.8*(1-math.exp(-x*34))))*math.exp(-x*18),.43*gain)
        if b%2:add(t,.15,lambda x:(rng.random()*2-1)*math.exp(-x*35),.16*gain)
        for off in (0,.25):add(t+off,.04,lambda x:(rng.random()*2-1)*math.exp(-x*110),.045*gain)
        f=[55,55,65.406,55,73.416,55,82.407,49][b%8]
        add(t,.4,lambda x,f=f:(math.sin(2*math.pi*f*x)+.25*math.sin(4*math.pi*f*x))*min(1,x*140)*math.exp(-x*5),.15*gain)
        melody=[220,261.626,329.628,261.626,293.665,261.626,220,195.998][b%8]
        add(t+.25,.2,lambda x,f=melody:math.sin(2*math.pi*f*x)*math.exp(-x*19),.05*gain)
    for s in scenes:
        add(s['edit_start'],.09,lambda x:(rng.random()*2-1)*math.sin(math.pi*x/.09)*math.exp(-x*12),.06)
    output=array('h')
    peak=0
    for i,v in enumerate(mix):
        fade=min(1,i/sr/.12,max(0,(duration-i/sr)/1.0))
        sample=round(math.tanh(v)*27000*fade);peak=max(peak,abs(sample));output.append(sample)
    assert 1000<peak<32767
    p=OUT/'original-score.wav'
    with wave.open(str(p),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(output.tobytes())
    return p,peak

def main():
    ap=argparse.ArgumentParser();ap.add_argument('storyboard');ap.add_argument('--layout-only',action='store_true');ap.add_argument('--render-only',action='store_true');args=ap.parse_args()
    scenes=json.loads(Path(args.storyboard).read_text())
    cursor=0
    for s in scenes:
        s['duration']=round(s['duration']*FPS)/FPS
        s['edit_start']=cursor;cursor+=s['duration'];s['edit_end']=cursor
    (OUT/'storyboard-final.json').write_text(json.dumps(scenes,indent=2))
    if args.layout_only:
        for i,s in enumerate(scenes):poster(s,i,len(scenes))
        print('Layout cards prepared');return
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        parts=list(pool.map(render,[(i,s,len(scenes)) for i,s in enumerate(scenes)]))
    if args.render_only:
        print(json.dumps({'rendered_shots':len(parts),'seconds':cursor}));return
    music,peak=score(cursor,scenes)
    playlist=OUT/'shots.ffconcat';playlist.write_text('ffconcat version 1.0\n'+''.join(f"file '{p.name}'\n" for p in parts))
    final=OUT/'airport-baggage-expanded-trailer-vertical.mp4'
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(playlist),'-i',str(music),'-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','160k','-af','aformat=channel_layouts=stereo,loudnorm=I=-16:TP=-1.5:LRA=9','-ar','48000','-ac','2','-t',str(cursor),'-movflags','+faststart',str(final)])
    run(['ffmpeg','-v','error','-i',str(final),'-f','null','-'])
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(final)],text=True))
    v=next(s for s in probe['streams'] if s['codec_type']=='video');a=next(s for s in probe['streams'] if s['codec_type']=='audio')
    assert (v['width'],v['height'])==(1080,1920)
    assert a['sample_rate']=='48000' and a['channels']==2
    assert abs(float(probe['format']['duration'])-cursor)<.1
    evidence={'probe':probe,'sha256':hashlib.sha256(final.read_bytes()).hexdigest(),'features':sorted({f for s in scenes for f in s.get('features',[])}),'original_synth_score_pcm_peak':peak,'provenance':'Fresh actual Godot footage. Automated scripted scenarios; editorial crops and any rate changes in storyboard. No reconstructed gameplay or seeded upgrade currency.'}
    (OUT/'trailer-evidence.json').write_text(json.dumps(evidence,indent=2))
    print(json.dumps({'file':str(final),'seconds':cursor,'scenes':len(scenes),'sha256':evidence['sha256']},indent=2))

if __name__=='__main__':main()
