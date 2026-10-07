#!/usr/bin/env bash
# <swiftbar.title>Yeruham Weather</swiftbar.title>
# <swiftbar.version>1.0</swiftbar.version>
# <swiftbar.desc>Current conditions from Wunderground PWS IYERUHAM2</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.environment>[WU_KEY:]</swiftbar.environment>

# SwiftBar runs plugins with a minimal PATH; make sure Homebrew's jq is found.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STATION="IYERUHAM2"
DASH="https://www.wunderground.com/dashboard/pws/$STATION"
STALE_MIN=30   # show a warning marker if the reading is older than this

# API key: set WU_KEY in SwiftBar's plugin settings, or put it in this file.
KEY="${WU_KEY:-$(cat "$HOME/.config/swiftbar/weather/apikey" 2>/dev/null)}"

footer() {
  echo "---"
  echo "Open dashboard | href=$DASH sfimage=safari"
  echo "Refresh | refresh=true sfimage=arrow.clockwise"
}

if [ -z "$KEY" ]; then
  echo "?°C"
  echo "---"
  echo "No API key set"
  echo "Set WU_KEY in the plugin settings, or write it to ~/.config/swiftbar/weather/apikey"
  footer
  exit 0
fi

URL="https://api.weather.com/v2/pws/observations/current?stationId=$STATION&format=json&units=m&numericPrecision=decimal&apiKey=$KEY"
resp=$(curl -s -m 10 -w '\n%{http_code}' "$URL")
code=${resp##*$'\n'}
body=${resp%$'\n'*}

case "$code" in
  200) ;;
  204)
    echo "–°C"
    echo "---"
    echo "No recent data (station hasn't reported in the last hour)"
    footer; exit 0 ;;
  401|403)
    echo "?°C"
    echo "---"
    echo "API key rejected (HTTP $code)"
    footer; exit 0 ;;
  *)
    echo "?°C"
    echo "---"
    echo "Fetch failed (HTTP ${code:-none})"
    footer; exit 0 ;;
esac

# One jq call -> tab-separated fields; missing values become "–".
IFS=$'\t' read -r obs epoch temp dew hum wspd wgust wdir pres rate rain uv sol < <(
  echo "$body" | jq -r '.observations[0] | [
    .obsTimeLocal, .epoch,
    .metric.temp, .metric.dewpt, .humidity,
    .metric.windSpeed, .metric.windGust, .winddir,
    .metric.pressure, .metric.precipRate, .metric.precipTotal,
    .uv, .solarRadiation
  ] | map(. // "–") | @tsv'
)

compass() {
  local pts=(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW)
  [[ "$1" =~ ^[0-9.]+$ ]] || { echo "–"; return; }
  echo "${pts[$(( (${1%.*} * 100 + 1125) / 2250 % 16 ))]}"
}

age_min=""
[[ "$epoch" =~ ^[0-9]+$ ]] && age_min=$(( ( $(date +%s) - epoch ) / 60 ))

# fixed width; trim=false keeps the padding
title="$(printf '%2.0f' "$temp")°C"
if [ -n "$age_min" ] && [ "$age_min" -gt "$STALE_MIN" ]; then
  title="⚠ $title"
fi
echo "$title | font=Menlo trim=false"

echo "---"
echo "Yeruham · $STATION | size=12"
echo "Humidity: ${hum}% (dew point ${dew}°C) | sfimage=humidity bash=/usr/bin/true terminal=false"
echo "Wind: ${wspd} km/h $(compass "$wdir"), gusts ${wgust} | sfimage=wind bash=/usr/bin/true terminal=false"
echo "Pressure: ${pres} hPa | sfimage=gauge bash=/usr/bin/true terminal=false"
echo "Rain: ${rate} mm/h now, ${rain} mm today | sfimage=cloud.rain bash=/usr/bin/true terminal=false"
echo "UV ${uv} · Solar ${sol} W/m² | sfimage=sun.max bash=/usr/bin/true terminal=false"
echo "---"
if [ -n "$age_min" ]; then
  echo "Updated ${obs#* } (${age_min} min ago) | size=11"
else
  echo "Updated ${obs#* } | size=11"
fi
footer
