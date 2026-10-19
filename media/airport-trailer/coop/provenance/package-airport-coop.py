#!/usr/bin/env python3
"""Package exact frame-aligned editorial selects from genuine dual-peer footage."""
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts'
FPS=24
source=OUT/'airport-bag-throws.mp4'
report=json.loads((OUT/'throw-host.json').read_text())
clock=json.loads((OUT/'capture-clock.json').read_text())
base=report['markers'][0]['ticks_msec']
offset=(clock['cue_monotonic']-clock['recorder_started_monotonic'])*0.5
markers=[dict(m, normal_seconds=round((m['ticks_msec']-base)/2000+offset,6),nearest_frame=round(((m['ticks_msec']-base)/2000+offset)*FPS)) for m in report['markers']]
selects=[('heavy-shared-walk',110,284,'32kg shared carry: helper joins, both walk >6m, gentle Q release'),('airborne-relay',392,558,'8kg G/E airborne throw and catch, host to client and client to host')]
clips=[]
for name,start,end,description in selects:
    path=OUT/(name+'.mp4')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vf',f'trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS','-an','-c:v','libx264','-preset','veryfast','-threads','2','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(path)],check=True)
    subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],check=True)
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','format=duration,size:stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_read_frames','-of','json',str(path)]))
    assert int(probe['streams'][0]['nb_read_frames'])==end-start
    clips.append({'path':str(path.resolve()),'description':description,'source_in_frame':start,'source_out_frame_exclusive':end,'source_in_seconds':start/FPS,'source_out_seconds':end/FPS,'duration_seconds':(end-start)/FPS,'ffprobe':probe})
evidence_frames=[('heavy-walking',180),('heavy-helper',216),('airborne-outbound',438),('airborne-return',513)]
for label,frame in evidence_frames:
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vf',f'select=eq(n\\,{frame})','-fps_mode','passthrough','-frames:v','1',str(OUT/(label+'.png'))],check=True)
for role in ('host','client'):
    r=json.loads((OUT/f'throw-{role}.json').read_text())
    assert r['passed'] and r['simulation_time_scale']==0.5
    assert not re.search(r'ERROR:|SCRIPT ERROR:',(OUT/f'throw-{role}.log').read_text())
    n=json.loads((OUT/'normal-speed'/f'throw-{role}.json').read_text())
    assert n['passed'] and n['simulation_time_scale']==1
assert len(report['catch_events'])==2
assert all(s['linked'] and s['location']=='held' for s in report['shared_samples'])
def xyz(s): return tuple(map(float,s.strip('()').split(',')))
first,last=report['shared_samples'][0],report['shared_samples'][-1]
displacements={k:math.dist(xyz(first[k]),xyz(last[k])) for k in ('primary','helper')}
assert min(displacements.values())>6
output={'source_mp4':str(source.resolve()),'raw_half_speed_capture':str((OUT/'airport-bag-throws-capture.mp4').resolve()),'normal_speed_fps':FPS,'geometry':{'canvas':[1280,480],'host_window':[0,0,640,480],'client_window':[640,0,640,480],'active_gameplay_each':[640,360],'letterbox_y':60},'capture':{'real_process_count':2,'transport':'ENet localhost through ordinary lobby/readiness','automated_inputs':True,'simulation_time_scale':0.5,'video_normalization':'setpts=0.5*PTS,fps=24','audio':'silent Dummy audio; no audio test','fixture_disclosure':report['fixture_disclosure']},'clips':clips,'event_markers':markers,'marker_alignment_note':'Event markers mapped from host monotonic ticks and recorder launch/cue clock. Approximate within a rendered frame plus ffmpeg startup latency. Editorial selects have exact encoded frame boundaries.','assertions':{'captured_session_passed':True,'independent_normal_speed_session_passed':True,'host_checks':len(report['checks']),'client_checks':len(json.loads((OUT/'throw-client.json').read_text())['checks']),'linked_walking_samples':len(report['shared_samples']),'sampled_displacements_metres':displacements,'catch_events':report['catch_events'],'runtime_errors':0}}
output['verified_evidence_frames']=[{'label':label,'source_frame':frame,'normal_seconds':frame/FPS,'path':str((OUT/(label+'.png')).resolve())} for label,frame in evidence_frames]
for clip in clips:
    def tc(frame):
        seconds,subframe=divmod(frame,FPS)
        return f'{seconds//3600:02}:{seconds//60%60:02}:{seconds%60:02}:{subframe:02}'
    clip['source_in_timecode_24fps']=tc(clip['source_in_frame'])
    clip['source_out_timecode_24fps_exclusive']=tc(clip['source_out_frame_exclusive'])
(OUT/'timeline.json').write_text(json.dumps(output,indent=2))
provenance=OUT/'provenance'
provenance.mkdir(exist_ok=True)
files=['scripts/airport/airport_coop_capture.gd','tools/capture-airport-coop.py','tools/package-airport-coop.py']
for f in files: shutil.copy2(ROOT/f,provenance/Path(f).name)
(provenance/'isolated-worktree.patch').write_bytes(subprocess.check_output(['git','diff','HEAD'],cwd=ROOT))
meta={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'worktree':str(ROOT),'original_checkout_not_modified':True,'new_files':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files},'engine':subprocess.check_output(['godot','--version'],text=True).strip(),'capture_command':'LP_NUM_THREADS=4 python3 tools/capture-airport-coop.py --record --time-scale 0.5','normal_speed_check':'python3 tools/capture-airport-coop.py','video_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.mp4')}}
(provenance/'provenance.json').write_text(json.dumps(meta,indent=2))
print(json.dumps(output,indent=2))
