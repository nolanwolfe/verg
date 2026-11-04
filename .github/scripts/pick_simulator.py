"""Print the UDID of an available iPhone simulator on the newest iOS runtime.

CI runners ship different simulator sets as Xcode updates, so naming a
device ("iPhone 16") breaks the day the image changes. This picks whatever
iPhone exists on the newest installed runtime instead.
"""
import json
import re
import subprocess
import sys

devices = json.loads(
    subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
)["devices"]


def runtime_version(key: str) -> tuple:
    match = re.search(r"iOS-(\d+)-(\d+)", key)
    return tuple(int(x) for x in match.groups()) if match else (0, 0)


for runtime in sorted((k for k in devices if ".iOS-" in k), key=runtime_version, reverse=True):
    iphones = [d for d in devices[runtime] if d["name"].startswith("iPhone")]
    if iphones:
        # Prefer a plain current model over SE/mini for a typical screen size.
        iphones.sort(key=lambda d: ("SE" in d["name"] or "mini" in d["name"], d["name"]))
        print(iphones[0]["udid"])
        sys.exit(0)

sys.exit("No available iPhone simulator found")
