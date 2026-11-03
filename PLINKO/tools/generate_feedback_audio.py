"""Original Sugarfall PCM Foley/chimes. Deterministic offline composition only."""
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / "data/audio/feedback"
RATE = 24000
TAU = math.tau
VERSION = 1


def tone(buffer, at, length, frequency, strength=1.0, material="soft", bend=0.0):
    partials = {"soft": [(1,1),(2,.16),(3,.035)],
                "wood": [(1,1),(1.98,.22),(3.12,.08)],
                "ceramic": [(1,1),(2.71,.21),(4.12,.055)],
                "candy": [(1,1),(2,.23),(3.01,.085),(4,.02)]}[material]
    start = round(at * RATE)
    count = round(length * RATE)
    for i in range(count):
        if start+i >= len(buffer): break
        t = i / RATE
        edge = min(1.0, t/.004) * min(1.0, (count-1-i)/(RATE*.018))
        decay = math.exp(-t/(length*.25))
        phase = TAU * (frequency*t + .5*bend*t*t)
        value = sum(weight*math.sin(phase*multiple)*math.exp(-t*multiple/length*.35)
                    for multiple,weight in partials)
        buffer[start+i] += value * decay * max(0,edge) * strength


def crumb(buffer, at, length, strength, rng):
    start = round(at * RATE)
    count = round(length * RATE)
    smooth = 0.0
    for i in range(count):
        if start+i >= len(buffer): break
        smooth = .78*smooth + .22*rng.uniform(-1,1)
        t = i / RATE
        edge = min(1.0,t/.004)*max(0,min(1.0,(count-1-i)/(RATE*.015)))
        buffer[start+i] += smooth * math.exp(-t/(length*.24)) * strength * edge


def render(name, duration, notes, noise=0.0, peak=.28):
    rng = random.Random(int.from_bytes(hashlib.sha256(name.encode()).digest()[:8],"little"))
    buffer = [0.0]*round(RATE*duration)
    for at,length,hz,strength,material,bend in notes:
        tone(buffer,at,length,hz,strength,material,bend)
    if noise: crumb(buffer,0,min(duration,.22),noise,rng)
    # Quiet, short reflections give body without a persistent ambience track.
    dry = buffer[:]
    for delay,gain in [(.011,.055),(.023,.025)]:
        offset=round(delay*RATE)
        for i in range(offset,len(buffer)): buffer[i]+=dry[i-offset]*gain
    for i in range(len(buffer)-round(.022*RATE),len(buffer)):
        buffer[i] *= max(0,(len(buffer)-1-i)/(.022*RATE))
    maximum = max(abs(v) for v in buffer)
    scale = peak/maximum if maximum else 0
    values = [max(-32767,min(32767,round(v*scale*32767))) for v in buffer]
    values[0]=values[-1]=0
    path=OUTPUT/(name+".wav")
    with wave.open(str(path),"wb") as file:
        file.setnchannels(1);file.setsampwidth(2);file.setframerate(RATE)
        file.writeframes(struct.pack("<"+"h"*len(values),*values))
    # Lossless PCM imports keep the source and mixer relationship inspectable.
    descriptor=path.with_suffix(".wav.import")
    if not descriptor.exists():
        descriptor.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\nforce/8_bit=false\nforce/mono=true\nforce/max_rate=false\nforce/max_rate_hz=24000\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n',encoding="utf-8")
    return {"path":path.relative_to(PROJECT).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes":path.stat().st_size,"duration":duration,"frames":len(values),"rate":RATE,"channels":1,"bits":16,
            "peak":max(abs(v) for v in values)/32767,"rms":math.sqrt(sum((v/32767)**2 for v in values)/len(values))}


def note(at,hz,length=.17,strength=1,material="soft",bend=0): return (at,length,hz,strength,material,bend)


def main():
    OUTPUT.mkdir(parents=True,exist_ok=True)
    specs = {
        "ui_tap":(.10,[note(0,420,.09,material="wood")],.05),
        "ui_back":(.18,[note(0,510,.14),note(.045,380,.12,.48)],0),
        "ui_confirm":(.27,[note(0,523,.20),note(.06,659,.20,.7)],0),
        "ui_error":(.23,[note(0,294,.16,material="wood"),note(.08,262,.14,.6,"wood")],0),
        "upgrade":(.37,[note(0,523,.24),note(.065,659,.23,.8),note(.13,784,.23,.7)],0),
        "ability_purchase":(.65,[note(0,392,.36),note(.075,523,.36,.8),note(.15,659,.35,.7),note(.24,784,.38,.6)],0),
        "run_start":(.39,[note(0,392,.22),note(.075,523,.24,.8),note(.15,659,.23,.65)],0),
        "pause":(.22,[note(0,440,.18),note(.055,330,.16,.55)],0),
        "resume":(.24,[note(0,330,.17),note(.055,440,.18,.65)],0),
        "pickup_appear":(.11,[note(0,740,.09,.65,"candy")],0),
        "time_pickup":(.40,[note(0,659,.25,material="candy"),note(.085,880,.28,.65,"candy")],0),
        "prism":(.52,[note(0,523,.32,material="candy"),note(.07,784,.32,.7,"candy"),note(.16,1046.5,.32,.5,"candy")],0),
        "jam_splash":(.25,[note(0,215,.19,bend=700),note(.045,330,.18,.5,"wood")],.55),
        "twin_transform":(.62,[note(0,330,.28,material="ceramic"),note(.085,440,.3,.7,"ceramic"),note(.17,659,.37,.6,"ceramic"),note(.22,784,.35,.4,"ceramic")],0),
        "tray_win":(.82,[note(0,392,.34),note(.12,523,.34,.8),note(.24,659,.34,.7),note(.36,784,.43,.7)],0),
        "tray_loss":(.62,[note(0,392,.30),note(.14,330,.30,.65),note(.28,262,.30,.50)],0),
        "collect":(.40,[note(0,523,.26,material="candy"),note(.06,659,.25,.7,"candy"),note(.12,784,.26,.55,"candy")],0),
        "special_split":(.25,[note(0,460,.16),note(.045,690,.18,.7),note(.07,575,.16,.5)],.08),
        "special_impact":(.20,[note(0,165,.18,material="wood"),note(.012,330,.14,.5,"wood")],.22),
        "special_ricochet":(.19,[note(0,610,.17,material="ceramic",bend=350)],0),
        "countdown":(.13,[note(0,550,.11,material="wood")],0),
    }
    for area,material,base,noise in [("bakery","wood",270,.18),("gelato","ceramic",520,0),("crystal","candy",660,0)]:
        specs[area+"_launch"]=(.10,[note(0,base*.65,.08,.75,material,bend=base*.7)],noise*.3)
        specs[area+"_peg_hit"]=(.12,[note(0,base,.10,1,material)],noise)
        specs[area+"_peg_break"]=(.23,[note(0,base,.18,1,material),note(.035,base*1.5,.17,.5,material)],noise*2)
        specs[area+"_cup_catch"]=(.23,[note(0,base*.8,.19,1,material),note(.04,base*1.2,.17,.4,material)],noise*.2)
    assets=[render(name,*spec) for name,spec in sorted(specs.items())]
    report={"version":VERSION,"origin":"Original deterministic procedural PCM composition. No external samples, recordings, melodies or third-party sound assets.",
            "generator":"tools/generate_feedback_audio.py","generator_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "asset_count":len(assets),"pcm_bytes":sum(item["frames"]*2 for item in assets),"assets":assets,
            "normalization":"Each clip peak 0.28; controller adds conservative gains. Four-millisecond onset, tapered tail, no loops.",
            "human_listening_verified":False}
    (PROJECT/"docs/GAME_AUDIO_ASSETS.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"assets":len(assets),"pcm_bytes":report["pcm_bytes"],"max_peak":max(item["peak"] for item in assets)}))


if __name__=="__main__": main()
