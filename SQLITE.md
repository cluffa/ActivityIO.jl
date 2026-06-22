# SQLite Integration

ActivityIO can load activity files into a SQLite database for analysis and querying.

## Usage

```julia
using ActivityIO, SQLite

# Load files into a database
files = ["activity1.gpx", "activity2.fit.gz", "activity3.tcx"]
load_activities_to_db("activities.db", files)

# Or load all files from a directory
load_from_directory("activities.db", "/path/to/activities"; recursive=true)
```

## Schema

The database creates two tables:

**`activities`** — Metadata for each loaded file:
- `id` — Unique identifier
- `filename` — Path to the source file
- `name` — Filename
- `sport_type` — Activity type (when available)
- `num_records` — Number of data points loaded
- `loaded_at` — Timestamp when the file was loaded

**`records`** — Point-level activity data:
- `id` — Record ID
- `activity_id` — Foreign key to activities table
- `timestamp` — Time of the measurement
- `position_lat`, `position_long` — Coordinates (if available)
- `altitude` — Elevation (if available)
- `heart_rate` — HR (if available)
- `cadence` — Cadence (if available)

## Query Examples

```julia
using SQLite, DataFrames

db = SQLite.DB("activities.db")

# All activities
SQLite.execute(db, "SELECT * FROM activities") |> DataFrame

# Total distance by activity (if your records have distance)
SQLite.execute(db, """
    SELECT a.name, COUNT(*) as num_records
    FROM records r
    JOIN activities a ON r.activity_id = a.id
    GROUP BY a.id
""") |> DataFrame

# Close the database
SQLite.close(db)
```

## Custom Table Names

By default, records are stored in a `records` table. Customize with:

```julia
load_activities_to_db("activities.db", files; table_name="runs")
```
