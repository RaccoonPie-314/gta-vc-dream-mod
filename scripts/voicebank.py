#!/usr/bin/env python3
"""Extract GTA VC voice sets from sfx.SDT/sfx.RAW into per-voice WAVs and a manifest.

Voice samples are 16-bit mono; the SDT table is 9941 little-endian records of
{offset, size, rate, loop_start, loop_end}. Names come from the eSfxSample enum,
whose order is the table order.
"""

import argparse
import json
import math
import re
import struct
import sys
import wave
from array import array
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import median

REPO = Path(__file__).resolve().parent.parent
DEFAULT_HEADER = REPO / "reVC/src/audio/AudioSamples.h"
DEFAULT_LOGIC = REPO / "reVC/src/audio/AudioLogic.cpp"
DEFAULT_GAME = Path.home() / "Games/VC"

NAME_RE = re.compile(r"\bSFX_[A-Z0-9_]+\b")
LAW_RE = re.compile(r"^(COP|SWAT|FBI|MEDIC|FIREMAN|ARMY|VICE)_VOICE_(\d+)_(.+)$")
TRAILING_NUM_RE = re.compile(r"_\d+$")

BUCKETS = {
    "player": {
        "calm": ["CALM"],
        "angry": ["ANGRY", "PISSED"],
        "taunt": ["WISECRACKING", "GANG"],
    },
    "ped": {
        "neutral": ["CHAT"],
        "angry": ["FIGHT", "BUMP", "EYEING"],
        "panic": ["DODGE", "CAR_CRASH", "GENERIC_CRASH"],
    },
    "law": {
        "order": ["ARREST", "COP_TARGETING", "PULLOUTWEAPON", "COP_ASK_FOR_ID"],
        "tense": ["GUNAIMEDAT2", "GUNAIMEDAT3", "COP_ALONE", "COP_MANYCOPSAROUND", "SAVED"],
        "fight": ["FIGHT", "DODGE"],
    },
}


def parse_names(header_text):
    start = header_text.index("enum eSfxSample")
    body = header_text[start:]
    body = body[body.index("{") + 1:body.index("};")]
    body = re.sub(r"//[^\n]*", "", body)
    names, seen = [], set()
    for match in NAME_RE.finditer(body):
        name = match.group(0)
        if name not in seen:
            seen.add(name)
            names.append(name)
    return names


def parse_ped_bounds(header_text):
    head = header_text[header_text.index("// shorthands"):]
    first = re.search(r"SAMPLEBANK_PED_START\s*=\s*(SFX_[A-Z0-9_]+)\s*\+\s*1", head)
    last = re.search(r"SAMPLEBANK_PED_END\s*=\s*(SFX_[A-Z0-9_]+)", head)
    if not first or not last:
        sys.exit("could not find SAMPLEBANK_PED_START/END in header")
    return first.group(1), last.group(1)


def classify(name):
    name = name[4:] if name.startswith("SFX_") else name
    law = LAW_RE.match(name)
    if law:
        group, variant, rest = law.groups()
        return f"{group}_V{variant}", "law", TRAILING_NUM_RE.sub("", rest)
    if name.startswith("PLAYER_"):
        return "PLAYER", "player", TRAILING_NUM_RE.sub("", name[len("PLAYER_"):])
    token, _, rest = name.partition("_")
    if token == "POLICE":
        return "POLICE", "radio", TRAILING_NUM_RE.sub("", rest)
    return token, "ped", TRAILING_NUM_RE.sub("", rest)


def read_table(sdt_path):
    data = sdt_path.read_bytes()
    if len(data) % 20:
        sys.exit(f"SDT size {len(data)} is not a multiple of 20")
    return [struct.unpack_from("<IIIIi", data, i) for i in range(0, len(data), 20)]


def active_rms_dbfs(pcm, rate):
    step = max(1, int(rate * 0.02)) * 2
    levels = []
    for pos in range(0, len(pcm) - step + 1, step):
        chunk = array("h")
        chunk.frombytes(pcm[pos:pos + step])
        if sys.byteorder == "big":
            chunk.byteswap()
        rms = math.sqrt(sum(v * v for v in chunk) / len(chunk))
        if rms > 0:
            levels.append(20 * math.log10(rms / 32768))
    if not levels:
        return None
    active = [level for level in levels if level > -50]
    return round(median(active or levels), 1)


def clipped_fraction(pcm):
    samples = array("h")
    samples.frombytes(pcm)
    if sys.byteorder == "big":
        samples.byteswap()
    if not samples:
        return 0.0
    hits = sum(1 for v in samples if v >= 32700 or v <= -32700)
    return round(hits / len(samples), 5)


def pick_references(kind, samples):
    if kind not in BUCKETS:
        return {}
    buckets = BUCKETS[kind]
    chosen = {}
    for bucket, categories in buckets.items():
        candidates = [s for s in samples
                      if any(s["category"].startswith(c) for c in categories)
                      and s["clipped"] < 0.001 and s["seconds"] >= 1.0]
        def score(sample):
            duration = sample["seconds"]
            return duration if 2.0 <= duration <= 8.0 else duration * 0.5
        candidates.sort(key=score, reverse=True)
        chosen[bucket] = candidates[:3]
    return chosen


def parse_model_routing(logic_path):
    if not logic_path or not logic_path.exists():
        return {}
    text = logic_path.read_text()
    switch = re.search(r"GetPedCommentSfx\(CPed \*ped.*?\n}", text, re.S)
    if not switch:
        return {}
    cases = dict(re.findall(r"case MI_(\w+):\s*return (Get\w+TalkSfx)\(", switch.group(0)))

    resolved = {}
    for model, func in cases.items():
        seen, current = set(), func
        while current not in seen:
            seen.add(current)
            body = re.search(rf"{current}\(CPed \*ped, uint16 sound\)\s*\{{(.*?)\n\}}", text, re.S)
            if not body:
                break
            body = body.group(1)
            direct = NAME_RE.search(body)
            if direct:
                set_id, kind, _ = classify(direct.group(0))
                variants = 1
                if kind == "law":
                    mod = re.search(r"%\s*(\d+)", body)
                    variants = int(mod.group(1)) if mod else 1
                    base = set_id.rsplit("_V", 1)[0]
                    sets = [f"{base}_V{n}" for n in range(1, variants + 1)]
                else:
                    sets = [set_id]
                resolved[model] = {
                    "function": func,
                    "sets": sets,
                    "variants": variants,
                }
                break
            call = re.search(r"return (Get\w+TalkSfx)\(", body)
            if not call:
                break
            current = call.group(1)
    return resolved


def build(game, header, logic, out_dir, only, make_wavs, force=False):
    sdt_path = game / "audio/sfx.SDT"
    raw_path = game / "audio/sfx.RAW"
    for path in (sdt_path, raw_path, header):
        if not path.exists():
            sys.exit(f"missing: {path}")

    header_text = header.read_text()
    names = parse_names(header_text)
    table = read_table(sdt_path)
    if len(names) != len(table):
        sys.exit(f"name/table mismatch: {len(names)} names vs {len(table)} entries")
    raw_size = raw_path.stat().st_size
    if sum(entry[1] for entry in table) != raw_size:
        sys.exit("SDT sizes do not sum to sfx.RAW size; table is misaligned")

    start_name, end_name = parse_ped_bounds(header_text)
    lo, hi = names.index(start_name) + 1, names.index(end_name) + 1

    voices = defaultdict(list)
    with raw_path.open("rb") as raw:
        for index in range(lo, hi):
            name = names[index]
            set_id, kind, category = classify(name)
            if only and set_id not in only:
                continue
            offset, size, rate, _, _ = table[index]
            if size <= 0 or not 8000 <= rate <= 48000 or offset + size > raw_size:
                continue
            raw.seek(offset)
            pcm = raw.read(size)
            seconds = round(size / 2 / rate, 3)
            voices[set_id].append({
                "name": name,
                "index": index,
                "offset": offset,
                "bytes": size,
                "rate": rate,
                "seconds": seconds,
                "clipped": clipped_fraction(pcm),
                "rms_dbfs": active_rms_dbfs(pcm, rate),
                "category": category,
                "_pcm": pcm,
                "_kind": kind,
            })

    routing = parse_model_routing(logic)
    models = defaultdict(list)
    for model, info in routing.items():
        for set_id in info["sets"]:
            models[set_id].append(model)

    manifest = {
        "schema": 1,
        "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": {
            "sdt": str(sdt_path),
            "raw": str(raw_path),
            "samples_header": str(header),
            "entries": len(table),
            "raw_bytes": raw_size,
            "voice_range": [lo, hi - 1],
        },
        "format": {"bits": 16, "channels": 1, "note": "written at each sample's native rate"},
        "voices": {},
        "model_routing": routing,
    }

    for set_id in sorted(voices):
        samples = voices[set_id]
        kind = samples[0]["_kind"]
        rate = Counter(s["rate"] for s in samples).most_common(1)[0][0]
        references = pick_references(kind, samples)
        folder = out_dir / "voices" / set_id
        if make_wavs:
            folder.mkdir(parents=True, exist_ok=True)
        for sample in samples:
            pcm = sample.pop("_pcm")
            sample.pop("_kind")
            if make_wavs:
                target = folder / f"{sample['name']}.wav"
                if not target.exists() or force:
                    with wave.open(str(target), "wb") as handle:
                        handle.setnchannels(1)
                        handle.setsampwidth(2)
                        handle.setframerate(sample["rate"])
                        handle.writeframes(pcm)
        manifest["voices"][set_id] = {
            "kind": kind,
            "models": sorted(models.get(set_id, [])),
            "rate": rate,
            "sample_count": len(samples),
            "seconds": round(sum(s["seconds"] for s in samples), 2),
            "categories": dict(sorted(Counter(s["category"] for s in samples).items())),
            "references": {
                bucket: [f"voices/{set_id}/{s['name']}.wav" for s in picks]
                for bucket, picks in references.items()
            },
            "samples": samples,
        }

    if make_wavs:
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def print_stats(manifest):
    voices = manifest["voices"]
    total = sum(v["seconds"] for v in voices.values())
    print(f"voices: {len(voices)}   samples: {sum(v['sample_count'] for v in voices.values())}"
          f"   speech: {total / 60:.1f} min")
    print(f"{'set':<12} {'kind':<7} {'lines':>5} {'min':>6} {'rate':>6}  models")
    for set_id, voice in voices.items():
        models = ",".join(voice["models"]) or "-"
        print(f"{set_id:<12} {voice['kind']:<7} {voice['sample_count']:>5} "
              f"{voice['seconds'] / 60:>6.1f} {voice['rate']:>6}  {models}")


def load_manifest(game, header, logic, out_dir):
    path = out_dir / "manifest.json"
    if path.exists():
        return json.loads(path.read_text())
    return build(game, header, logic, out_dir, set(), make_wavs=False)


def lookup(manifest, out_dir, target):
    voices = manifest["voices"]
    routing = manifest["model_routing"]
    key = target.upper()
    key = key[3:] if key.startswith("MI_") else key
    if key in routing:
        info = routing[key]
        print(f"model {key} -> {info['function']}, {info['variants']} variant(s)")
        set_ids = info["sets"]
    elif key in voices:
        set_ids = [key]
    else:
        set_ids = sorted(v for v in voices if key in v)
    if not set_ids:
        print(f"no voice set for {target}")
        return 1
    for set_id in set_ids:
        if set_id not in voices:
            print(f"{set_id}: routed but not present in this manifest")
            continue
        voice = voices[set_id]
        print(f"\n{set_id}  {voice['kind']}  {voice['sample_count']} clips  "
              f"{voice['seconds'] / 60:.1f} min  {voice['rate']} Hz")
        print(f"  models: {', '.join(voice['models']) or '-'}")
        print(f"  delivery: {', '.join(f'{c} {n}' for c, n in voice['categories'].items())}")
        for bucket, paths in voice["references"].items():
            names = ", ".join(p.rsplit("/", 1)[-1] for p in paths) or "no candidate"
            print(f"  refs/{bucket}: {names}")
        generated = sorted((out_dir / "generated" / set_id).glob("*.wav"))
        print(f"  generated: {', '.join(p.name for p in generated) if generated else 'none'}")
    return 0


def verify(out_dir, manifest):
    raw_path = Path(manifest["source"]["raw"])
    raw = raw_path.open("rb")
    bad = 0
    checked = 0
    for set_id, voice in manifest["voices"].items():
        for sample in voice["samples"]:
            path = out_dir / "voices" / set_id / f"{sample['name']}.wav"
            checked += 1
            if not path.exists():
                print(f"missing {path}")
                bad += 1
                continue
            with wave.open(str(path), "rb") as handle:
                frames = handle.getnframes()
                rate = handle.getframerate()
                pcm = handle.readframes(frames)
            raw.seek(sample["offset"])
            if pcm != raw.read(sample["bytes"]) or rate != sample["rate"]:
                print(f"mismatch {path}")
                bad += 1
    raw.close()
    print(f"checked {checked} files, {bad} problems")
    return 1 if bad else 0


def main():
    parser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        epilog="Cutscene workflow rules: docs/specs/2026-11-07-cutscene-voice-guide.md",
    )
    parser.add_argument("command", choices=["stats", "dump", "verify", "lookup"])
    parser.add_argument("target", nargs="?", help="model or voice set id, for lookup")
    parser.add_argument("--game", type=Path, default=DEFAULT_GAME)
    parser.add_argument("--header", type=Path, default=DEFAULT_HEADER)
    parser.add_argument("--logic", type=Path, default=DEFAULT_LOGIC)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--set", action="append", default=[], help="limit to this set id (repeatable)")
    parser.add_argument("--force", action="store_true", help="overwrite existing WAVs")
    args = parser.parse_args()

    force = args.force
    out_dir = args.out or args.game / "voice-library"
    only = set(args.set)

    if args.command == "verify":
        manifest = json.loads((out_dir / "manifest.json").read_text())
        return verify(out_dir, manifest)

    if args.command == "lookup":
        if not args.target:
            parser.error("lookup needs a model or set id")
        manifest = load_manifest(args.game, args.header, args.logic, out_dir)
        return lookup(manifest, out_dir, args.target)

    manifest = build(args.game, args.header, args.logic, out_dir, only,
                     make_wavs=args.command == "dump", force=force)
    print_stats(manifest)
    if args.command == "dump":
        print(f"written: {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
