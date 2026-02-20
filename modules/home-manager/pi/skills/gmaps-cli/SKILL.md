---
name: gmaps-cli
description: Search for places and get directions using Google Maps. Use for finding locations, nearby places, and route planning.
---

# Google Maps CLI

Requires a Google Maps API key (enable Places API + Directions API in
Google Cloud Console).

## Install

```bash
nix run github:Mic92/mics-skills#gmaps-cli -- --help
```

## Setup

```bash
gmaps-cli setup --api-key-command "cat ~/.config/gmaps/api-key"
```

Or store the key in `~/.config/gmaps/config.json`.

## Usage

```bash
# Search for a specific place
gmaps-cli search "Nobu Malibu"

# Find nearby places
gmaps-cli nearby "coffee" --limit 5
gmaps-cli nearby "restaurants" --location "26.1224,-80.1373" --limit 3

# Get directions
gmaps-cli route "Miami" "Orlando"
gmaps-cli route "Times Square" "Central Park" --mode walking
gmaps-cli route "Brooklyn" "Manhattan" --mode transit
```
