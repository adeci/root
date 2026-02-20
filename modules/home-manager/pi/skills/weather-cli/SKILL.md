---
name: weather-cli
description: Get weather forecasts for any location worldwide. Use for current weather and multi-day forecasts.
---

# Weather CLI

Uses Bright Sky API (DWD/MOSMIX data). No API key required. Covers ~5400
stations worldwide.

## Install

```bash
nix run github:Mic92/mics-skills#weather-cli -- "location"
```

## Usage

```bash
weather-cli Miami                  # Current weather
weather-cli Orlando -f             # 3-day forecast (default)
weather-cli "New York" -f -d 7    # 7-day forecast
```
