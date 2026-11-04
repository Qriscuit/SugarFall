"""Build the private trailer-review mix from an unchanged local music reference.

The new Foley is deterministic synthesis. No third-party samples are used for it.
The provided Beethoven performance remains an unlicensed-for-publication reference.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
RATE = 48_000
SECONDS = 30
FRAMES = RATE * SECONDS
DEFAULT_FFMPEG = ROOT / 'tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
BASE = Path(__file__).resolve().parent
OUTPUT = ROOT / 'outputs/trailer-v1-20261104'
WORK = ROOT / 'verification/trailer-v1-20261104/audio'
SOURCE = ROOT / 'AudioContent/Symphony 6 - beethoven cut - Sugarfall.wav'
SOURCE_SHA = '3d654f3a5fefd2d1d7216730c499991235c1fc06e27502b4653c648a76319e11'


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_wav(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if samples.ndim == 1:
        samples = samples[:, None]
    pcm = np.rint(np.clip(samples, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(samples.shape[1])
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def read_pcm(path: Path) -> np.ndarray:
    with wave.open(str(path), 'rb') as stream:
        assert stream.getframerate() == RATE and stream.getsampwidth() == 2
        return np.frombuffer(stream.readframes(stream.getnframes()), dtype='<i2').astype(np.float64).reshape(-1, stream.getnchannels()) / 32768


def noise_band(rng: np.random.Generator, count: int, lo: float, hi: float) -> np.ndarray:
    noise = rng.standard_normal(count)
    spectrum = np.fft.rfft(noise)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    lo_edge = np.clip((frequencies - lo * .5) / max(lo * .5, 1), 0, 1)
    hi_edge = np.clip((hi * 1.25 - frequencies) / max(hi * .25, 1), 0, 1)
    result = np.fft.irfft(spectrum * lo_edge * hi_edge, n=count)
    return result / max(np.max(np.abs(result)), 1e-12)


def synth_foley() -> list[dict]:
    folder = BASE / 'foley'
    folder.mkdir(exist_ok=True)
    rng = np.random.default_rng(20261104)
    result = []
    for name, duration in [('food_landing', .18), ('shoe_step', .13), ('paper_rustle', .48), ('tray_settle', .34)]:
        t = np.arange(round(duration * RATE)) / RATE
        if name == 'food_landing':
            attack = 1 - np.exp(-t * 1100)
            signal = attack * (np.sin(2*np.pi*(115*t-45*t*t)) * np.exp(-t*32) + .25*np.sin(2*np.pi*220*t)*np.exp(-t*45))
            signal += noise_band(rng, len(t), 80, 1200) * np.exp(-t*48) * .22
            peak = .46
        elif name == 'shoe_step':
            signal = np.sin(2*np.pi*145*t)*np.exp(-t*48)*(1-np.exp(-t*1800))
            signal += noise_band(rng, len(t), 180, 2400) * np.exp(-t*55) * .55
            peak = .34
        elif name == 'paper_rustle':
            shape = .30*np.exp(-((t-.075)/.045)**2) + .46*np.exp(-((t-.195)/.05)**2) + .22*np.exp(-((t-.31)/.045)**2)
            signal = noise_band(rng, len(t), 500, 6500) * shape
            signal += noise_band(rng, len(t), 250, 1200) * np.sin(np.pi*t/duration)**2 * .08
            peak = .25
        else:
            signal = np.zeros_like(t)
            for frequency, gain, decay in [(680, 1, 25), (1080, .42, 22), (1730, .20, 28), (2300, .08, 35)]:
                signal += gain*np.sin(2*np.pi*frequency*t)*np.exp(-t*decay)
            signal += .5*np.sin(2*np.pi*140*t)*np.exp(-t*45)
            signal *= 1 - np.exp(-t*1800)
            peak = .32
        signal *= np.minimum(t/.003, 1) * np.minimum((duration-t)/.012, 1)
        signal *= peak / max(np.max(np.abs(signal)), 1e-12)
        path = folder / (name + '.wav')
        write_wav(path, signal)
        result.append(dict(file=str(path.relative_to(ROOT)).replace('\\','/'), duration=duration, sha256=sha(path), origin='Original deterministic procedural Foley, no external sample'))
    return result


def default_events() -> list[dict]:
    plan = json.loads((ROOT/'concept-art/trailer-storyboard-v1/storyboard.json').read_text(encoding='utf-8'))
    events = []
    for cue in plan['audio_events']:
        events.append(dict(time=cue['time'], file='PLINKO/data/audio/feedback/'+Path(cue['file']).name,
                           gain=cue['gain'], pan=0, label=cue['label'], type='game_sfx'))
    for time, name, gain, pan, label in [
        (17.9667,'food_landing',.56,.25,'Mabel first doughnut catch'),
        (18.8500,'food_landing',.60,.25,'Mabel second doughnut catch'),
        (19.7667,'food_landing',.65,.25,'Mabel third doughnut catch'),
        (19.89,'shoe_step',.40,.30,'Mabel first balancing step'),
        (20.14,'shoe_step',.43,.35,'Mabel second balancing step'),
        (19.84,'paper_rustle',.38,.30,'Mabel paper movement'),
        (27.60,'tray_settle',.45,.25,'Mabel steadies tray beside title'),
    ]:
        events.append(dict(time=time, file=f'concept-art/trailer-v1/audio/foley/{name}.wav', gain=gain,
                           pan=pan, label=label, type='original_foley'))
    return sorted(events, key=lambda item:item['time'])


def smooth_gate(t: np.ndarray, start: float, end: float, ramp: float) -> np.ndarray:
    fade_in = np.clip((t-start)/ramp, 0, 1)
    fade_out = np.clip((end-t)/ramp, 0, 1)
    return np.minimum(fade_in, fade_out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', type=Path, default=DEFAULT_FFMPEG)
    parser.add_argument('--cues', type=Path, help='JSON list or object with events list; replaces default event timings')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    assert SOURCE.is_file() and sha(SOURCE) == SOURCE_SHA, 'Unexpected or modified source music'
    assert args.ffmpeg.is_file(), 'Portable FFmpeg executable not found'
    foley = synth_foley()
    cues = default_events() if args.cues is None else json.loads(args.cues.read_text(encoding='utf-8-sig'))
    if isinstance(cues, dict):
        cues = cues['events']
    (OUTPUT/'audio').mkdir(exist_ok=True)
    (OUTPUT/'audio/cues.json').write_text(json.dumps(dict(events=cues), indent=2)+'\n', encoding='utf-8')
    music48 = WORK/'music-48k-reference.wav'
    subprocess.run([str(args.ffmpeg),'-hide_banner','-loglevel','error','-y','-i',str(SOURCE),'-t','30',
                    '-ar',str(RATE),'-ac','2','-c:a','pcm_s16le',str(music48)], check=True,
                   creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    music = read_pcm(music48)[:FRAMES]
    assert music.shape == (FRAMES,2)
    t = np.arange(FRAMES)/RATE
    gain = np.full(FRAMES, .90)
    gain *= 1 - .32*smooth_gate(t,17.45,20.76,.12)
    for event in cues:
        if event.get('type') == 'game_sfx':
            gain *= 1 - .10*smooth_gate(t,event['time']-.025,event['time']+.17,.025)
    gain *= np.clip((SECONDS-t)/.30,0,1)
    mix = music*gain[:,None]
    event_report = []
    for index,event in enumerate(cues):
        path = ROOT / event['file']
        assert path.is_file(), path
        assert 0 <= event['time'] < SECONDS and 0 <= event.get('gain',1) <= 2
        temp = WORK/f'event-{index:02d}.wav'
        pitch = float(event.get('pitch', 1))
        assert .5 <= pitch <= 2
        filters = f'aresample={RATE},asetrate={RATE}*{pitch:.8f},aresample={RATE}'
        subprocess.run([str(args.ffmpeg),'-hide_banner','-loglevel','error','-y','-i',str(path),
                        '-af',filters,'-ar',str(RATE),'-ac','1','-c:a','pcm_s16le',str(temp)],check=True,
                       creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        sample = read_pcm(temp)[:,0] * event.get('gain',1)
        pan = float(np.clip(event.get('pan',0),-1,1))
        left = np.sqrt((1-pan)/2)
        right = np.sqrt((1+pan)/2)
        stereo = np.column_stack([sample*left,sample*right])
        start = round(event['time']*RATE)
        count = min(len(stereo),FRAMES-start)
        mix[start:start+count] += stereo[:count]
        event_report.append({**event,'source_sha256':sha(path),'rendered_frames':count})
    peak_before = float(np.max(np.abs(mix)))
    normalization = min(1,.94/max(peak_before,1e-12))
    mix *= normalization
    target = OUTPUT/'trailer-v1-mix.wav'
    write_wav(target,mix)
    reloaded = read_pcm(target)
    peak = float(np.max(np.abs(reloaded)))
    rms = float(np.sqrt(np.mean(reloaded*reloaded)))
    assert len(reloaded) == FRAMES and peak <= .95 and not np.any(np.abs(reloaded)>=1)
    assert sha(SOURCE) == SOURCE_SHA
    report = dict(status='PRIVATE REVIEW MIX; provided performance publication permission not established',
        original_source=str(SOURCE.relative_to(ROOT)).replace('\\','/'),original_source_sha256=SOURCE_SHA,
        original_source_unchanged=True, music_source_range=[0,30],music_speed=1,
        source_performance_metadata='HALIDONMUSIC / The Best of Beethoven / 2025',
        output=target.as_posix(), output_sha256=sha(target),seconds=SECONDS,sample_rate=RATE,channels=2,
        bit_depth=16,peak=round(peak,7),rms_dbfs=round(20*np.log10(max(rms,1e-12)),3),
        peak_before_normalization=round(peak_before,7),normalization_gain=round(normalization,7),clipped_samples=0,
        music_gain=.90,mabel_music_duck_db=round(20*np.log10(.68),3),mabel_duck_range=[17.45,20.76],
        fade_out=[29.7,30], events=event_report,original_foley=foley,
        ffmpeg=args.ffmpeg.as_posix(),ffmpeg_binary_sha256=sha(args.ffmpeg),
        cue_source=args.cues.as_posix() if args.cues else 'Default storyboard cue list',
        note='Capture-synced cue input used.' if args.cues else 'Default storyboard timing; rerun --cues with captured event times before final mux.')
    (OUTPUT/'audio/mix-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report[key] for key in ['output','seconds','sample_rate','channels','peak','rms_dbfs','normalization_gain','clipped_samples']},indent=2))


if __name__ == '__main__':
    main()
