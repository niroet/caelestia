#!/usr/bin/env python3
"""Dynamically sets Hyprland monitor layout based on connected displays.
Ultrawide (Samsung LC49G95T) → centered below. Otherwise → side-by-side."""

import os, socket, subprocess, time

LAYOUT_FILE = os.path.expanduser("~/.config/hypr/monitor-layout.conf")

LAYOUTS = {
    "ultrawide": (
        "monitor = HDMI-A-1,3840x1080@60,0x0,1\n"
        "monitor = eDP-1,1920x1080@60,960x1080,1\n"
    ),
    "standard": (
        "monitor = HDMI-A-1,preferred,0x0,1\n"
        "monitor = eDP-1,1920x1080@60,auto,1\n"
    ),
}


def hyprctl(*args):
    try:
        r = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=5)
        return r.stdout
    except Exception:
        return ""


def socket_path():
    rd = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    return os.path.join(rd, "hypr", sig, ".socket2.sock")


def update_layout():
    monitors = hyprctl("-j", "monitors")
    layout = LAYOUTS["ultrawide"] if "LC49G95T" in monitors else LAYOUTS["standard"]

    try:
        with open(LAYOUT_FILE) as f:
            if f.read() == layout:
                return  # No change needed
    except FileNotFoundError:
        pass

    with open(LAYOUT_FILE, "w") as f:
        f.write(layout)
    hyprctl("reload")


def main():
    update_layout()

    path = socket_path()
    while True:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(path)
            buf = ""
            while True:
                data = sock.recv(4096)
                if not data:
                    break
                buf += data.decode(errors="replace")
                while "\n" in buf:
                    line, buf = buf.split("\n", 1)
                    if line.startswith(("monitoradded", "monitorremoved")):
                        time.sleep(1)
                        update_layout()
            sock.close()
        except OSError:
            pass
        time.sleep(2)


if __name__ == "__main__":
    main()
