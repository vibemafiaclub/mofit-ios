"""
Exercise counting parameter optimizer.

Loads pre-extracted joint data (from Swift Vision API) and finds optimal
threshold parameters for each exercise's counting algorithm.

Usage:
    python3 optimize.py              # optimize all exercises
    python3 optimize.py squat        # optimize single exercise
    python3 optimize.py --visualize  # show angle plots
"""

import json
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path
from itertools import product

DATA_DIR = Path(__file__).parent / "data"
INDEX_PATH = Path(__file__).parent.parent / "videos" / "index.json"
MIN_CONFIDENCE = 0.1  # Lower than Swift's 0.3 — we interpolate noisy frames anyway


# ---------------------------------------------------------------------------
# Angle calculation — identical to Swift SquatCounter.calculateAngle
# ---------------------------------------------------------------------------

def calc_angle(p1: list, vertex: list, p3: list) -> float:
    """Calculate angle at vertex formed by p1-vertex-p3, in degrees (0-180)."""
    angle_rad = math.atan2(p3[1] - vertex[1], p3[0] - vertex[0]) \
              - math.atan2(p1[1] - vertex[1], p1[0] - vertex[0])
    deg = abs(math.degrees(angle_rad))
    if deg > 180:
        deg = 360 - deg
    return deg


# ---------------------------------------------------------------------------
# Signal definitions: multiple signal types per exercise
# ---------------------------------------------------------------------------

SIGNAL_CONFIGS = {
    "squat": [
        {
            "name": "knee_angle",
            "type": "angle",
            "joints": [("leftHip", "leftKnee", "leftAnkle"),
                       ("rightHip", "rightKnee", "rightAnkle")],
            "description": "Knee angle (Hip→Knee→Ankle)",
        },
        {
            "name": "hip_y",
            "type": "joint_y",
            "joints": ["leftHip", "rightHip"],
            "description": "Hip Y position (vertical movement)",
        },
    ],
    "push-up": [
        {
            "name": "elbow_angle",
            "type": "angle",
            "joints": [("leftShoulder", "leftElbow", "leftWrist"),
                       ("rightShoulder", "rightElbow", "rightWrist")],
            "description": "Elbow angle (Shoulder→Elbow→Wrist)",
        },
        {
            "name": "shoulder_y",
            "type": "joint_y",
            "joints": ["leftShoulder", "rightShoulder"],
            "description": "Shoulder Y position",
        },
        {
            "name": "shoulder_wrist_dist",
            "type": "joint_dist_y",
            "joints_top": ["leftShoulder", "rightShoulder"],
            "joints_bottom": ["leftWrist", "rightWrist"],
            "description": "Shoulder-to-Wrist Y distance (up/down movement)",
        },
        {
            "name": "nose_wrist_dist",
            "type": "joint_dist_y",
            "joints_top": ["nose"],
            "joints_bottom": ["leftWrist", "rightWrist"],
            "description": "Nose-to-Wrist Y distance",
        },
    ],
    "sit-up": [
        {
            "name": "hip_angle",
            "type": "angle",
            "joints": [("leftShoulder", "leftHip", "leftKnee"),
                       ("rightShoulder", "rightHip", "rightKnee")],
            "description": "Hip angle (Shoulder→Hip→Knee)",
        },
        {
            "name": "nose_y",
            "type": "joint_y",
            "joints": ["nose"],
            "description": "Nose Y position",
        },
        {
            "name": "shoulder_y",
            "type": "joint_y",
            "joints": ["leftShoulder", "rightShoulder"],
            "description": "Shoulder Y position",
        },
        {
            "name": "torso_angle",
            "type": "angle",
            "joints": [("nose", "neck", "root"),
                       ("neck", "root", "leftHip")],
            "description": "Torso angle (Nose→Neck→Root)",
        },
    ],
}


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_index() -> dict:
    with open(INDEX_PATH) as f:
        items = json.load(f)
    return {item["name"]: item for item in items}


def load_joint_data(exercise: str) -> list[dict]:
    path = DATA_DIR / f"{exercise}.json"
    with open(path) as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Signal extraction (angle or joint Y)
# ---------------------------------------------------------------------------

def extract_signal(frames: list[dict], sig_config: dict) -> list[tuple[float, float]]:
    """Extract a time series signal from joint data."""
    result = []
    sig_type = sig_config["type"]

    for frame in frames:
        joints = frame["joints"]
        conf = frame.get("confidence", {})
        value = None

        if sig_type == "angle":
            for j1, j2, j3 in sig_config["joints"]:
                if all(j in joints and conf.get(j, 0) >= MIN_CONFIDENCE
                       for j in [j1, j2, j3]):
                    value = calc_angle(joints[j1], joints[j2], joints[j3])
                    break

        elif sig_type == "joint_y":
            ys = []
            for j in sig_config["joints"]:
                if j in joints and conf.get(j, 0) >= MIN_CONFIDENCE:
                    ys.append(joints[j][1])
            if ys:
                # Scale to degrees-like range for unified processing
                value = sum(ys) / len(ys) * 180

        elif sig_type == "joint_dist_y":
            # Vertical distance between two joint groups
            j_top = sig_config["joints_top"]
            j_bot = sig_config["joints_bottom"]
            top_ys = [joints[j][1] for j in j_top
                      if j in joints and conf.get(j, 0) >= MIN_CONFIDENCE]
            bot_ys = [joints[j][1] for j in j_bot
                      if j in joints and conf.get(j, 0) >= MIN_CONFIDENCE]
            if top_ys and bot_ys:
                value = (sum(top_ys)/len(top_ys) - sum(bot_ys)/len(bot_ys)) * 180

        if value is not None:
            result.append((frame["t"], value))

    return result


# ---------------------------------------------------------------------------
# Interpolation — fill gaps in sparse signals
# ---------------------------------------------------------------------------

def interpolate_signal(signal: list[tuple[float, float]], step: float = 0.05) -> list[tuple[float, float]]:
    """Linearly interpolate to fill time gaps, producing uniform time steps."""
    if len(signal) < 2:
        return signal

    result = []
    for i in range(len(signal) - 1):
        t0, v0 = signal[i]
        t1, v1 = signal[i + 1]
        result.append((t0, v0))

        gap = t1 - t0
        if gap > step * 1.5:
            n_fill = int(gap / step)
            for k in range(1, n_fill):
                frac = k / n_fill
                result.append((t0 + gap * frac, v0 + (v1 - v0) * frac))

    result.append(signal[-1])
    return result


# ---------------------------------------------------------------------------
# Smoothing
# ---------------------------------------------------------------------------

def smooth_signal(signal: list[tuple[float, float]], window: int) -> list[tuple[float, float]]:
    """Simple moving average smoothing."""
    if window <= 1:
        return signal
    smoothed = []
    for i in range(len(signal)):
        start = max(0, i - window // 2)
        end = min(len(signal), i + window // 2 + 1)
        avg = sum(a for _, a in signal[start:end]) / (end - start)
        smoothed.append((signal[i][0], avg))
    return smoothed


# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------

@dataclass
class CountResult:
    count_times: list[float] = field(default_factory=list)
    total: int = 0


def run_counter_threshold(
    signal: list[tuple[float, float]],
    down_threshold: float,
    up_threshold: float,
    min_hold_frames: int = 0,
) -> CountResult:
    """
    State machine counter (threshold crossing with hysteresis).
    'up' -> signal drops below down_threshold -> 'down'
    'down' -> signal rises above up_threshold -> 'up' (count!)
    """
    state = "up"
    count_times = []
    frames_in_state = 0

    for t, val in signal:
        if state == "up":
            if val < down_threshold:
                frames_in_state += 1
                if frames_in_state >= max(1, min_hold_frames):
                    state = "down"
                    frames_in_state = 0
            else:
                frames_in_state = 0
        elif state == "down":
            if val > up_threshold:
                frames_in_state += 1
                if frames_in_state >= max(1, min_hold_frames):
                    state = "up"
                    count_times.append(t)
                    frames_in_state = 0
            else:
                frames_in_state = 0

    return CountResult(count_times=count_times, total=len(count_times))


def run_counter_peak(
    signal: list[tuple[float, float]],
    prominence: float,
    min_distance_frames: int = 5,
    detect: str = "valleys",
) -> CountResult:
    """
    Peak/valley detection counter.
    Detects local minima (valleys) or maxima (peaks) with minimum prominence.
    Counts on the rising edge after each valley.
    """
    if len(signal) < 3:
        return CountResult()

    values = [v for _, v in signal]
    times = [t for t, _ in signal]

    # Find valleys (or peaks)
    if detect == "valleys":
        candidates = find_valleys(values, prominence, min_distance_frames)
    else:
        candidates = find_peaks(values, prominence, min_distance_frames)

    count_times = [times[i] for i in candidates]
    return CountResult(count_times=count_times, total=len(count_times))


def find_valleys(values: list[float], prominence: float, min_dist: int) -> list[int]:
    """Find valley indices with minimum prominence and distance."""
    n = len(values)
    valleys = []

    for i in range(1, n - 1):
        if values[i] <= values[i-1] and values[i] <= values[i+1]:
            # Check prominence: how much does the signal rise on both sides?
            left_max = max(values[max(0, i-50):i+1])
            right_max = max(values[i:min(n, i+50)])
            prom = min(left_max - values[i], right_max - values[i])
            if prom >= prominence:
                if not valleys or (i - valleys[-1]) >= min_dist:
                    valleys.append(i)

    return valleys


def find_peaks(values: list[float], prominence: float, min_dist: int) -> list[int]:
    """Find peak indices with minimum prominence and distance."""
    neg = [-v for v in values]
    return find_valleys(neg, prominence, min_dist)


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def score_result(
    result: CountResult,
    expected_times: list[float],
    threshold_sec: float,
) -> dict:
    hits = 0
    matched_detected = set()

    for i, expected_t in enumerate(expected_times):
        for j, detected_t in enumerate(result.count_times):
            if j in matched_detected:
                continue
            if abs(detected_t - expected_t) <= threshold_sec:
                hits += 1
                matched_detected.add(j)
                break

    misses = len(expected_times) - hits
    false_positives = len(result.count_times) - hits

    total = hits + misses + false_positives
    score = hits / total if total > 0 else 0.0

    return {
        "score": score,
        "hits": hits,
        "misses": misses,
        "false_positives": false_positives,
        "total_expected": len(expected_times),
        "total_detected": result.total,
        "detected_times": result.count_times,
    }


# ---------------------------------------------------------------------------
# Grid search optimizer
# ---------------------------------------------------------------------------

def optimize(exercise: str, verbose: bool = True) -> dict:
    index = load_index()
    meta = index[exercise]
    signals = SIGNAL_CONFIGS[exercise]
    frames = load_joint_data(exercise)

    expected_times = meta["countSeconds"]
    threshold_sec = meta["thresholdSeconds"]

    best_overall_score = -1
    best_overall = None

    for sig_config in signals:
        raw_signal = extract_signal(frames, sig_config)
        if len(raw_signal) < 10:
            continue

        # Interpolate gaps for sparse signals
        raw_signal = interpolate_signal(raw_signal)

        all_vals = [v for _, v in raw_signal]
        val_min, val_max = min(all_vals), max(all_vals)

        if verbose:
            print(f"\n{'='*60}")
            print(f"[{exercise}] Signal: {sig_config['name']} — {sig_config['description']}")
            print(f"  Frames: {len(raw_signal)}, Range: {val_min:.1f} — {val_max:.1f}")

        # === Method 1: Threshold crossing ===
        margin = 5
        step = 2
        down_range = range(int(val_min - margin), int(val_max), step)
        up_range = range(int(val_min), int(val_max + margin), step)
        smooth_range = [1, 3, 5, 7, 9]
        hold_range = [0, 1, 2, 3]

        best_thresh_score = -1
        best_thresh = None
        combos = 0

        for smooth_w in smooth_range:
            smoothed = smooth_signal(raw_signal, smooth_w)
            for down_th, up_th, hold_f in product(down_range, up_range, hold_range):
                if up_th - down_th < 5:  # require minimum hysteresis gap
                    continue
                combos += 1
                result = run_counter_threshold(smoothed, down_th, up_th, hold_f)
                detail = score_result(result, expected_times, threshold_sec)

                if detail["score"] > best_thresh_score or (
                    detail["score"] == best_thresh_score
                    and best_thresh is not None
                    and detail["false_positives"] < best_thresh["detail"]["false_positives"]
                ):
                    best_thresh_score = detail["score"]
                    best_thresh = {
                        "method": "threshold",
                        "signal": sig_config["name"],
                        "signal_type": sig_config["type"],
                        "signal_joints": sig_config.get("joints", sig_config.get("joints_top", []) + sig_config.get("joints_bottom", [])),
                        "params": {
                            "downThreshold": down_th,
                            "upThreshold": up_th,
                            "smoothingWindow": smooth_w,
                            "minHoldFrames": hold_f,
                        },
                        "detail": detail,
                    }

        if verbose and best_thresh:
            d = best_thresh["detail"]
            print(f"  Threshold: {combos:,} combos → score={d['score']:.3f} "
                  f"({d['hits']}/{d['total_expected']} hits, {d['false_positives']} FP)")
            print(f"    params={best_thresh['params']}")
            print(f"    detected={[f'{t:.2f}' for t in d['detected_times']]}")

        # === Method 2: Peak/valley detection ===
        prom_range = [v for v in range(2, int(val_max - val_min), 2)]
        dist_range = [3, 5, 8, 12, 15, 20, 30, 40]

        best_peak_score = -1
        best_peak = None

        for smooth_w in smooth_range:
            smoothed = smooth_signal(raw_signal, smooth_w)
            for prom, dist in product(prom_range, dist_range):
                for detect_type in ["valleys", "peaks"]:
                    result = run_counter_peak(smoothed, prom, dist, detect_type)
                    detail = score_result(result, expected_times, threshold_sec)

                    if detail["score"] > best_peak_score or (
                        detail["score"] == best_peak_score
                        and best_peak is not None
                        and detail["false_positives"] < best_peak["detail"]["false_positives"]
                    ):
                        best_peak_score = detail["score"]
                        best_peak = {
                            "method": f"peak_{detect_type}",
                            "signal": sig_config["name"],
                            "signal_type": sig_config["type"],
                            "signal_joints": sig_config.get("joints", sig_config.get("joints_top", []) + sig_config.get("joints_bottom", [])),
                            "params": {
                                "prominence": prom,
                                "minDistanceFrames": dist,
                                "smoothingWindow": smooth_w,
                                "detectType": detect_type,
                            },
                            "detail": detail,
                        }

        if verbose and best_peak:
            d = best_peak["detail"]
            print(f"  Peak det: score={d['score']:.3f} "
                  f"({d['hits']}/{d['total_expected']} hits, {d['false_positives']} FP)")
            print(f"    params={best_peak['params']}")
            print(f"    detected={[f'{t:.2f}' for t in d['detected_times']]}")

        # Track overall best
        for candidate in [best_thresh, best_peak]:
            if candidate and candidate["detail"]["score"] > best_overall_score:
                best_overall_score = candidate["detail"]["score"]
                best_overall = candidate
            elif (candidate and candidate["detail"]["score"] == best_overall_score
                  and best_overall
                  and candidate["detail"]["false_positives"] < best_overall["detail"]["false_positives"]):
                best_overall = candidate

    if verbose and best_overall:
        d = best_overall["detail"]
        print(f"\n  >>> BEST for {exercise}: {best_overall['method']} on {best_overall['signal']}")
        print(f"      score={d['score']:.3f}, {d['hits']}/{d['total_expected']} hits, "
              f"{d['false_positives']} FP, {d['misses']} misses")
        print(f"      params={best_overall['params']}")
        print(f"      detected={[f'{t:.2f}' for t in d['detected_times']]}")
        print(f"      expected={expected_times}")

    return {
        "exercise": exercise,
        **best_overall,
    }


# ---------------------------------------------------------------------------
# Visualization
# ---------------------------------------------------------------------------

def visualize(exercise: str):
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("pip install matplotlib for visualization")
        return

    index = load_index()
    meta = index[exercise]
    signals = SIGNAL_CONFIGS[exercise]
    frames = load_joint_data(exercise)

    n_signals = len(signals)
    fig, axes = plt.subplots(n_signals, 1, figsize=(14, 4 * n_signals), sharex=True)
    if n_signals == 1:
        axes = [axes]

    for ax, sig_config in zip(axes, signals):
        raw_signal = extract_signal(frames, sig_config)
        if not raw_signal:
            continue

        times = [t for t, _ in raw_signal]
        values = [v for _, v in raw_signal]

        ax.plot(times, values, linewidth=0.6, alpha=0.5, label="Raw")

        smoothed = smooth_signal(raw_signal, 5)
        ax.plot([t for t, _ in smoothed], [v for _, v in smoothed],
                linewidth=1.2, label="Smoothed (w=5)")

        for ct in meta["countSeconds"]:
            ax.axvline(ct, color="green", alpha=0.5, linestyle="--", linewidth=1)

        ax.set_ylabel(sig_config["name"])
        ax.set_title(f"{exercise} — {sig_config['description']}")
        ax.legend(loc="upper right")
        ax.grid(True, alpha=0.3)

    axes[-1].set_xlabel("Time (s)")
    plt.tight_layout()
    plt.savefig(str(DATA_DIR / f"{exercise}_signals.png"), dpi=150)
    print(f"  Saved: data/{exercise}_signals.png")
    plt.close()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    exercises = list(SIGNAL_CONFIGS.keys())
    do_visualize = "--visualize" in sys.argv or "-v" in sys.argv

    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if args:
        exercises = [e for e in exercises if e in args]

    results = []
    for ex in exercises:
        res = optimize(ex)
        results.append(res)
        if do_visualize:
            visualize(ex)

    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY — Optimal parameters for Swift")
    print(f"{'='*60}")
    for res in results:
        p = res["params"]
        d = res["detail"]
        perfect = "PERFECT" if d["score"] == 1.0 else f"score={d['score']:.3f}"
        print(f"\n  {res['exercise']} [{res['method']} on {res['signal']}]:")
        for k, v in p.items():
            print(f"    {k} = {v}")
        print(f"    result: {d['hits']}/{d['total_expected']} hits, "
              f"{d['false_positives']} FP — {perfect}")
