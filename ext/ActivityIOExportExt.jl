module ActivityIOExportExt

using ActivityIO
using CSV
using DataFrames
using FileIO

function _load_activity(f::String)
    fl = lowercase(f)
    if endswith(fl, ".fit.gz") || endswith(fl, ".fit")
        msgs = ActivityIO.parse_fit(f)
        return ActivityIO.get_records_df(msgs), ActivityIO.get_header(msgs)
    elseif endswith(fl, ".gpx.gz") || endswith(fl, ".gpx")
        pts = ActivityIO.parse_gpx(f)
        return ActivityIO.get_records_df(pts), missing
    elseif endswith(fl, ".tcx.gz") || endswith(fl, ".tcx")
        pts = ActivityIO.parse_tcx(f)
        return ActivityIO.get_records_df(pts), missing
    else
        return DataFrame(), missing
    end
end

function ActivityIO.load_export(dir::String; activity_type::Union{String,Nothing}=nothing)
    csv_path = joinpath(dir, "activities.csv")
    isfile(csv_path) || error("Not a Strava export directory: activities.csv not found in $dir")

    acts = CSV.read(csv_path, DataFrame; ntasks=1)

    if !isnothing(activity_type)
        filter!(row -> coalesce(row["Activity Type"], "") == activity_type, acts)
    end

    acts[!, :data]   = Vector{DataFrame}(undef, nrow(acts))
    acts[!, :header] = Vector{Union{Dict{Symbol,Any},Missing}}(missing, nrow(acts))

    Threads.@threads for i in 1:nrow(acts)
        fname = acts[i, "Filename"]
        if ismissing(fname)
            acts.data[i]   = DataFrame()
            acts.header[i] = missing
            continue
        end
        f = joinpath(dir, fname)
        try
            acts.data[i], acts.header[i] = _load_activity(f)
        catch e
            @warn "Failed to load file $fname" exception=e
            acts.data[i]   = DataFrame()
            acts.header[i] = missing
        end
    end

    return acts
end

end
