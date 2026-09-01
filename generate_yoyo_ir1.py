#!/usr/bin/env python3
"""
Generate a fresh Yo-Yo Intermittent Recovery Test Level 1 (Yo-Yo IR1)
audio track from the protocol mathematics — no source audio required.

Default output:
  - 48 kHz
  - stereo
  - 24-bit PCM WAV
  - outdoor-oriented synthesized cues
  - 0.8 s pre-roll (starts almost immediately)
  - protocol cue manifest CSV
  - optional 320 kbps MP3 preview

Protocol implemented:
  - each repetition = 2 x 20 m
  - 10 s active recovery after each 40 m repetition
  - standard IR1 speed/stage progression through Level 23
  - exact 20 m leg time = 72 / speed_kmh seconds
  - exact 40 m run time = 144 / speed_kmh seconds

The script bootstraps its own Python virtual environment on CachyOS/Arch
(or most other Linux distros) and installs the Python dependencies it needs.

Usage:
    python generate_yoyo_ir1.py
    python generate_yoyo_ir1.py --output ~/Music/yoyo_ir1.wav
    python generate_yoyo_ir1.py --mp3
    python generate_yoyo_ir1.py --no-stage-chimes
    python generate_yoyo_ir1.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


APP_NAME = "yoyo-ir1-synth"
BOOTSTRAP_ENV = "YOYO_IR1_SYNTH_BOOTSTRAPPED"

# NumPy handles fast DSP, SciPy supplies high-quality chirp/window functions,
# and soundfile writes proper 24-bit PCM WAV without manual byte packing.
PIP_PACKAGES = [
    "numpy>=2.0",
    "scipy>=1.14",
    "soundfile>=0.13",
]


def _imports_available() -> bool:
    try:
        import numpy  # noqa: F401
        import scipy  # noqa: F401
        import soundfile  # noqa: F401
        return True
    except ImportError:
        return False


def _run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess:
    print("+", " ".join(str(x) for x in cmd))
    return subprocess.run(cmd, check=check)


def _arch_install(*packages: str) -> None:
    """Install system packages on CachyOS/Arch when genuinely needed."""
    if not shutil.which("pacman"):
        raise RuntimeError(
            f"Missing system dependency: {', '.join(packages)}\n"
            "Install it with your distribution package manager and rerun."
        )
    _run(["sudo", "pacman", "-S", "--needed", "--noconfirm", *packages])


def bootstrap_python_dependencies() -> None:
    """
    Re-exec this script inside a cached virtualenv if DSP packages are absent.

    This keeps the system Python clean, which is especially important on Arch.
    """
    if _imports_available():
        return

    if os.environ.get(BOOTSTRAP_ENV) == "1":
        raise RuntimeError(
            "Python dependencies are still unavailable after bootstrapping."
        )

    cache_dir = Path.home() / ".cache" / APP_NAME
    venv_dir = cache_dir / "venv"
    venv_python = venv_dir / "bin" / "python"

    print("DSP packages are missing; creating a private virtual environment:")
    print(f"  {venv_dir}")

    cache_dir.mkdir(parents=True, exist_ok=True)

    try:
        if not venv_python.exists():
            _run([sys.executable, "-m", "venv", str(venv_dir)])
    except subprocess.CalledProcessError:
        # Arch/CachyOS normally ships venv with Python, but recover if needed.
        if shutil.which("pacman"):
            print("Python venv support failed; refreshing Python/pip packages...")
            _arch_install("python", "python-pip")
            _run([sys.executable, "-m", "venv", str(venv_dir)])
        else:
            raise

    _run([str(venv_python), "-m", "pip", "install", "--upgrade", "pip", "wheel"])

    try:
        _run([str(venv_python), "-m", "pip", "install", *PIP_PACKAGES])
    except subprocess.CalledProcessError:
        # python-soundfile may need libsndfile on some Linux setups.
        if shutil.which("pacman"):
            print("Retrying after installing libsndfile...")
            _arch_install("libsndfile")
            _run([str(venv_python), "-m", "pip", "install", *PIP_PACKAGES])
        else:
            raise

    env = os.environ.copy()
    env[BOOTSTRAP_ENV] = "1"
    script_path = str(Path(__file__).resolve())
    os.execve(
        str(venv_python),
        [str(venv_python), script_path, *sys.argv[1:]],
        env,
    )


bootstrap_python_dependencies()

# Third-party imports happen only after bootstrap/re-exec.
import numpy as np
import soundfile as sf
from scipy.signal import chirp
from scipy.signal.windows import tukey


# ---------------------------------------------------------------------------
# Standard Yo-Yo IR1 schedule
# (level, speed_km_h, number_of_40m_repetitions)
# ---------------------------------------------------------------------------

IR1_STAGES: list[tuple[int, float, int]] = [
    (5, 10.0, 1),
    (9, 12.0, 1),
    (11, 13.0, 2),
    (12, 13.5, 3),
    (13, 14.0, 4),
    (14, 14.5, 8),
    (15, 15.0, 8),
    (16, 15.5, 8),
    (17, 16.0, 8),
    (18, 16.5, 8),
    (19, 17.0, 8),
    (20, 17.5, 8),
    (21, 18.0, 8),
    (22, 18.5, 8),
    (23, 19.0, 8),
]

RECOVERY_SECONDS = 10.0
LEG_METERS = 20.0
REP_METERS = 40.0

# Full reference-table endpoint:
REFERENCE_TOTAL_DISTANCE_M = 3640
REFERENCE_TOTAL_SECONDS = 1724.5808681506787  # ~28:44.58


@dataclass(frozen=True)
class Rep:
    level: int
    shuttle: int
    speed_kmh: float
    protocol_start: float
    turn: float
    recovery_start: float
    next_start: float
    cumulative_distance_m: int


@dataclass(frozen=True)
class Cue:
    file_time: float
    kind: str
    level: int | None = None
    shuttle: int | None = None


def build_protocol(max_level: int = 23) -> list[Rep]:
    reps: list[Rep] = []
    t = 0.0
    distance = 0

    selected = [stage for stage in IR1_STAGES if stage[0] <= max_level]
    if not selected:
        raise ValueError(f"max level {max_level} is below the first IR1 level.")

    for level, speed_kmh, repetitions in selected:
        # 20 m / (km/h converted to m/s) = 72 / speed_kmh
        leg_seconds = 72.0 / speed_kmh

        for shuttle in range(1, repetitions + 1):
            start = t
            turn = start + leg_seconds
            recovery_start = start + 2.0 * leg_seconds
            next_start = recovery_start + RECOVERY_SECONDS
            distance += int(REP_METERS)

            reps.append(
                Rep(
                    level=level,
                    shuttle=shuttle,
                    speed_kmh=speed_kmh,
                    protocol_start=start,
                    turn=turn,
                    recovery_start=recovery_start,
                    next_start=next_start,
                    cumulative_distance_m=distance,
                )
            )
            t = next_start

    return reps


def validate_protocol(reps: list[Rep], max_level: int) -> None:
    if max_level == 23:
        if reps[-1].cumulative_distance_m != REFERENCE_TOTAL_DISTANCE_M:
            raise RuntimeError(
                f"Protocol distance mismatch: {reps[-1].cumulative_distance_m} m"
            )
        if abs(reps[-1].next_start - REFERENCE_TOTAL_SECONDS) > 1e-9:
            raise RuntimeError(
                "Protocol timing mismatch: "
                f"{reps[-1].next_start:.9f} s vs "
                f"{REFERENCE_TOTAL_SECONDS:.9f} s"
            )


# ---------------------------------------------------------------------------
# Audio synthesis
# ---------------------------------------------------------------------------

def db_to_amp(db: float) -> float:
    return 10.0 ** (db / 20.0)


def smooth_tone(
    sample_rate: int,
    duration: float,
    f0: float,
    f1: float | None = None,
    *,
    harmonic_mix: float = 0.20,
    second_voice_ratio: float = 1.19,
    second_voice_mix: float = 0.12,
) -> np.ndarray:
    """
    Make a bright, speaker-friendly, click-free synthesized beep.

    The main tone is accompanied by:
      - a controlled second harmonic for projection
      - a quieter non-octave second voice to survive outdoor reflections

    The waveform is normalized BEFORE final track peak scaling, so there is
    no hard clipping.
    """
    n = max(1, int(round(duration * sample_rate)))
    tt = np.arange(n, dtype=np.float64) / sample_rate
    end_f = f0 if f1 is None else f1

    main = chirp(tt, f0=f0, f1=end_f, t1=max(duration, 1e-6), method="linear", phi=-90)

    h0 = f0 * 2.0
    h1 = end_f * 2.0
    harmonic = chirp(
        tt, f0=h0, f1=h1, t1=max(duration, 1e-6), method="linear", phi=-90
    )

    v0 = f0 * second_voice_ratio
    v1 = end_f * second_voice_ratio
    voice2 = chirp(
        tt, f0=v0, f1=v1, t1=max(duration, 1e-6), method="linear", phi=-90
    )

    y = main + harmonic_mix * harmonic + second_voice_mix * voice2

    # Tukey window gives a fast but smooth attack/release.
    alpha = min(1.0, max(0.06, 0.018 / max(duration, 1e-6)))
    y *= tukey(n, alpha=alpha)

    peak = float(np.max(np.abs(y)))
    if peak > 0:
        y /= peak

    return y.astype(np.float32)


def gap(sample_rate: int, seconds: float) -> np.ndarray:
    return np.zeros(max(0, int(round(seconds * sample_rate))), dtype=np.float32)


def concat(*parts: np.ndarray) -> np.ndarray:
    return np.concatenate(parts).astype(np.float32, copy=False)


def synth_cue(kind: str, sample_rate: int) -> np.ndarray:
    """
    Distinct phase cues.

    START:
        rising double beep = start next 2x20 m repetition
    TURN:
        single bright high beep = 20 m turnaround
    RECOVERY:
        descending double beep = 40 m completed; 10 s recovery begins
    LEVEL:
        three short rising pips = next repetition starts a new IR1 level
        (placed during recovery BEFORE the exact START cue)
    COUNTDOWN:
        simple pip
    FINISH:
        unmistakable descending 3-note sequence
    """
    if kind == "START":
        return concat(
            smooth_tone(sample_rate, 0.105, 1250, 1450),
            gap(sample_rate, 0.045),
            smooth_tone(sample_rate, 0.145, 1750, 2050),
        )

    if kind == "TURN":
        return smooth_tone(
            sample_rate, 0.190, 1950, 2050,
            harmonic_mix=0.22,
            second_voice_mix=0.14,
        )

    if kind == "RECOVERY":
        return concat(
            smooth_tone(sample_rate, 0.115, 2050, 1800),
            gap(sample_rate, 0.050),
            smooth_tone(sample_rate, 0.160, 1450, 1150),
        )

    if kind == "LEVEL":
        return concat(
            smooth_tone(sample_rate, 0.090, 900, 1050),
            gap(sample_rate, 0.055),
            smooth_tone(sample_rate, 0.090, 1200, 1400),
            gap(sample_rate, 0.055),
            smooth_tone(sample_rate, 0.110, 1550, 1850),
        )

    if kind == "COUNTDOWN":
        return smooth_tone(sample_rate, 0.120, 1050, 1150, harmonic_mix=0.16)

    if kind == "FINISH":
        return concat(
            smooth_tone(sample_rate, 0.180, 2200, 1950),
            gap(sample_rate, 0.060),
            smooth_tone(sample_rate, 0.220, 1650, 1400),
            gap(sample_rate, 0.060),
            smooth_tone(sample_rate, 0.400, 1150, 850),
        )

    raise ValueError(f"Unknown cue type: {kind}")


def build_cues(
    reps: list[Rep],
    pre_roll: float,
    stage_chimes: bool,
) -> list[Cue]:
    cues: list[Cue] = []

    # 3-2-1 countdown during pre-roll when enough space exists.
    for seconds_before in (3.0, 2.0, 1.0):
        t = pre_roll - seconds_before
        if t >= 0:
            cues.append(Cue(t, "COUNTDOWN"))

    previous_level: int | None = None

    for rep in reps:
        file_start = pre_roll + rep.protocol_start

        # New-level indicator lives in recovery BEFORE the precise run start.
        # The first level uses the pre-roll countdown instead.
        if (
            stage_chimes
            and previous_level is not None
            and rep.level != previous_level
            and file_start >= 0.80
        ):
            cues.append(
                Cue(
                    file_time=file_start - 0.70,
                    kind="LEVEL",
                    level=rep.level,
                    shuttle=rep.shuttle,
                )
            )

        cues.append(Cue(file_start, "START", rep.level, rep.shuttle))
        cues.append(Cue(pre_roll + rep.turn, "TURN", rep.level, rep.shuttle))
        cues.append(
            Cue(
                pre_roll + rep.recovery_start,
                "RECOVERY",
                rep.level,
                rep.shuttle,
            )
        )

        previous_level = rep.level

    # Finish after the final 10 s recovery period.
    cues.append(Cue(pre_roll + reps[-1].next_start, "FINISH"))

    return sorted(cues, key=lambda c: c.file_time)


def write_silence(
    f: sf.SoundFile,
    frames: int,
    channels: int,
    sample_rate: int,
) -> None:
    block_frames = sample_rate * 10
    zero_block = np.zeros((block_frames, channels), dtype=np.float32)

    remaining = frames
    while remaining > 0:
        n = min(remaining, block_frames)
        f.write(zero_block[:n])
        remaining -= n


def render_wav(
    output: Path,
    cues: list[Cue],
    *,
    sample_rate: int,
    channels: int,
    peak_dbfs: float,
    total_seconds: float,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    peak_amp = db_to_amp(peak_dbfs)

    # Pre-build each cue type only once.
    cache: dict[str, np.ndarray] = {}
    for cue in cues:
        if cue.kind not in cache:
            cache[cue.kind] = synth_cue(cue.kind, sample_rate) * peak_amp

    with sf.SoundFile(
        output,
        mode="w",
        samplerate=sample_rate,
        channels=channels,
        subtype="PCM_24",
        format="WAV",
    ) as f:
        cursor = 0

        for cue in cues:
            target = int(round(cue.file_time * sample_rate))

            if target < cursor:
                raise RuntimeError(
                    f"Cue overlap near {cue.file_time:.3f}s ({cue.kind}). "
                    "Change cue durations or scheduling."
                )

            if target > cursor:
                write_silence(f, target - cursor, channels, sample_rate)
                cursor = target

            mono = cache[cue.kind]
            if channels == 1:
                audio = mono[:, None]
            else:
                # Identical L/R keeps phase coherent on mono/outdoor PA systems.
                audio = np.repeat(mono[:, None], channels, axis=1)

            f.write(audio)
            cursor += len(mono)

        total_frames = int(round(total_seconds * sample_rate))
        if cursor < total_frames:
            write_silence(f, total_frames - cursor, channels, sample_rate)


def write_manifest(
    path: Path,
    reps: list[Rep],
    pre_roll: float,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(
            [
                "level",
                "shuttle",
                "speed_kmh",
                "cumulative_distance_m",
                "protocol_start_s",
                "turn_20m_s",
                "recovery_start_40m_s",
                "next_start_s",
                "file_start_s",
                "file_turn_s",
                "file_recovery_start_s",
                "file_next_start_s",
            ]
        )

        for rep in reps:
            writer.writerow(
                [
                    rep.level,
                    rep.shuttle,
                    f"{rep.speed_kmh:.1f}",
                    rep.cumulative_distance_m,
                    f"{rep.protocol_start:.6f}",
                    f"{rep.turn:.6f}",
                    f"{rep.recovery_start:.6f}",
                    f"{rep.next_start:.6f}",
                    f"{pre_roll + rep.protocol_start:.6f}",
                    f"{pre_roll + rep.turn:.6f}",
                    f"{pre_roll + rep.recovery_start:.6f}",
                    f"{pre_roll + rep.next_start:.6f}",
                ]
            )


def ensure_ffmpeg() -> str:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        return ffmpeg

    if shutil.which("pacman"):
        print("ffmpeg is required only for --mp3; installing it with pacman...")
        _arch_install("ffmpeg")
        ffmpeg = shutil.which("ffmpeg")

    if not ffmpeg:
        raise RuntimeError("ffmpeg is not installed and could not be installed.")

    return ffmpeg


def make_mp3(wav_path: Path) -> Path:
    ffmpeg = ensure_ffmpeg()
    mp3_path = wav_path.with_suffix(".mp3")

    _run(
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(wav_path),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "320k",
            str(mp3_path),
        ]
    )
    return mp3_path


def format_clock(seconds: float) -> str:
    minutes = int(seconds // 60)
    sec = seconds - minutes * 60
    return f"{minutes:02d}:{sec:05.2f}"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Synthesize a protocol-derived Yo-Yo IR1 audio track."
    )
    p.add_argument(
        "--output",
        type=Path,
        default=Path("YoYo_IR1_protocol_outdoor_48k_24bit.wav"),
        help="Output WAV path.",
    )
    p.add_argument(
        "--pre-roll",
        type=float,
        default=0.8,
        help="Seconds before protocol time 0. Default: 0.8.",
    )
    p.add_argument(
        "--tail",
        type=float,
        default=2.0,
        help="Silence after finish cue area. Default: 2.",
    )
    p.add_argument(
        "--peak-dbfs",
        type=float,
        default=-1.0,
        help="Synthesized cue peak ceiling. Default: -1.0 dBFS.",
    )
    p.add_argument(
        "--sample-rate",
        type=int,
        default=48000,
        choices=(44100, 48000, 96000),
        help="WAV sample rate. Default: 48000.",
    )
    p.add_argument(
        "--mono",
        action="store_true",
        help="Write mono WAV instead of phase-coherent stereo.",
    )
    p.add_argument(
        "--no-stage-chimes",
        action="store_true",
        help="Disable level-change chimes during recovery.",
    )
    p.add_argument(
        "--max-level",
        type=int,
        default=23,
        help="Stop after this protocol level. Default: 23.",
    )
    p.add_argument(
        "--mp3",
        action="store_true",
        help="Also make a 320 kbps MP3 preview (installs ffmpeg if needed).",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate protocol and print timings without rendering audio.",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if args.pre_roll < 0 or args.tail < 0:
        raise SystemExit("--pre-roll and --tail must be >= 0.")
    if not (-12.0 <= args.peak_dbfs <= -0.1):
        raise SystemExit("--peak-dbfs should be between -12 and -0.1 dBFS.")

    reps = build_protocol(args.max_level)
    validate_protocol(reps, args.max_level)

    protocol_end = reps[-1].next_start
    # Finish cue lasts ~1.18 s; leave tail after it.
    finish_len = len(synth_cue("FINISH", args.sample_rate)) / args.sample_rate
    total_seconds = args.pre_roll + protocol_end + finish_len + args.tail

    print()
    print("Yo-Yo IR1 protocol synthesis")
    print("---------------------------")
    print(f"Repetitions:       {len(reps)}")
    print(f"Distance:          {reps[-1].cumulative_distance_m} m")
    print(f"Final level:       {reps[-1].level}")
    print(f"Protocol duration: {format_clock(protocol_end)}")
    print(f"Pre-roll:          {args.pre_roll:.2f} s")
    print(f"Rendered duration: {format_clock(total_seconds)}")
    print(f"Peak target:       {args.peak_dbfs:.1f} dBFS")
    print(f"Sample rate:       {args.sample_rate} Hz")
    print(f"Channels:          {1 if args.mono else 2}")
    print(f"Stage chimes:      {'off' if args.no_stage_chimes else 'on'}")
    print()

    if args.dry_run:
        print("Protocol validated. No audio rendered (--dry-run).")
        return 0

    cues = build_cues(
        reps,
        pre_roll=args.pre_roll,
        stage_chimes=not args.no_stage_chimes,
    )

    output = args.output.expanduser().resolve()
    manifest = output.with_name(output.stem + "_cues.csv")

    print(f"Rendering WAV -> {output}")
    render_wav(
        output,
        cues,
        sample_rate=args.sample_rate,
        channels=1 if args.mono else 2,
        peak_dbfs=args.peak_dbfs,
        total_seconds=total_seconds,
    )

    write_manifest(manifest, reps, args.pre_roll)

    info = sf.info(output)
    size_mb = output.stat().st_size / (1024 * 1024)

    print()
    print("Created successfully")
    print("--------------------")
    print(f"WAV:      {output}")
    print(f"Manifest: {manifest}")
    print(
        f"Format:   {info.samplerate} Hz / PCM_24 / "
        f"{info.channels} channel(s)"
    )
    print(f"Duration: {format_clock(info.duration)}")
    print(f"Size:     {size_mb:.1f} MiB")

    if args.mp3:
        mp3 = make_mp3(output)
        print(f"MP3:      {mp3}")

    print()
    print("Cue meanings:")
    print("  rising double beep     = start next 2 x 20 m")
    print("  single bright beep     = 20 m turn")
    print("  descending double beep = 40 m complete / recovery starts")
    print("  three rising pips      = new IR1 level coming")
    print("  descending 3-note cue  = end of generated protocol")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
