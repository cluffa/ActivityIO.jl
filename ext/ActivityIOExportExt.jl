module ActivityIOExportExt

using ActivityIO
using CSV
using DataFrames
using FileIO

function ActivityIO.load_export(dir::String; activity_type::Union{String,Nothing}=nothing)
    csv_path = joinpath(dir, "activities.csv")
    isfile(csv_path) || error("Not a Garmin export directory: activities.csv not found in $dir")

    acts = CSV.read(csv_path, DataFrame; ntasks=1)

    if !isnothing(activity_type)
        filter!(row -> coalesce(row["Activity Type"], "") == activity_type, acts)
    end

    acts.data = Vector{DataFrame}(undef, nrow(acts))
    Threads.@threads for i in 1:nrow(acts)
        fname = acts[i, "Filename"]
        if ismissing(fname)
            acts.data[i] = DataFrame()
            continue
        end
        f = joinpath(dir, fname)
        try
            acts.data[i] = load(f, DataFrame)
        catch
            acts.data[i] = DataFrame()
        end
    end

    return acts
end

end
