#!/usr/bin/env bash
# usage: focus-or-open.sh <bundle-id>
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

bundle="$1"

ids=$(aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}' |
  awk -F'|' -v b="$bundle" '
      { gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2)
        if ($2 == b) print $1 }')

# No windows -> launch (or just activate a running-but-windowless app)
if [ -z "$ids" ]; then
  open -b "$bundle"
  exit 0
fi

focused=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null | tr -d '[:space:]')

ids_arr=($ids)
count=${#ids_arr[@]}
target="${ids_arr[0]}"

for i in "${!ids_arr[@]}"; do
  if [[ "${ids_arr[$i]}" == "$focused" ]]; then
    target="${ids_arr[$(((i + 1) % count))]}"
    break
  fi
done

aerospace focus --window-id "$target" || open -b "$bundle"
