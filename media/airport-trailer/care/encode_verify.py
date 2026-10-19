#!/usr/bin/env python3
"""Encode completed real Godot movie; verify gameplay report and media."""
from pathlib import Path
import collections, hashlib, json, subprocess
P = Path(__file__).resolve().parent
report = json.loads((P/'assertions.json').read_text())
assert report['passed'] and all(c['ok'] for c in report['checks']), 'Gameplay assertion failed'
def run(args, log=None):
    r = subprocess.run(args, capture_output=True, text=True)
    if log: (P/log).write_text(r.stdout+r.stderr)
    if r.returncode: raise RuntimeError(f'{args[0]} failed {r.returncode}: {r.stderr[-1500:]}')
    return r.stdout
run(['ffmpeg','-hide_banner','-y','-threads','3','-i',str(P/'care-source.avi'),'-c:v','libx264','-threads','3','-preset','fast','-crf','20','-vf','scale=in_range=full:out_range=tv,format=yuv420p','-pix_fmt','yuv420p','-color_range','tv','-an','-movflags','+faststart',str(P/'care-source.mp4')], 'encode.log')
probe = json.loads(run(['ffprobe','-v','error','-show_entries','format=duration,size:stream=codec_name,width,height,r_frame_rate,pix_fmt,nb_frames','-of','json',str(P/'care-source.mp4')]))
(P/'probe.json').write_text(json.dumps(probe,indent=2))
v = probe['streams'][0]
assert (v['width'],v['height'],v['r_frame_rate'],v['codec_name'],v['pix_fmt']) == (1280,720,'24/1','h264','yuv420p')
run(['ffmpeg','-v','error','-threads','3','-i',str(P/'care-source.mp4'),'-f','null','-'],'decode.log')
timeline = json.loads((P/'timeline.json').read_text())
for i,s in enumerate(timeline['scenes']):
    t = (s['start']+s['end'])/2
    run(['ffmpeg','-v','error','-y','-ss',f'{t:.6f}','-i',str(P/'care-source.mp4'),'-frames:v','1',str(P/f'encoded-scene-{i+1:02}.png')])
from PIL import Image, ImageDraw
images = sorted(P.glob('encoded-scene-*.png'))
w,h = 384,240
sheet = Image.new('RGB',(w*4,h*((len(images)+3)//4)), '#111111')
draw = ImageDraw.Draw(sheet)
for i,p in enumerate(images):
    im=Image.open(p).convert('RGB').resize((384,216))
    x=(i%4)*w;y=(i//4)*h
    sheet.paste(im,(x,y))
    s=timeline['scenes'][i]
    draw.text((x+4,y+220),f'{i+1:02} {s["start"]:.3f}-{s["end"]:.3f} {s["name"][:32]}',fill='white')
sheet.save(P/'encoded-contact-sheet.jpg',quality=92)
checks = collections.Counter(c['ok'] for c in report['checks'])
results = collections.Counter(r['result'] for r in report['scent_results'])
summary={'media_verified':True,'full_decode_errors':(P/'decode.log').read_text(),'assertions_passed':checks[True],'assertions_failed':checks[False],'scenes':len(timeline['scenes']),'duration':probe['format']['duration'],'sha256':hashlib.sha256((P/'care-source.mp4').read_bytes()).hexdigest(),'scent_results':dict(results),'money_ledger':report['money_ledger'],'disclosures':report['disclosures']}
(P/'verification.json').write_text(json.dumps(summary,indent=2))
def tc(t):
    f=round(t*24);return f'{f//1440:02}:{(f//24)%60:02}:{f%24:02}'
lines=['# Fresh PET / DOG / PROGRESSION footage','',f'MP4: care-source.mp4 — {probe["format"]["duration"]} sec; 1280×720, 24fps, H.264/yuv420p, silent.','', 'Timecodes are MM:SS:FF at 24 fps; ranges are half-open.','', '| In | Out | Scene |','|---|---|---|']
for s in timeline['scenes']: lines.append(f'| {tc(s["start"])} | {tc(s["end"])} | {s["name"]} |')
lines += ['',f'Assertions: {checks[True]} passed, {checks[False]} failed. Full MP4 decoded without errors.',f'Observed RNG scent outcomes: {dict(results)}.','', '## Disclosures']+[f'- {d}' for d in report['disclosures']]
lines += ['', '## Limitations','- Automated fixture-staged solo footage, not a continuous human shift or multiplayer proof.','- All rewards and purchases are live. Staged object positions and known item truth are disclosed above.','- Pet portraits look through the carrier from behind; the animals and differing ear silhouettes are visible, but these are not face closeups.','- Scent counts are observed after the first live pulse, not lifetime totals: subsequent pulses can alert a previously missed bag. The live bark HUD may name a different bag while the earlier false-positive bag is inspected. Use assertions.json to distinguish these timings.','- In-game UI is unmodified; no recorded chapter or branding graphics. Parent may add captions outside footage.','- Render log retains a software-driver VSync warning. Final rendered run has no script errors or shutdown-leak warning; the headless preflight retains an ObjectDB shutdown-leak warning.']
(P/'SCENES.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(summary,indent=2))
