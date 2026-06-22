module ActivityIODataFramesExt

using ActivityIO
using DataFrames
using FileIO

function ActivityIO.get_records_df(points::Vector{ActivityIO.ActivityPoint})::DataFrame
    isempty(points) && return DataFrame()
    DataFrame(
        timestamp      = [p.timestamp for p in points],
        position_lat   = [p.lat for p in points],
        position_long  = [p.lon for p in points],
        altitude       = [p.ele for p in points],
        heart_rate     = [p.hr for p in points],
        cadence        = [p.cad for p in points]
    )
end

function ActivityIO.get_records_df(messages::Vector{ActivityIO.FitMessage})::DataFrame
    all_keys = Set{Symbol}()
    n_records = 0
    for msg in messages
        if msg.name == :record
            n_records += 1
            union!(all_keys, keys(msg.fields))
        end
    end
    n_records == 0 && return DataFrame()

    sorted_keys = sort(collect(all_keys))
    if :timestamp in sorted_keys
        filter!(k -> k != :timestamp, sorted_keys)
        pushfirst!(sorted_keys, :timestamp)
    end

    df = DataFrame()
    for k in sorted_keys
        col_data = Vector{Any}(undef, n_records)
        idx = 1
        for msg in messages
            if msg.name == :record
                col_data[idx] = get(msg.fields, k, missing)
                idx += 1
            end
        end
        df[!, k] = identity.(col_data)
    end
    return df
end

# FIT
ActivityIO.fileio_load(f::File{format"FIT"},    ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(f))
ActivityIO.fileio_load(s::Stream{format"FIT"},  ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(s))
ActivityIO.fileio_load(f::File{format"FIT_GZ"}, ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.parse_fit(f.filename))

# GPX
ActivityIO.fileio_load(f::File{format"GPX"},    ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(f))
ActivityIO.fileio_load(s::Stream{format"GPX"},  ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(s))
ActivityIO.fileio_load(f::File{format"GPX_GZ"}, ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.parse_gpx(f.filename))

# TCX
ActivityIO.fileio_load(f::File{format"TCX"},    ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(f))
ActivityIO.fileio_load(s::Stream{format"TCX"},  ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(s))
ActivityIO.fileio_load(f::File{format"TCX_GZ"}, ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.parse_tcx(f.filename))

# GZIP
ActivityIO.fileio_load(f::File{format"GZIP"}, ::Type{DataFrame}) = ActivityIO.get_records_df(ActivityIO.fileio_load(f))

end
