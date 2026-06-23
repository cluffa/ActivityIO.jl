# ActivityIO.jl

Load FIT, GPX, and TCX activity files in Julia. Supports Strava exports and optional SQLite storage.

## Installation

```julia
pkg> add https://github.com/cluffa/ActivityIO.jl
```

## Usage

```julia
using ActivityIO
using FileIO       # optional — enables load()
using DataFrames   # optional — enables get_records_df() and load_export()
using CSV          # optional — required alongside DataFrames for load_export()
using SQLite       # optional — enables load_activities_to_db() and load_from_directory()
```

### Parse a file directly

```julia
pts  = parse_gpx("activity.gpx")   # Vector{ActivityPoint}
pts  = parse_tcx("activity.tcx")   # Vector{ActivityPoint}
msgs = parse_fit("activity.fit")   # Vector{FitMessage}
```

All three accept `.gz` compressed files automatically (`.fit.gz`, `.gpx.gz`, `.tcx.gz`).

### Load via FileIO

```julia
pts  = load("activity.gpx")
msgs = load("activity.fit")
df   = load("activity.fit.gz", DataFrame)
recs = load("activity.tcx",    Vector{Dict{Symbol,Any}})
```

### Convert to records

```julia
# Returns Vector{Dict{Symbol,Any}} — works for both ActivityPoint and FitMessage vectors
records = get_records(pts)
records = get_records(msgs)
```

### Convert to DataFrame

```julia
using DataFrames
df = get_records_df(parse_gpx("activity.gpx"))
df = get_records_df(parse_fit("activity.fit"))
# columns: timestamp | position_lat | position_long | altitude | heart_rate | cadence
# FIT files also include: distance | speed | power | cadence | etc.
```

### Session header (FIT only)

```julia
msgs = parse_fit("activity.fit")
h = get_header(msgs)   # Dict{Symbol,Any} or missing

h[:sport]              # Symbol, e.g. :running, :cycling, :swimming
h[:sub_sport]          # Symbol, e.g. :trail, :road, :indoor_cycling
h[:start_time]         # DateTime
h[:total_elapsed_time] # Float64 (seconds)
h[:total_distance]     # Float64 (metres)
h[:avg_heart_rate]     # Integer (bpm)
h[:avg_speed]          # Float64 (m/s)
```

`sport` and `sub_sport` are decoded from raw Garmin FIT SDK enum bytes to Julia `Symbol`s. Unknown codes fall back to `Symbol("sport_", N)` / `Symbol("sub_sport_", N)`.

### Load a Strava export

```julia
using ActivityIO, CSV, DataFrames

acts = load_export("/path/to/strava/export")
acts = load_export("/path/to/strava/export"; activity_type="Run")
```

Returns a `DataFrame` with all columns from Strava's `activities.csv` plus:

| Added column | Type | Contents |
|---|---|---|
| `:data` | `Vector{DataFrame}` | Trackpoint records for each activity |
| `:header` | `Vector{Union{Dict,Missing}}` | FIT session header (missing for GPX/TCX) |

```julia
acts.data[1]            # DataFrame of trackpoints for the first activity
acts.header[1][:sport]  # :running — decoded sport type from FIT session
```

### SQLite storage

```julia
using ActivityIO, SQLite

# Load individual files into a database
load_activities_to_db("activities.db", ["run.fit", "ride.gpx"])

# Load an entire directory (recursive by default)
load_from_directory("activities.db", "/path/to/activities")
```

Creates two tables: `activities` (metadata) and `records` (trackpoints with the six core fields).

## Types

**`ActivityPoint`** — one trackpoint from a GPX or TCX file.

| Field | Type |
|-------|------|
| `timestamp` | `Union{DateTime, Missing}` |
| `lat` | `Union{Float64, Missing}` |
| `lon` | `Union{Float64, Missing}` |
| `ele` | `Union{Float64, Missing}` |
| `hr` | `Union{Int, Missing}` |
| `cad` | `Union{Int, Missing}` |

**`FitMessage`** — one decoded message from a binary FIT file. Fields are in `msg.fields::Dict{Symbol,Any}`. Use `get_records` to filter to `:record` messages (trackpoints), or `get_header` to extract the `:session` message.

## Field name conventions

All formats normalise to these keys in dicts and DataFrames:

| Concept | Key |
|---------|-----|
| Time | `:timestamp` |
| Latitude | `:position_lat` |
| Longitude | `:position_long` |
| Elevation | `:altitude` |
| Heart rate | `:heart_rate` |
| Cadence | `:cadence` |

FIT records carry additional fields when present (`:distance`, `:speed`, `:power`, `:enhanced_speed`, `:enhanced_altitude`, etc.).
