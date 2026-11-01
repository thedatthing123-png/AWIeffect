"""Song map for editing: BPM, beats, accents (kick / snare / hat), energy sections, drops and a spectrogram image.

Usage:  python analyze_audio.py <song or video file> [--fps 60] [--out map]
Writes <out>.json (the map) and <out>.png (spectrogram + energy + beats) next to the output path, and prints a summary.
Needs ffmpeg on PATH, numpy, scipy and matplotlib (librosa not required).
"""
import argparse, json, subprocess, sys
import numpy as np
from scipy.signal import stft, find_peaks, butter, sosfilt

SR = 22050


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def onset_env(x, lo, hi, hop=256, n=1024):
    f, t, Z = stft(x, SR, nperseg=n, noverlap=n - hop, boundary=None)
    band = (f >= lo) & (f < hi)
    mag = np.log1p(np.abs(Z[band]) * 10)
    flux = np.maximum(0, np.diff(mag, axis=1)).sum(axis=0)
    flux = np.concatenate([[0], flux])
    return t, flux / (flux.max() + 1e-9)


def peaks(env, t, min_gap, k=1.4):
    win = max(3, int(0.4 / (t[1] - t[0])))
    med = np.convolve(env, np.ones(win) / win, mode="same")
    idx, _ = find_peaks(env, height=med * k + 0.05, distance=max(1, int(min_gap / (t[1] - t[0]))))
    return idx


def tempo(env, t):
    dt = t[1] - t[0]
    e = env - env.mean()
    ac = np.correlate(e, e, mode="full")[len(e) - 1:]
    lags = np.arange(len(ac)) * dt
    ok = (lags > 60 / 200) & (lags < 60 / 60)
    best = lags[ok][np.argmax(ac[ok])]
    bpm = 60 / best
    while bpm < 80: bpm *= 2
    while bpm > 180: bpm /= 2
    return bpm


def beat_grid(env, t, bpm):
    period = 60 / bpm
    dt = t[1] - t[0]
    best, best_off = -1, 0
    for off in np.arange(0, period, dt):
        idx = ((np.arange(off, t[-1], period)) / dt).astype(int)
        idx = idx[idx < len(env)]
        s = env[idx].sum()
        if s > best: best, best_off = s, off
    return np.arange(best_off, t[-1], period)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file"); ap.add_argument("--fps", type=float, default=60); ap.add_argument("--out", default="song_map")
    a = ap.parse_args()
    x = load(a.file)
    dur = len(x) / SR
    t, full = onset_env(x, 30, 11000)
    _, kick = onset_env(x, 30, 150)
    _, snare = onset_env(x, 150, 2500)
    _, hat = onset_env(x, 6000, 11000)
    bpm = tempo(full, t)
    beats = beat_grid(full, t, bpm)

    # Loudness curve (RMS, 0.25 s windows) -> sections and drops.
    w = int(SR * 0.25)
    rms = np.array([np.sqrt(np.mean(x[i:i + w] ** 2) + 1e-12) for i in range(0, len(x) - w, w)])
    db = 20 * np.log10(rms + 1e-9); db -= db.max()
    smooth = np.convolve(db, np.ones(8) / 8, mode="same")
    rise = np.diff(smooth, prepend=smooth[0])
    drop_idx, _ = find_peaks(rise, height=2.5, distance=16)
    drops = [round(i * 0.25, 2) for i in drop_idx]
    quiet = [round(i * 0.25, 2) for i in range(len(smooth)) if smooth[i] < -22]

    # Sections: split where the 4 s average loudness shifts by > 4 dB.
    sec, start = [], 0.0
    blk = np.convolve(db, np.ones(16) / 16, mode="same")
    for i in range(16, len(blk), 4):
        if abs(blk[i] - blk[int(start / 0.25)]) > 4 and i * 0.25 - start > 4:
            sec.append({"start": round(start, 2), "end": round(i * 0.25, 2), "level_db": round(float(blk[int((start / 0.25 + i) / 2)]), 1)})
            start = i * 0.25
    sec.append({"start": round(start, 2), "end": round(dur, 2), "level_db": round(float(blk[min(len(blk) - 1, int((start / 0.25 + len(blk)) / 2))]), 1)})
    for s in sec:
        s["energy"] = "high" if s["level_db"] > -6 else ("mid" if s["level_db"] > -14 else "low")

    def times(idx): return [round(float(t[i]), 3) for i in idx]
    m = {
        "file": a.file, "duration": round(dur, 2), "bpm": round(bpm, 1), "fps": a.fps,
        "frames_per_beat": round(a.fps * 60 / bpm, 2),
        "beats": [round(float(b), 3) for b in beats],
        "kicks": times(peaks(kick, t, 0.18)), "snares": times(peaks(snare, t, 0.18)), "hats": times(peaks(hat, t, 0.08, 1.2)),
        "strong_hits": times(peaks(full, t, 0.25, 2.2)),
        "drops": drops, "quiet": quiet[:200], "sections": sec,
    }
    json.dump(m, open(a.out + ".json", "w"), indent=1)

    try:
        import matplotlib; matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        f, tt, Z = stft(x, SR, nperseg=2048, noverlap=1536)
        fig, ax = plt.subplots(2, 1, figsize=(16, 7), sharex=True, gridspec_kw={"height_ratios": [3, 1]})
        ax[0].pcolormesh(tt, f, 20 * np.log10(np.abs(Z) + 1e-6), shading="auto", cmap="magma", vmin=-90, vmax=-10)
        ax[0].set_yscale("symlog", linthresh=200); ax[0].set_ylim(30, 11000); ax[0].set_ylabel("Hz")
        for b in m["beats"]: ax[0].axvline(b, color="w", alpha=0.15, lw=0.5)
        for d in drops: ax[0].axvline(d, color="cyan", lw=1.5); ax[1].axvline(d, color="cyan", lw=1.5)
        ax[1].plot(np.arange(len(db)) * 0.25, db, color="k"); ax[1].set_ylabel("dB"); ax[1].set_xlabel("seconds")
        for s in sec: ax[1].axvspan(s["start"], s["end"], alpha=0.12, color={"high": "red", "mid": "orange", "low": "blue"}[s["energy"]])
        ax[0].set_title(f"{bpm:.1f} BPM  |  cyan = drops  |  red/orange/blue = high/mid/low energy")
        plt.tight_layout(); plt.savefig(a.out + ".png", dpi=80)
    except Exception as e:
        print("plot skipped:", e, file=sys.stderr)

    print(f"{dur:.1f}s  {bpm:.1f} BPM  ({m['frames_per_beat']} frames/beat at {a.fps:g} fps)  beats={len(beats)} "
          f"kicks={len(m['kicks'])} snares={len(m['snares'])} drops={drops}")
    for s in sec: print(f"  {s['start']:7.2f}-{s['end']:7.2f}s  {s['energy']:4}  ({s['level_db']} dB)")


if __name__ == "__main__":
    main()
