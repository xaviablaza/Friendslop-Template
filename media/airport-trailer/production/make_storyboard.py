#!/usr/bin/env python3
from pathlib import Path
import json
P=Path(__file__).resolve().parent
R=P.parent
I=R/'inspection/inspection-complete.mp4'
C=R/'care/care-source.mp4'
M=R/'movement/movement-source.mp4'
S=[]
def add(id,source,start,duration,title,copy,features=(),detail=None,tag='ACTUAL PROTOTYPE GAMEPLAY',rate=1.0,care=False,menu=False):
    panes=[{'crop':[0,0,1280,720],'rect':[48,425,984,554]}]
    if menu:
        panes=[{'crop':[240,30,800,660],'rect':[48,400,984,1050]}]
    elif detail:
        panes.append({'crop':detail,'rect':[48,1050,984,400]})
    s=dict(id=id,source=str(source),start=start,duration=duration,title=title,copy=copy,features=list(features),panes=panes,tag=tag,rate=rate,care=care)
    S.append(s)
add('hook',C,63.15,2.25,'JUST SORT\nTHE BAGS.','Easy shift.\nComplicated luggage.', ['throw_dog'],[330,195,570,385],tag='HARMLESS CARTOON DOG HOP / NO ANIMAL HARM')
add('splash',M,.15,1.8,'CLOCK IN.','A fresh shift starts here.', ['splash'],menu=True)
add('menu',M,2.35,1.75,'SOLO OR\nCREW UP.','Play solo. Host. Join the crew.', ['menu'],menu=True)
add('settings',M,5.22,1.6,'YOUR SHIFT.\nYOUR SETUP.','Saved audio and mouse settings.\nControls when you need them.',[],menu=True)
add('sprint',M,14.25,3.9,'MOVE FAST.\nPACE YOURSELF.','Sprint burns stamina.\nCatch your breath before the next bag.', ['sprint','stamina'],[18,490,350,110])
add('crouch',M,21.45,3.4,'GET LOW.','Crouch changes your physical height.\nStand when there is room.', ['crouch'],[330,180,580,420])
add('jump',M,25.02,2.0,'TAKE A\nSHORTCUT.','Jump. Land. Keep moving.', ['jump'],[340,170,560,440])
add('random',I,9.8,3.0,'NO TWO BAGS\nTHE SAME.','Random belongings. Individual weights.\nA different shift, every time.', ['random_loot','random_weights'],[890,10,380,220])
add('neutral',I,13.05,2.3,'A SCAN IS\nJUST A CLUE.','Hidden truth stays hidden\nuntil you inspect.', ['hidden_probabilistic_truth'],[330,215,550,290])
add('key',I,15.55,3.5,'BEAT\nTHE LOCK.','Use the right tool.\nEnter the sequence before time runs out.', ['timed_locks'],[365,220,555,230])
add('lookalike',I,19.2,2.4,'SUSPICIOUS?\nMAYBE NOT.','A legal lookalike is still legal.\nInspection beats assumptions.', ['hidden_probabilistic_truth'],[320,170,650,400])
add('durability',I,27.1,3.1,'TOOLS\nWEAR OUT.','Failed attempts use real durability.\nA worn key will not save the shift.', ['consumable_tools','tool_durability'],[18,485,350,155])
add('pliers',I,32.0,3.35,'NEED A\nBIGGER TOOL?','Pliers cut the lock.\nFour inputs. One ticking clock.', ['timed_locks','tool_durability'],[365,220,555,230])
add('close_relock',I,36.9,2.3,'CLOSE IT.\nSEAL IT.','Close inspected luggage.\nSpend a seal to relock it.', ['close_bag','relock'],[890,10,380,220])
add('browser',I,39.7,3.0,'CHOOSE\nANY ITEM.','Browse the contents.\nTake the item you actually want.', ['item_browser'],[320,160,650,420])
add('repack',I,43.8,3.6,'REPACK IT.\nFEEL THE WEIGHT.','Move belongings between open bags.\nEvery item adds its own mass.', ['arbitrary_repacking','additive_mass'],[320,160,650,420])
add('taxonomy',I,76.15,3.0,'KNOW\nTHE DIFFERENCE.','Narcotics. Organics. Customs goods.\nInspect the actual contents.', ['contraband_taxonomy'],[320,160,650,420])
add('wildlife',I,79.6,2.4,'SOME CARGO\nNEEDS CARE.','Protected wildlife is not a souvenir.\nKeep it safely in its carrier.', ['contraband_taxonomy'],[320,160,650,420],care=True)
add('weapons',I,54.0,4.0,'SECURE\nTHE WEAPONS.','Identify the training prop.\nHand it to specialist disposal.', ['weapon_disposal','contraband_taxonomy'],[320,190,650,370],tag='FICTIONAL TRAINING PROPS / 1.6x EDIT',rate=1.6)
add('explosives',I,61.4,4.0,'EXPLOSIVES?\nSPECIALIST DESK.','A separate disposal path.\nNot the departure gate.', ['explosive_disposal','contraband_taxonomy'],[320,190,650,370],tag='INERT FICTIONAL TRAINING PROPS / 1.6x EDIT',rate=1.6)
add('dangerous',I,69.0,4.0,'DANGEROUS\nDOES NOT FLY.','Secure hazardous training objects.\nEarn the disposal reward once.', ['dangerous_disposal','contraband_taxonomy'],[320,190,650,370],tag='FICTIONAL TRAINING PROPS / 1.6x EDIT',rate=1.6)
add('restock',I,85.45,4.0,'RESTOCK.\nBACK TO WORK.','Spend earned disposal money\non fresh tools and seals.', ['consumable_tools','tool_durability'],[320,190,650,370])
add('item_throw',I,109.0,2.8,'LOOSE ITEMS.\nREAL MOMENTUM.','Throw individual belongings.\nWatch where they land.', ['throw_items'],[500,300,370,280],tag='ACTUAL ITEM FLIGHT / 0.8x SLOW MOTION',rate=.8)
add('pile',I,94.1,2.8,'THAT PILE\nWAS SUPPORTING IT.','Remove the bottom bag.\nThe rest really falls.', ['physical_piles'],[340,170,590,460])
add('damage',I,116.9,2.7,'HANDLE\nWITH CARE.','Hard impacts damage baggage.\nThe damage stays with the case.', ['bag_damage'],[890,10,380,220])
add('injury',I,122.7,3.4,'MIND\nYOUR HEAD.','Falling luggage can hurt operators.\nNon-graphic workplace chaos.', ['player_injury'],[18,485,350,155])
add('first_aid',I,101.25,3.7,'FIRST AID.\nSECOND CHANCE.','Visit the first-aid station.\nGet back on baggage duty.', ['first_aid'],[18,485,350,155])
add('cat',C,4.05,3.6,'PRECIOUS\nCARGO.', 'Ventilated carriers.\nActual animals inside.', ['pet_carriers'],[340,170,560,420],care=True)
add('rabbit',C,26.2,3.3,'CATS.\nRABBITS.','Not another confiscation.\nAn animal-care handoff.', ['pet_carriers'],[340,170,560,420],care=True)
add('supplies',C,11.25,4.0,'ONE SHARED\nCARE STATION.','Collect finite food and water portions\nfor pets and your detection dog.', ['shared_food_water'],[330,120,620,470],care=True)
add('pet_feed',C,16.1,3.8,'FEED THEM.\nWATER THEM.','Hungry carrier animals need care\nbefore their handoff.', ['pet_feeding'],[330,170,620,430],care=True)
add('dog_care',C,41.1,5.35,'GOOD DOGS\nNEED BREAKS.','Hunger. Thirst. Food. Water. Rest.\nCare is part of the shift.', ['dog_hunger'],[18,335,305,150],care=True)
add('follow',C,52.2,3.6,'YOUR PARTNER\nFOLLOWS YOU.','Autonomous following\nthrough the real room.', ['follow'],[330,170,580,430],care=True)
add('patrol',C,56.5,3.8,'OR WORKS\nTHE PATROL.','Send the dog around the operator lane.\nIt navigates on its own.', ['patrol'],[330,170,580,430],care=True)
add('scent',C,122.1,4.4,'A BARK IS\nNOT A VERDICT.','Scent can miss. It can false-alarm.\nInspect before you decide.', ['probabilistic_scent'],[900,450,362,150],care=True)
add('dog_scan',C,68.25,4.5,'TRAINING\nPAYS OFF.','A harmless training scan earns XP.\nNow kennel training can unlock.', ['training_xp','scan_kennel'],[900,210,362,245],tag='FICTIONAL NON-IONIZING SCAN / NO ANIMAL HARM',care=True)
add('upgrades',C,95.9,5.5,'EARN IT.\nUPGRADE IT.','Buy scanner, kennel and terminal upgrades\nwith actual handoff earnings.', ['scan_kennel'],[340,175,555,440])
add('new_route',C,115.6,4.0,'BUILD A\nBIGGER SHIFT.','Open flight C and oversize routing.\nPut the new terminal to work.', [],[300,170,680,440])
# Co-op scenes are appended from their verified fresh-capture timeline.
if (P/'coop-scenes.json').exists():
    S.extend(json.loads((P/'coop-scenes.json').read_text()))
S.append(dict(id='end',duration=4.0,title='A CO-OP\nAIRPORT PROTOTYPE.',tag='CHECKED CHAOS / WORKING TITLE',copy='Real prototype footage.\nMore baggage. More ways to help your crew.',features=[],end=True))
(P/'storyboard.json').write_text(json.dumps(S,indent=2))
required=set(json.loads((P/'coverage-plan.json').read_text())['required_features'])
covered={f for s in S for f in s.get('features',[])}
print(json.dumps({'shots':len(S),'seconds':sum(round(s['duration']*24)/24 for s in S),'missing_features':sorted(required-covered)},indent=2))
