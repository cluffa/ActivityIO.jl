module ActivityIODataFramesExt

using ActivityIO
using DataFrames
using Dates
using FileIO

function _haversine_m(lat1::Float64, lon1::Float64, lat2::Float64, lon2::Float64)::Float64
    R = 6371000.0
    φ1 = deg2rad(lat1)
    φ2 = deg2rad(lat2)
    Δφ = deg2rad(lat2 - lat1)
    Δλ = deg2rad(lon2 - lon1)
    a = sin(Δφ/2)^2 + cos(φ1) * cos(φ2) * sin(Δλ/2)^2
    2.0 * R * asin(sqrt(a))
end

function ActivityIO.get_records_df(points::Vector{ActivityIO.ActivityPoint})::DataFrame
    isempty(points) && return DataFrame()

    n = length(points)
    timestamps = [p.timestamp for p in points]
    lats       = [p.lat       for p in points]
    lons       = [p.lon       for p in points]
    eles       = [p.ele       for p in points]
    hrs        = [p.hr        for p in points]
    cads       = [p.cad       for p in points]

    distance = Vector{Union{Float64, Missing}}(missing, n)
    speed    = Vector{Union{Float64, Missing}}(missing, n)

    cumulative = 0.0
    prev_lat = missing
    prev_lon = missing
    prev_ts  = missing

    for i in 1:n
        lat = lats[i]
        lon = lons[i]
        ts  = timestamps[i]
        (ismissing(lat) || ismissing(lon)) && continue
        if prev_lat isa Float64
            d = _haversine_m(prev_lat, prev_lon::Float64, lat::Float64, lon::Float64)
            cumulative += d
            if prev_ts isa DateTime && ts isa DateTime
                dt = (ts - prev_ts).value / 1000.0
                dt > 0 && (speed[i] = d / dt)
            end
        end
        distance[i] = cumulative
        prev_lat, prev_lon, prev_ts = lat, lon, ts
    end

    DataFrame(
        timestamp      = timestamps,
        position_lat   = lats,
        position_long  = lons,
        altitude       = eles,
        heart_rate     = hrs,
        cadence        = cads,
        distance       = distance,
        speed          = speed,
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
