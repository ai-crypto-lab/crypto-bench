#!/usr/bin/env python3
"""Aggregate per-run JSON artifacts from every target into one table.

Reads  artifacts/<target>/run-*.json
Writes artifacts/comparison.{csv,md,json}

Intended to be committed into `openhash-core/artifacts/experiments/`
alongside the OpenHash re-measurement for the paper's §5.6 table.
"""
import glob
import json
import pathlib
import statistics
import sys

HERE = pathlib.Path(__file__).resolve().parent
ARTIFACTS = HERE.parent / "artifacts"


def summarize(target_dir: pathlib.Path):
    runs = []
    for f in sorted(target_dir.glob("run-*.json")):
        try:
            runs.append(json.loads(f.read_text()))
        except Exception:
            pass
    if not runs:
        return None
    tps = [r["committed_tps"] for r in runs]
    p99 = [r.get("p99_ms", 0.0) for r in runs]
    return {
        "target": runs[0]["target"],
        "consensus": runs[0]["consensus"],
        "version": runs[0]["version"],
        "cluster_nodes": runs[0]["cluster"]["nodes"],
        "n_reps": len(runs),
        "tps_mean": round(statistics.mean(tps), 2),
        "tps_stddev": round(statistics.stdev(tps) if len(tps) > 1 else 0.0, 2),
        "p99_ms_mean": round(statistics.mean(p99), 2),
        "accepted_total": sum(r.get("accepted", 0) for r in runs),
        "attempted_total": sum(r.get("attempted", 0) for r in runs),
    }


def main():
    summaries = []
    for d in sorted(ARTIFACTS.glob("*")):
        if d.is_dir():
            s = summarize(d)
            if s:
                summaries.append(s)
    if not summaries:
        print(f"no run-*.json artifacts under {ARTIFACTS}", file=sys.stderr)
        return 1

    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    (ARTIFACTS / "comparison.json").write_text(
        json.dumps(summaries, indent=2)
    )

    # CSV
    with open(ARTIFACTS / "comparison.csv", "w") as fh:
        fh.write(
            "target,consensus,version,cluster_nodes,n_reps,"
            "tps_mean,tps_stddev,p99_ms_mean,accepted_total,attempted_total\n"
        )
        for s in summaries:
            fh.write(
                f"{s['target']},{s['consensus']},{s['version']},"
                f"{s['cluster_nodes']},{s['n_reps']},"
                f"{s['tps_mean']},{s['tps_stddev']},{s['p99_ms_mean']},"
                f"{s['accepted_total']},{s['attempted_total']}\n"
            )

    # Markdown table
    with open(ARTIFACTS / "comparison.md", "w") as fh:
        fh.write("# crypto-bench comparison\n\n")
        fh.write(
            "| target | consensus | version | nodes | reps | TPS mean ± σ | p99 ms | accepted/attempted |\n"
            "|---|---|---|---|---|---|---|---|\n"
        )
        for s in summaries:
            fh.write(
                f"| {s['target']} | {s['consensus']} | {s['version']} | "
                f"{s['cluster_nodes']} | {s['n_reps']} | "
                f"{s['tps_mean']} ± {s['tps_stddev']} | "
                f"{s['p99_ms_mean']} | "
                f"{s['accepted_total']} / {s['attempted_total']} |\n"
            )
        fh.write(
            "\n**Caveats:** see `crypto-bench/workloads/transfer-500.md` "
            "for the trust-model / batching / WAN notes that must accompany "
            "any citation of this table.\n"
        )
    print(f"wrote {ARTIFACTS / 'comparison.csv'}")
    print(f"wrote {ARTIFACTS / 'comparison.md'}")
    print(f"wrote {ARTIFACTS / 'comparison.json'}")
    for s in summaries:
        print(
            f"  {s['target']:<10s} {s['tps_mean']:>8.1f} ± {s['tps_stddev']:<6.1f} "
            f"({s['n_reps']} reps)"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
