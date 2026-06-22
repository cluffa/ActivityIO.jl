module ActivityIOSQLiteExt

using ActivityIO
using SQLite
using Dates

export load_activities_to_db, load_from_directory

"""
    load_activities_to_db(db_path::String, files::Vector{String}; table_name="records")

Load activity files into a SQLite database. Creates `records` and `activities` tables.
"""
function load_activities_to_db(db_path::String, files::Vector{String}; table_name="records")
    db = SQLite.DB(db_path)

    # Create activities metadata table if it doesn't exist
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS activities (
            id INTEGER PRIMARY KEY,
            filename TEXT UNIQUE NOT NULL,
            name TEXT,
            sport_type TEXT,
            num_records INTEGER,
            loaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create records table if it doesn't exist
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS $table_name (
            id INTEGER PRIMARY KEY,
            activity_id INTEGER NOT NULL,
            timestamp DATETIME,
            position_lat REAL,
            position_long REAL,
            altitude REAL,
            heart_rate INTEGER,
            cadence INTEGER,
            FOREIGN KEY(activity_id) REFERENCES activities(id)
        )
    """)

    for filepath in files
        _insert_file(db, filepath, table_name)
    end

    SQLite.close(db)
    return db_path
end

"""
    load_from_directory(db_path::String, directory::String; recursive=true)

Load all supported activity files from a directory into a SQLite database.
"""
function load_from_directory(db_path::String, directory::String; recursive=true)
    supported_exts = [".fit", ".fit.gz", ".gpx", ".gpx.gz", ".tcx", ".tcx.gz"]

    files = String[]
    if recursive
        for (root, dirs, filenames) in walkdir(directory)
            for f in filenames
                if any(endswith(f, ext) for ext in supported_exts)
                    push!(files, joinpath(root, f))
                end
            end
        end
    else
        for f in readdir(directory)
            if any(endswith(f, ext) for ext in supported_exts)
                push!(files, joinpath(directory, f))
            end
        end
    end

    return load_activities_to_db(db_path, files)
end

function _insert_file(db::SQLite.DB, filepath::String, table_name::String)
    try
        points = ActivityIO.fileio_load(filepath)
        isempty(points) && return

        records = ActivityIO.get_records(points)
        name = basename(filepath)
        sport_type = _infer_sport_type(filepath, records)

        # Insert activity metadata
        SQLite.execute(db,
            "INSERT OR IGNORE INTO activities (filename, name, sport_type, num_records) VALUES (?, ?, ?, ?)",
            [filepath, name, sport_type, length(records)]
        )

        # Get the activity ID
        activity_id = SQLite.execute(db, "SELECT id FROM activities WHERE filename = ?", [filepath]) |>
                       x -> x[1, 1]

        # Insert records
        for rec in records
            SQLite.execute(db,
                "INSERT INTO $table_name (activity_id, timestamp, position_lat, position_long, altitude, heart_rate, cadence)
                 VALUES (?, ?, ?, ?, ?, ?, ?)",
                [activity_id,
                 rec[:timestamp],
                 rec[:position_lat],
                 rec[:position_long],
                 rec[:altitude],
                 rec[:heart_rate],
                 rec[:cadence]]
            )
        end
    catch e
        @warn "Failed to load $filepath: $e"
    end
end

function _infer_sport_type(filepath::String, records::Vector{Dict{Symbol, Any}})
    # Try to infer from filename or records
    fl = lowercase(filepath)
    if endswith(fl, ".fit") || endswith(fl, ".fit.gz")
        # FIT files may have sport_type in records
        for rec in records
            haskey(rec, :sport) && return string(rec[:sport])
        end
    end
    return "unknown"
end

end # module
