#!/bin/bash
# Cycle through ALL windows in the focused workspace (tiling + floating)
# in a deterministic order matching sketchybar icon layout.
# Sort order: app-name alphabetically, then window-id numerically.
# Usage: cycle_windows.sh [next|prev]

export PATH="/opt/homebrew/bin:$PATH"

DIRECTION="${1:-next}"

# Get sorted window IDs: sort by app-name first, then window-id (numeric)
IDS=($(aerospace list-windows --workspace focused --format '%{app-name}|%{window-id}' \
    | sort -t'|' -k1,1 -k2,2n \
    | cut -d'|' -f2))

COUNT=${#IDS[@]}
[ "$COUNT" -le 1 ] && exit 0

# Get currently focused window ID
FOCUSED=$(aerospace list-windows --focused --format '%{window-id}' | tr -d '[:space:]')

# Find index of focused window
CIDX=0
for i in "${!IDS[@]}"; do
    if [ "${IDS[$i]}" = "$FOCUSED" ]; then
        CIDX=$i
        break
    fi
done

# Calculate target index (wrap around)
if [ "$DIRECTION" = "prev" ]; then
    TIDX=$(( (CIDX - 1 + COUNT) % COUNT ))
else
    TIDX=$(( (CIDX + 1) % COUNT ))
fi

aerospace focus --window-id "${IDS[$TIDX]}"
