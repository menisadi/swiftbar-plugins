#!/usr/bin/env bash
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.title>pbar</swiftbar.title>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.environment>[HOST:google.com]</swiftbar.environment>

HOST="${HOST:-google.com}"

while :; do ping -i 1 "$HOST" 2>/dev/null; sleep 2; done | awk -v host="$HOST" '
BEGIN { N = 20; ESC = sprintf("%c", 27); print "~~~"; print "… | color=#8E8E93"; fflush() }

function hex(t) {
  if (t < 0)   return "#8E8E93"
  if (t < 50)  return "#34C759"
  if (t < 100) return "#FFCC00"
  if (t < 200) return "#FF9500"
  return "#FF3B30"
}

function sfcfg(t,   c, cmd, b) {
  c = hex(t)
  if (!(c in cfg)) {
    cmd = "printf %s '\''{\"renderingMode\":\"Palette\",\"colors\":[\"" c "\"],\"scale\":\"small\"}'\'' | base64"
    cmd | getline b; close(cmd)
    cfg[c] = b
  }
  return cfg[c]
}

# nearest xterm-256 colors to hex() (SwiftBar has no truecolor ANSI)
function cell(t,   c) {
  if (t < 0) return ESC "[90m░" ESC "[0m"
  if (t < 50)       c = 77
  else if (t < 100) c = 220
  else if (t < 200) c = 208
  else              c = 196
  return ESC "[38;5;" c "m█" ESC "[0m"
}

function push(t,   i, start, h, ok, sum, lost, n, label) {
  s[++k] = t
  delete s[k - N]
  start = k - N + 1; if (start < 1) start = 1
  h = ""; ok = 0; sum = 0; lost = 0; n = 0
  for (i = start; i <= k; i++) {
    h = h cell(s[i]); n++
    if (s[i] >= 0) { ok++; sum += s[i] } else lost++
  }
  label = (t < 0) ? "timeout" : sprintf("%d ms", t)

  print "~~~"
  printf "%s | sfimage=circle.fill sfconfig=%s\n", label, sfcfg(t)
  print "---"
  printf "%s | ansi=true font=Menlo size=15 bash=/usr/bin/true terminal=false\n", h
  if (ok) printf "avg %.0f ms · loss %d/%d | font=Menlo size=12 bash=/usr/bin/true terminal=false\n", sum/ok, lost, n
  printf "host: %s | font=Menlo size=12 bash=/usr/bin/true terminal=false\n", host
  fflush()
}

/Request timeout|[Uu]nreachable/ { push(-1); next }
/bytes from/ {
  if (match($0, /time[=<][0-9.]+/)) push(substr($0, RSTART + 5, RLENGTH - 5) + 0)
}
'
