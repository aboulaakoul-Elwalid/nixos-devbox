#!/usr/bin/env bash
# probe-gtk-dialog.sh — does a native GTK file dialog accept synthetic input?
#
# THE QUESTION
#   Driving the "Choose folder…" dialog in VSCodium failed with keyboard input,
#   both nested and on the host. Two explanations fit that evidence equally well:
#
#     (a) GTK portal dialogs ignore virtual-keyboard (zwp_virtual_keyboard) input
#     (b) our input never reaches the dialog at all (focus, seat, routing)
#
#   They call for opposite fixes, so guessing is expensive. Pointer input
#   discriminates: it travels a different path (wlrctl virtual-pointer) than
#   the keyboard. If clicking works and typing does not, it is (a). If neither
#   works, it is (b).
#
# THE ORACLE
#   We do not infer success from pixels. The dialog is summoned through the
#   xdg-desktop-portal FileChooser API, so the portal itself reports what was
#   picked, over D-Bus, as a list of URIs. That is ground truth: a click that
#   merely highlights a row and a click that actually selects a file look
#   identical in a screenshot but differ completely here.
#
#   ./qa/probe-gtk-dialog.sh pointer     click a file row
#   ./qa/probe-gtk-dialog.sh keyboard    Ctrl+L, type a path, Enter
#   ./qa/probe-gtk-dialog.sh inspect     just open it and dump geometry
#
# The dialog appears on the CURRENT desktop by design — host input is the
# measured-working path, and this probe is about input fidelity, not isolation.
set -uo pipefail

MODE="${1:-inspect}"
WORK="$(mktemp -d /tmp/gtkprobe-XXXXXX)"
PORTAL_DEST="org.freedesktop.portal.Desktop"
PORTAL_PATH="/org/freedesktop/portal/desktop"
MON_PID=""
CALL_PID=""

# A pending portal dialog IGNORES `hyprctl closewindow` — the request is still
# open, so GTK keeps the window. Sixteen of them piled onto the desktop before
# this was understood. Cancel must be CLICKED, which is also the input path
# measured to work.
_dismiss() {
  local geo dx dy dw i
  for i in 1 2 3; do
    geo="$(_dialog_geo)"; [ -z "$geo" ] && return 0
    read -r dx dy dw _ <<< "$geo"
    hyprctl dispatch focuswindow "address:$(_dialog_addr)" >/dev/null 2>&1
    sleep 0.3
    hcu-click $(( dx + 45 )) $(( dy + 22 )) >/dev/null 2>&1   # Cancel, top-left
    sleep 0.8
  done
}

cleanup() {
  [ -n "$MON_PID" ] && kill "$MON_PID" 2>/dev/null
  [ -n "$CALL_PID" ] && kill "$CALL_PID" 2>/dev/null
  _dismiss
  rm -rf "$WORK"
}
trap cleanup EXIT

# The GTK portal implementation owns the dialog window, so match on its class
# rather than the title (titles are localised and change per request).
_dialog_addr() {
  hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: d = []
for c in d:
    if "portal" in c.get("class", "").lower() or c.get("title", "") in ("Open File", "Open Folder"):
        print(c["address"]); break
' 2>/dev/null
}

_dialog_geo() {
  hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: d = []
for c in d:
    if "portal" in c.get("class", "").lower() or c.get("title", "") in ("Open File", "Open Folder"):
        print("%d %d %d %d %s | %s" % (c["at"][0], c["at"][1], c["size"][0], c["size"][1],
                                       c.get("class",""), c.get("title","")))
        break
' 2>/dev/null
}

echo "=== summoning a real portal FileChooser dialog ==="

# Watch the bus BEFORE calling, so the Response signal cannot be missed.
gdbus monitor --session --dest "$PORTAL_DEST" > "$WORK/bus.log" 2>&1 &
MON_PID=$!
sleep 1

# OpenFile blocks in the background until the user (or us) answers it.
# PROBE_DIRECTORY=1 asks for a folder chooser — the mode VSCodium's "Open
# Folder" actually uses. In file mode, clicking a directory only navigates into
# it, so a folder can never be "confirmed"; that is correct GTK behaviour and
# must not be mistaken for an input failure.
OPTS="{}"
[ -n "${PROBE_DIRECTORY:-}" ] && OPTS="{'directory': <true>}"
gdbus call --session --dest "$PORTAL_DEST" --object-path "$PORTAL_PATH" \
  --method org.freedesktop.portal.FileChooser.OpenFile \
  "" "probe-$$" "$OPTS" > "$WORK/call.log" 2>&1 &
CALL_PID=$!

ADDR=""
for i in $(seq 1 40); do
  sleep 0.5
  ADDR="$(_dialog_addr)"
  [ -n "$ADDR" ] && break
done
[ -z "$ADDR" ] && { echo "FAIL: no dialog window appeared within 20s"; cat "$WORK/call.log"; exit 1; }

GEO="$(_dialog_geo)"
echo "dialog window: $GEO"
read -r DX DY DW DH _ <<< "$GEO"

# Focus it explicitly. Trusting spawn-order focus has bitten this project
# before; the compositor's own IPC is the authoritative way to say "this one".
hyprctl dispatch focuswindow "address:$ADDR" >/dev/null 2>&1
sleep 0.8
FOCUSED="$(hyprctl activewindow -j | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("address",""),"|",d.get("class",""))')"
echo "active window after focuswindow: $FOCUSED"

OUT="$WORK/dialog.png" hcu-capture window 'portal|Open File' 2>/dev/null || \
  OUT="$WORK/dialog.png" hcu-capture output >/dev/null 2>&1
echo "screenshot: $WORK/dialog.png"

case "$MODE" in
  inspect)
    echo "(inspect only — leaving dialog up for 10s)"
    sleep 10
    ;;

  pointer)
    # Offsets read off an actual capture of this dialog (941x509): the header
    # row sits at y=57 and the first file row at y=84, ~24px apart; "Select" is
    # top-right at (DW-47, 22). Window coords, so they hold wherever Hyprland
    # places the window.
    ROW_X=$(( DX + 250 ))
    ROW_Y=$(( DY + 84 ))
    SEL_X=$(( DX + DW - 47 ))
    SEL_Y=$(( DY + 22 ))

    echo "pointer: click first file row at ${ROW_X},${ROW_Y}"
    hcu-click "$ROW_X" "$ROW_Y"
    sleep 1
    OUT="$WORK/after-row-click.png" hcu-capture window 'portal|Open File' >/dev/null 2>&1

    # Confirm with the Select button rather than a double-click: a double-click
    # on a directory row only descends into it, which would look like "nothing
    # happened" to the oracle even though the pointer worked perfectly.
    echo "pointer: click Select at ${SEL_X},${SEL_Y}"
    hcu-click "$SEL_X" "$SEL_Y"
    sleep 2
    OUT="$WORK/after-select.png" hcu-capture output >/dev/null 2>&1
    ;;

  keyboard)
    # Tunable so the failure can be attributed instead of guessed:
    #   PROBE_SETTLE        pause after Ctrl+L before typing
    #   HCU_TYPE_STRATEGY   chunk | perchar | paste (read by hcu-type)
    SETTLE="${PROBE_SETTLE:-0.8}"
    TEXT="${PROBE_TEXT:-/etc/hostname}"
    echo "keyboard: Ctrl+L, settle=${SETTLE}s, strategy=${HCU_TYPE_STRATEGY:-chunk}, text=$TEXT"
    wtype -M ctrl -k l -m ctrl 2>/dev/null
    sleep "$SETTLE"
    # The GTK file chooser REMEMBERS the location entry across dialog sessions,
    # so a fresh dialog can open with a previous run's path already in it and
    # new text is inserted into that leftover instead of replacing it. Select
    # all first so the first typed character clears whatever was there.
    if [ -n "${PROBE_CLEAR:-}" ]; then
      echo "  clearing entry first (ctrl+a)"
      wtype -M ctrl -k a -m ctrl 2>/dev/null
      sleep 0.4
    fi
    # PROBE_DELAY types the whole string through ONE virtual keyboard with
    # wtype's own inter-key delay. hcu-type's chunking spawns a fresh keyboard
    # per chunk, and GTK's location bar runs an async completion after every
    # keystroke — keyboard churn during that window is where characters vanish.
    # 'single' commits text and Return together below, so it must not type here.
    if [ "${PROBE_CONFIRM:-return}" = "single" ]; then
      :
    elif [ -n "${PROBE_SPLIT:-}" ]; then
      # In the GTK file chooser "/" is itself a shortcut that opens the location
      # entry. Sending it as part of a fast stream re-triggers that handler and
      # the NEXT keystroke is consumed by the reopening entry — which is exactly
      # the character observed missing every time. Send the leading "/" alone,
      # let the entry settle, then type the remainder.
      echo "  typing via: split leading '/' then remainder (settle ${PROBE_SPLIT}s)"
      wtype "${TEXT:0:1}" 2>/dev/null
      sleep "$PROBE_SPLIT"
      wtype -d "${PROBE_DELAY:-60}" "${TEXT:1}" 2>/dev/null
    elif [ -n "${PROBE_DELAY:-}" ]; then
      echo "  typing via: wtype -d $PROBE_DELAY (single keyboard)"
      wtype -d "$PROBE_DELAY" "$TEXT" 2>/dev/null
    else
      hcu-type "$TEXT" 2>/dev/null
    fi
    sleep 0.8
    # READBACK: what is ACTUALLY in the entry? Select-all + copy, then read the
    # clipboard. This replaces screenshot-squinting with an exact string, which
    # is the difference between "looks right" and "is right" — the dropped 'e'
    # in /etc/hostname was invisible at a glance.
    if [ -n "${PROBE_READBACK:-}" ]; then
      SAVED_CLIP="$(wl-paste --no-newline 2>/dev/null || true)"
      wl-copy --clear 2>/dev/null || true
      sleep 0.2
      wtype -M ctrl -k a -m ctrl 2>/dev/null; sleep 0.3
      wtype -M ctrl -k c -m ctrl 2>/dev/null; sleep 0.5
      GOT="$(wl-paste --no-newline 2>/dev/null || true)"
      printf '  entry text : [%s]\n' "$GOT"
      if [ "$GOT" = "$TEXT" ]; then echo "  entry match: EXACT"
      else echo "  entry match: MISMATCH (wanted [$TEXT])"; fi
      # Deselect so the confirm step does not act on a selection.
      wtype -k End 2>/dev/null; sleep 0.3
      if [ -n "$SAVED_CLIP" ]; then printf '%s' "$SAVED_CLIP" | wl-copy
      else wl-copy --clear 2>/dev/null || true; fi
    fi

    # Inline completion leaves a SELECTED suffix; a stray keystroke would
    # replace it. PROBE_POSTKEY dismisses or accepts it deliberately.
    if [ -n "${PROBE_POSTKEY:-}" ]; then
      echo "  post-key: $PROBE_POSTKEY"
      wtype -k "$PROBE_POSTKEY" 2>/dev/null
      sleep 0.5
    fi
    OUT="$WORK/after-typing.png" hcu-capture window 'portal|Open File' >/dev/null 2>&1
    # How the entry gets committed. Each is a different input path, and they
    # fail independently of whether the text itself is correct.
    case "${PROBE_CONFIRM:-return}" in
      return) echo "  confirm: separate wtype -k Return"
              wtype -k Return 2>/dev/null ;;
      single) echo "  confirm: text+Return in ONE wtype call"
              wtype -d "${PROBE_DELAY:-250}" "$TEXT" -k Return 2>/dev/null ;;
      kpenter) echo "  confirm: wtype -k KP_Enter"
              wtype -k KP_Enter 2>/dev/null ;;
      click)  echo "  confirm: pointer click on Select"
              hcu-click $(( DX + DW - 47 )) $(( DY + 22 )) ;;
    esac
    sleep 2
    OUT="$WORK/after-keyboard.png" hcu-capture window 'portal|Open File' >/dev/null 2>&1
    ;;
esac

# --- oracle: what does the portal itself say happened? ---
echo
echo "=== oracle (portal D-Bus response) ==="
STILL_OPEN="$(_dialog_addr)"
if [ -n "$STILL_OPEN" ]; then
  echo "dialog still open : YES  (nothing was confirmed)"
else
  echo "dialog still open : no   (it closed — something answered it)"
fi

# Give the response signal a moment to land, then read the uris out of it.
sleep 1
python3 - "$WORK/bus.log" <<'PY'
import re, sys
log = open(sys.argv[1], errors="replace").read()
resp = [l for l in log.splitlines() if "Request.Response" in l or "'uris'" in l]
uris = re.findall(r"file://[^']+", log)
print("response signals  : %d" % len(resp))
print("uris returned     : %s" % (uris if uris else "<none>"))
if resp:
    print("--- raw ---")
    for l in resp[:6]:
        print("  " + l.strip()[:220])
PY

echo
echo "call result: $(tr -d '\n' < "$WORK/call.log" | head -c 200)"
echo "artifacts kept in: $WORK"
trap - EXIT
[ -n "$MON_PID" ] && kill "$MON_PID" 2>/dev/null
[ -n "$CALL_PID" ] && kill "$CALL_PID" 2>/dev/null
_dismiss
exit 0
