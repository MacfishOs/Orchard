"""Read-only local process sampling; artifacts stay in build/performance.

Linux reads /proc and sysfs for per-thread, GPU, thermal and frequency data.
Other systems report CPU time and memory per process through ps or tasklist.
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def cpu_ticks(path):
    fields = path.read_text().rsplit(") ", 1)[1].split()
    return int(fields[11]) + int(fields[12])


def switches(path):
    values = {}
    for line in path.read_text().splitlines():
        key, _, value = line.partition(":")
        if key in ("voluntary_ctxt_switches", "nonvoluntary_ctxt_switches"):
            values[key] = int(value.strip())
    return values


PROCESS_NAMES = ("orchard", "orchard-adaptiv")


def wanted(name):
    base = os.path.basename(name.strip()).lower()
    if base.endswith(".exe"):
        base = base[:-4]
    return base in PROCESS_NAMES


def process_sample(entry):
    name = (entry / "comm").read_text().strip()
    if not wanted(name):
        return None
    memory = {}
    for line in (entry / "smaps_rollup").read_text().splitlines()[1:]:
        fields = line.split()
        memory[fields[0].rstrip(":")] = int(fields[1])
    tasks = {}
    for task in (entry / "task").iterdir():
        try:
            tasks[task.name] = {
                "name": (task / "comm").read_text().strip(),
                "cpu_ticks": cpu_ticks(task / "stat"),
                **switches(task / "status"),
            }
        except (OSError, ValueError, IndexError):
            continue
    gpu = {}
    for descriptor in (entry / "fdinfo").iterdir():
        try:
            fields = dict(line.split(":", 1) for line in descriptor.read_text().splitlines()
                          if line.startswith("drm-"))
            if "drm-client-id" in fields:
                gpu[fields["drm-client-id"].strip()] = fields
        except OSError:
            continue
    return {
        "pid": int(entry.name), "name": name,
        "cpu_ticks": cpu_ticks(entry / "stat"),
        "rss_kib": memory.get("Rss"),
        "memory_kib": memory, "tasks": tasks, "gpu": gpu,
        **switches(entry / "status"),
    }


def linux_processes():
    result = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            sample = process_sample(entry)
            if sample:
                result.append(sample)
        except (OSError, ValueError, IndexError):
            continue
    return result


def parse_cpu_time(text):
    days, _, clock = text.rpartition("-")
    seconds = 0.0
    for part in clock.split(":"):
        seconds = seconds * 60 + float(part)
    return seconds + (int(days) * 86400 if days else 0)


def ps_processes():
    output = subprocess.run(["ps", "-axo", "pid=,rss=,time=,comm="], check=True,
                            capture_output=True, text=True).stdout
    result = []
    for line in output.splitlines():
        fields = line.split(None, 3)
        if len(fields) == 4 and wanted(fields[3]):
            try:
                result.append({"pid": int(fields[0]), "name": os.path.basename(fields[3]),
                               "rss_kib": int(fields[1]),
                               "cpu_seconds": parse_cpu_time(fields[2])})
            except ValueError:
                continue
    return result


def tasklist_processes():
    output = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], check=True,
                            capture_output=True, text=True).stdout
    result = []
    for row in csv.reader(output.splitlines()):
        if len(row) >= 5 and wanted(row[0]):
            digits = "".join(c for c in row[4] if c.isdigit())
            result.append({"pid": int(row[1]), "name": row[0],
                           "rss_kib": int(digits) if digits else None})
    return result


def collect_processes():
    if sys.platform.startswith("linux"):
        return linux_processes()
    if sys.platform == "win32":
        return tasklist_processes()
    return ps_processes()


def sysfs_values(pattern):
    values = {}
    for path in Path("/sys").glob(pattern):
        try:
            values[str(path)] = path.read_text().strip()
        except OSError:
            continue
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 1200:
        parser.error("--seconds must be between 1 and 1200")
    if not args.label.replace("-", "").replace("_", "").isalnum():
        parser.error("label must contain letters, numbers, hyphens or underscores")
    output = Path(__file__).resolve().parents[2] / "build" / "performance"
    output.mkdir(parents=True, exist_ok=True)
    end = time.monotonic() + args.seconds
    with (output / (args.label + ".jsonl")).open("x") as stream:
        while time.monotonic() < end:
            record = {
                "time": time.time(), "monotonic": time.monotonic(),
                "platform": sys.platform,
                "clock_ticks_per_second": os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else None,
                "logical_cpus": os.cpu_count(), "label": args.label,
                "processes": collect_processes(),
            }
            record["temperature_mC"] = sysfs_values("class/thermal/thermal_zone*/temp")
            record["frequency_kHz"] = sysfs_values("devices/system/cpu/cpu*/cpufreq/scaling_cur_freq")
            stream.write(json.dumps(record) + "\n")
            stream.flush()
            time.sleep(min(1, max(0, end - time.monotonic())))


if __name__ == "__main__":
    main()
