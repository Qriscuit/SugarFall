"""Map captured game sound events through the final edit, then sparsify the mix."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path

from build_mix import default_events, synth_foley

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_EDL = ROOT / 'outputs/trailer-v1-20261104/edit-decision-list.json'
GAMEPLAY = ROOT / 'outputs/trailer-v1-20261104/gameplay'
OUTPUT = ROOT / 'outputs/trailer-v1-20261104/audio/cues-synced.json'
GAME_END = 27.233
GAPS = {'peg': .25, 'cup': .50, 'launch': .80}
MATERIAL = {'launch', 'peg_hit', 'peg_break', 'cup_catch'}
KEEP_SPECIAL = {'prism', 'upgrade', 'jam_splash', 'ui_tap'}
GAINS = {'launch': .11, 'peg_hit': .21, 'peg_break': .33, 'cup_catch': .25,
         'prism': .32, 'upgrade': .30, 'jam_splash': .29, 'ui_tap': .23}


def event_group(event: dict) -> str:
    return {'peg_hit':'peg','peg_break':'peg','cup_catch':'cup','launch':'launch'}.get(event['event'],'special')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--edl', type=Path, default=DEFAULT_EDL)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()
    edl = json.loads(args.edl.read_text(encoding='utf-8-sig'))
    fps = edl['fps']
    candidates = []
    for segment_index, segment in enumerate(edl['segments']):
        capture_path = GAMEPLAY / segment['clip'] / 'clip.json'
        capture = json.loads(capture_path.read_text(encoding='utf-8-sig'))
        source_start = segment['source_start']
        source_end = source_start + segment['frames']/fps
        for event in capture['events']:
            name = event['event']
            if name not in MATERIAL | KEEP_SPECIAL:
                continue
            source_time = float(event['time'])
            if source_time < source_start-1e-5 or source_time >= source_end-1e-5:
                continue
            time = segment['edit_start'] + source_time-source_start
            if time < 0 or time >= GAME_END:
                continue
            area = event['area']
            filename = f'{area}_{name}' if name in MATERIAL else name
            cue = dict(time=round(time,7), file=f'PLINKO/data/audio/feedback/{filename}.wav',
                gain=GAINS[name],pan=0,label=f'{area}: {name}',type='game_sfx',
                event=name,area=area,source_clip=segment['clip'],source_time=source_time,
                edit_segment=segment_index,edit_frame=round(time*fps),
                pitch=float(event.get('options',{}).get('pitch',1)))
            assert (ROOT/cue['file']).is_file(), cue['file']
            candidates.append(cue)

    # Collapse simultaneous events first. A break takes precedence over a hit;
    # a featured special sound takes precedence over all incidental events.
    priority = {'prism':0,'upgrade':0,'jam_splash':0,'ui_tap':0,'peg_break':1,
                'peg_hit':2,'cup_catch':3,'launch':4}
    per_frame = {}
    for event in sorted(candidates,key=lambda e:(e['edit_frame'],priority[e['event']],e['time'])):
        per_frame.setdefault(event['edit_frame'],event)
    unique = list(per_frame.values())
    selected = [event for event in unique if event['event'] in KEEP_SPECIAL]

    # Select breaks before fills so a nearby earlier tick cannot hide the last
    # peg breaking. All retained events remain at their captured source times.
    for group in ['peg','cup','launch']:
        group_candidates = [event for event in unique if event_group(event)==group]
        group_candidates.sort(key=lambda e:(0 if e['event']=='peg_break' else 1,e['time']))
        chosen = []
        for event in group_candidates:
            if any(abs(event['time']-other['time']) < GAPS[group]-1e-5 for other in chosen):
                continue
            chosen.append(event)
        selected.extend(chosen)
    selected.sort(key=lambda event:event['time'])
    synth_foley()
    foley = [event for event in default_events() if event['type']=='original_foley']
    events = sorted(selected+foley,key=lambda event:event['time'])

    observed = {}
    for group,gap in GAPS.items():
        times = sorted(event['time'] for event in selected if event_group(event)==group)
        differences = [b-a for a,b in zip(times,times[1:])]
        minimum = min(differences) if differences else None
        assert minimum is None or minimum >= gap-1e-5
        observed[group]=dict(required_gap_seconds=gap,minimum_gap_seconds=round(minimum,6) if minimum else None,count=len(times))
    assert all(event['time']<GAME_END for event in selected)
    assert len({event['edit_frame'] for event in selected})==len(selected)
    report = dict(events=events,source_edl=str(args.edl.relative_to(ROOT)).replace('\\','/'),
        mapping='edit_start + captured event time - segment source_start; original speed',
        game_audio_stop=GAME_END,raw_mapped_event_count=len(candidates),
        unique_frame_event_count=len(unique),selected_game_event_count=len(selected),
        selected_foley_count=len(foley),counts=dict(Counter(event['event'] for event in selected)),
        gaps=observed,special_events=[event for event in selected if event['event'] in KEEP_SPECIAL],
        note='Real captured timing, sparse event selection, breaks preferred over hits in the same frame. Mabel Foley pans toward her right-side overlay.')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report[key] for key in ['raw_mapped_event_count','selected_game_event_count','selected_foley_count','counts','gaps','game_audio_stop']},indent=2))


if __name__ == '__main__':
    main()
