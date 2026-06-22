# ActivityIO.jl

Load FIT, GPX, and TCX activity files in Julia. Supports Strava exports.

## Installation

```julia
pkg> add https://github.com/cluffa/ActivityIO.jl
```

## Usage

```julia
using ActivityIO
using FileIO       # optional — enables load()
using DataFrames   # optional — enables get_records_df()
```

### Parse a file directly

```julia
pts  = parse_gpx("activity.gpx")   # Vector{ActivityPoint}
pts  = parse_tcx("activity.tcx")   # Vector{ActivityPoint}
msgs = parse_fit("activity.fit")   # Vector{FitMessage}
```

All three accept `.gz` compressed files automatically.

### Load via FileIO

```julia
pts  = load("activity.gpx")
df   = load("activity.fit.gz", DataFrame)
recs = load("activity.tcx",    Vector{Dict{Symbol,Any}})
```

### Convert to DataFrame

```julia
df = get_records_df(parse_gpx("activity.gpx"))
# timestamp | position_lat | position_long | altitude | heart_rate | cadence
```

### Convert to dicts

```julia
records = get_records(pts)   # Vector{Dict{Symbol,Any}}
```

### Load a Strava export

```julia
using ActivityIO, CSV, DataFrames

runs = load_export("/path/to/strava/export"; activity_type="Run")
# DataFrame with all activities.csv columns + :data (Vector{DataFrame} of trackpoints)
```

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

**`FitMessage`** — one decoded message from a FIT file (name, global_num, fields dict). Use `get_records` to filter to trackpoint records only.

## Dict / DataFrame field names

| Concept | Key |
|---------|-----|
| Time | `:timestamp` |
| Latitude | `:position_lat` |
| Longitude | `:position_long` |
| Elevation | `:altitude` |
| Heart rate | `:heart_rate` |
| Cadence | `:cadence` |

FIT records include additional fields (`:distance`, `:speed`, `:power`, etc.) when present in the file.
