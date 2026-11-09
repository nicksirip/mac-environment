#!/usr/bin/env python3
"""Rebuild ~/.config/tmux/pane-menu.conf: tmux's built-in right-click pane menus with a
Logging submenu (tmux-logging actions) inserted before "Kill".

Run inside tmux after a tmux upgrade, then: tmux source-file ~/.config/tmux/tmux.conf

It reads the live bindings and strips any Logging submenu it inserted before,
so it is safe to run while pane-menu.conf is loaded.
"""
import os
import re
import subprocess

# Kept as "~/..." on purpose: run-shell hands the command to sh, which expands ~,
# so the generated file holds no username.
S = "~/.config/tmux/plugins/tmux-logging/scripts"
OUT = os.path.expanduser("~/.config/tmux/pane-menu.conf")
ANCHOR = "'' Kill X { kill-pane }"


def item(label, key, script):
    return f'"{label}" {key} {{ select-pane ; run-shell "{S}/{script}" }}'


SUB = ("'' Logging g { display-menu -T \"#[align=centre]Logging\" -x L -y L "
       + item("#{?pane_pipe,Stop logging,Start logging}", "P", "toggle_logging.sh") + " "
       + item("Screen capture", "p", "screen_capture.sh") + " "
       + item("Save complete history", "H", "save_complete_history.sh") + " '' "
       + item("Clear history", "c", "clear_history.sh") + " } ")
# A previously inserted submenu, as tmux re-prints it (quoting may differ).
OLD_SUB = re.compile(r"'' Logging g \{ display-menu .*?clear_history\.sh \} \} ")

lines = ["# Right-click pane menus = tmux's built-in defaults (from `tmux list-keys`)",
         "# plus a Logging submenu for tmux-logging. Rebuild after a tmux upgrade:",
         "#   ~/.config/tmux/scripts/gen-pane-menu.py && tmux source-file ~/.config/tmux/tmux.conf"]
for key in ("MouseDown3Pane", "M-MouseDown3Pane"):
    line = subprocess.run(["tmux", "list-keys", "-T", "root", key],
                          capture_output=True, text=True, check=True).stdout.strip()
    line = OLD_SUB.sub("", line)
    if line.count(ANCHOR) != 1:
        raise SystemExit(f"{key}: expected one '{ANCHOR}' in the default menu, found "
                         f"{line.count(ANCHOR)}; tmux's menu changed, update ANCHOR")
    lines.append(line.replace(ANCHOR, SUB + ANCHOR))
with open(OUT, "w") as f:
    f.write("\n".join(lines) + "\n")
print("wrote", OUT)
