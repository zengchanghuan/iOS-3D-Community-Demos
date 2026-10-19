#!/usr/bin/env python3
"""Plot unmodified CADisplayLink timestamps. All recorded intervals are included."""
import json, pathlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root = pathlib.Path(__file__).resolve().parents[1] / 'Docs/Benchmarks'
fig, axes = plt.subplots(2, 1, figsize=(11, 7), constrained_layout=True)
summary = []
for ax, context, title in zip(axes, ['library', 'model'], ['Gallery: repeated scroll gestures', 'SceneKit Fox: repeated rotation gestures']):
    candidates = [(p, json.loads(p.read_text())) for p in root.glob('fps-'+context+'-*.json')]
    p, record = max(candidates, key=lambda item: len(item[1]['timestamps']))
    ts = np.asarray(record['timestamps']); dt = np.diff(ts)*1000
    fps = (len(ts)-1)/(ts[-1]-ts[0])
    stats = {'context': context, 'source': p.name, 'duration_s': float(ts[-1]-ts[0]), 'intervals': len(dt), 'average_callback_hz': float(fps), 'median_ms': float(np.median(dt)), 'p95_ms': float(np.percentile(dt,95)), 'max_ms': float(dt.max()), 'over_20ms_percent': float((dt>20).mean()*100)}
    summary.append(stats)
    ax.plot(ts[1:]-ts[0], dt, color='#265a9e', lw=0.8)
    ax.axhline(1000/60, color='#6b8e23', ls='--', lw=1, label='60 Hz budget: 16.67 ms')
    ax.set(title=f'{title} | mean {fps:.2f} Hz, P95 {stats["p95_ms"]:.2f} ms', xlabel='Elapsed time (s)', ylabel='Callback interval (ms)')
    ax.set_ylim(bottom=0); ax.grid(alpha=.18); ax.legend(loc='upper right')
fig.suptitle('Measured display-link intervals — iOS 27.0 Simulator / Debug / XCTest\nIncludes warm-up and test orchestration; not GPU completion or a stable-60-FPS claim', fontsize=11)
fig.savefig(root/'fps-timeline.png', dpi=160)
(root/'fps-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
print(json.dumps(summary, indent=2))
