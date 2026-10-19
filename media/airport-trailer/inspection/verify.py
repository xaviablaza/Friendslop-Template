from pathlib import Path
import json, subprocess, hashlib, re
from PIL import Image, ImageDraw
P=Path('/home/administrator/Friendslop-Template-airport-baggage')
O=P/'artifacts/trailer-v2/inspection'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args): return subprocess.check_output(args,cwd=P,text=True)
def save(name,obj): (O/name).write_text(json.dumps(obj,indent=2))
main=json.loads((O/'main-timeline.json' if (O/'main-timeline.json').exists() else O/'timeline.json').read_text())
supp=json.loads((O/'supplement-timeline.json').read_text())
save('main-timeline.json',main)
shots=main['shots']
offset=shots[-1]['end_frame']
for s in supp['shots']:
    s['start_frame']+=offset
    s['end_frame']+=offset
    s['start']=s['start_frame']/24
    s['end']=s['end_frame']/24
    s['source']='supplement-native.avi (scripted independent scenario)'
    shots.append(s)
for s in shots:
    s.setdefault('source','inspection-native.avi')
    s['timecode_start']=f"{int(s['start']//60):02}:{s['start']%60:06.3f}"
    s['timecode_end']=f"{int(s['end']//60):02}:{s['end']%60:06.3f}"
    s['start']=s['start_frame']/24
    s['end']=s['end_frame']/24
# Correct visual scope: main thrown clothes lands on an actual route-station surface.
for s in shots:
    if s['id']=='individual_item_throw':
        s['visible_result']='Real browser picks folded clothes; normal G launches them onto an actual route-station surface. The appended clear_individual_item_flight shot is preferred for editing.'
    if s['id']=='physical_stack_impact_damage':
        s['visible_result']='Three actual bag bodies settle into a supported stack; E removes bottom, remaining bags visibly fall. Damage is asserted here but the appended top-bag close aim shows actual DAMAGE 4% legibly.'
    if s['id']=='injury_health_after_actual_impact':
        s['visible_result']='Independent scripted scenario: gravity-driven falling bag hits local operator; follow-down view holds actual HEALTH 89 and landed bag. Main capture separately includes the real first-aid recovery.'
final_timeline={'fps':24,'native_size':[1280,720],'video':'inspection-complete.mp4','shot_count':len(shots),'duration':shots[-1]['end'],'disclosure':'Automated actual Godot gameplay with scripted catalogue cases, positions and cameras; separate supplemental scenarios appended after main. No fabricated UI, seeded money, or invented outcomes. Silent footage; external trailer captions must disclose scripted scenarios.','source_trim_frames':{'inspection-native.avi':8,'supplement-native.avi':7},'shots':shots}
save('timeline.json',final_timeline)
c1=json.loads((O/'checks.json').read_text())
c2=json.loads((O/'supplement-checks.json').read_text())
checks=c1['checks']+c2['checks']
assert all(c['passed'] for c in checks)
save('assertions.json',{'passed':all(c['passed'] for c in checks),'assertion_count':len(checks),'main_assertions':len(c1['checks']),'supplement_assertions':len(c2['checks']),'checks':checks})
logs=['headless.log','render.log','supplement-headless.log','supplement-render.log']
errors={n:re.findall(r'^.*(?:SCRIPT ERROR:|ERROR:|Parse Error|Invalid call).*$',(O/n).read_text(),re.M) for n in logs}
assert not any(errors.values()), errors
(O/'no-runtime-error.log').write_text('\n'.join(f'{n}: 0 runtime/script/parse errors' for n in logs)+'\nRendered captures contain the Xvfb/Mesa unsupported V-Sync warning; no gameplay runtime errors.\n')
probe=json.loads(run(['ffprobe','-v','error','-show_entries','format=duration,size:stream=codec_name,width,height,r_frame_rate,nb_frames,pix_fmt','-of','json',str(O/'inspection-complete.mp4')]))
assert probe['streams'][0]['nb_frames']==str(shots[-1]['end_frame'])
save('media-probe.json',probe)
sources=list((P/'scripts/airport').glob('*.gd'))+[P/'project.godot',P/'scenes/level/airport/AirportBaggage.tscn',O/'capture.gd',O/'supplement.gd']
save('provenance.json',{'head':run(['git','rev-parse','HEAD']).strip(),'tracked_worktree_status':run(['git','status','--short']),'engine':run(['godot','--version']).strip(),'sources':{str(p.relative_to(P)):sha(p) for p in sources},'videos':{n:sha(O/n) for n in ['inspection-complete.mp4','inspection-native.avi','supplement-native.avi']},'recording':'Godot MovieMaker native 1280x720 24fps, private xvfb-run, software OpenGL llvmpipe, LP_NUM_THREADS=3. Encoded H.264 yuv420p; silent. No UI reconstruction or generated frames.','input':'Input.parse_input_event physical keys; actual browser/station pressed and dropdown signals connected to original gameplay gateway.','fixtures':'fixtures.json plus exact scripted supplemental fixture edits in supplement.gd; RNG seeds 20261019 and 20261020. Catalogue contents certain=true for rare category staging, normal rejection-sampled cleared legal lookalike. No seeded funds/health; initial bags staged scanned; cleanup marked sorted directly and not counted as routing.','verification':{'headless_and_render_pass':True,'assertions':len(checks),'runtime_errors':errors,'fully_decoded':True},'application_edits':False,'issues':['One expected unsupported V-Sync warning under Xvfb/Mesa.','Main item throw lands quickly on a station; supplemental flight is preferable.','Main pile targets middle bag manifest; supplemental close aim shows top DAMAGE 4%.']})
# Extract actual encoded gameplay frames; sheet labels are outside each captured image.
thumbs=[]
for i,s in enumerate(shots):
    t=(s['start']+s['end'])/2
    fn=O/f'encoded-shot-{i+1:02}.png'
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-threads','2','-ss',str(t),'-i',str(O/'inspection-complete.mp4'),'-frames:v','1',str(fn)],check=True)
    im=Image.open(fn).convert('RGB').resize((384,216))
    thumbs.append((im,f"{i+1:02} {s['timecode_start']} {s['id']}"))
cols=3
rows=(len(thumbs)+cols-1)//cols
sheet=Image.new('RGB',(cols*384,rows*242),'#101820')
d=ImageDraw.Draw(sheet)
for i,(im,label) in enumerate(thumbs):
    x=(i%cols)*384;y=(i//cols)*242
    sheet.paste(im,(x,y));d.text((x+4,y+220),label,fill='white')
sheet.save(O/'encoded-contact-sheet.jpg',quality=94)
print(json.dumps({'assertions':len(checks),'shots':len(shots),'duration':probe['format']['duration'],'video':str(O/'inspection-complete.mp4'),'timeline':str(O/'timeline.json')},indent=2))
for s in shots: print(s['timecode_start'],s['timecode_end'],s['id'])
