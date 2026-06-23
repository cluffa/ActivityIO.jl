module ActivityIO

using Dates
using EzXML
using GZip
using FileIO

export ActivityPoint, FitMessage
export parse_fit, parse_gpx, parse_tcx
export get_records, get_records_df, get_header, load_export

struct ActivityPoint
    timestamp::Union{DateTime, Missing}
    lat::Union{Float64, Missing}
    lon::Union{Float64, Missing}
    ele::Union{Float64, Missing}
    hr::Union{Int, Missing}
    cad::Union{Int, Missing}
end

include("fit.jl")
include("gpx.jl")
include("tcx.jl")

function __init__()
    # Clear any FITS mapping for .fit files (avoid FITSIO conflict)
    for ext in (".fit", ".FIT")
        if haskey(FileIO.ext2sym, ext)
            val = FileIO.ext2sym[ext]
            (val == :FITS || (isa(val, Vector) && :FITS in val)) && delete!(FileIO.ext2sym, ext)
        end
    end

    add_format(format"FIT",     detect_fit_magic,           [".fit", ".FIT"], [@__MODULE__])
    add_format(format"FIT_GZ",  (),                         [".fit.gz"],      [@__MODULE__])
    add_format(format"GPX",     "<gpx",                     [".gpx"],         [@__MODULE__])
    add_format(format"GPX_GZ",  (),                         [".gpx.gz"],      [@__MODULE__])
    add_format(format"TCX",     "<TrainingCenterDatabase",  [".tcx"],         [@__MODULE__])
    add_format(format"TCX_GZ",  (),                         [".tcx.gz"],      [@__MODULE__])

    thismod = @__MODULE__
    for sym in (:FIT, :FIT_GZ, :FITS, :GZIP)
        if haskey(FileIO.sym2loader, sym) && !(thismod in FileIO.sym2loader[sym])
            push!(FileIO.sym2loader[sym], thismod)
        end
    end
end

# --- FIT ---
fileio_load(f::File{format"FIT"})  = open(f) do s; parse_fit(s.io); end
fileio_load(s::Stream{format"FIT"}) = parse_fit(s.io)
fileio_load(f::File{format"FIT"},  ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(f))
fileio_load(f::File{format"FIT"},  ::Type{Vector{Dict}})             = fileio_load(f, Vector{Dict{Symbol,Any}})
fileio_load(s::Stream{format"FIT"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(s))
fileio_load(s::Stream{format"FIT"}, ::Type{Vector{Dict}})             = fileio_load(s, Vector{Dict{Symbol,Any}})
fileio_load(f::File{format"FIT_GZ"})                                  = parse_fit(f.filename)
fileio_load(f::File{format"FIT_GZ"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(parse_fit(f.filename))
fileio_load(f::File{format"FIT_GZ"}, ::Type{Vector{Dict}})             = fileio_load(f, Vector{Dict{Symbol,Any}})

# Intercept FileIO's FITS routing for Garmin .fit files
function fileio_load(f::File{format"FITS"}, args...)
    fl = lowercase(f.filename)
    if endswith(fl, ".fit") || endswith(fl, ".fit.gz")
        msgs = parse_fit(f.filename)
        isempty(args) && return msgs
        T = args[1]
        (T == Vector{Dict} || T == Vector{Dict{Symbol,Any}}) && return get_records(msgs)
        string(T) == "DataFrame" && return get_records_df(msgs)
        error("Unsupported type for Garmin FIT: $T")
    end
    error("Not a Garmin FIT file. For FITS images, install and load FITSIO.jl.")
end

# --- GPX ---
fileio_load(f::File{format"GPX"})   = open(f) do s; parse_gpx(s.io); end
fileio_load(s::Stream{format"GPX"}) = parse_gpx(s.io)
fileio_load(f::File{format"GPX"},  ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(f))
fileio_load(f::File{format"GPX"},  ::Type{Vector{Dict}})             = fileio_load(f, Vector{Dict{Symbol,Any}})
fileio_load(s::Stream{format"GPX"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(s))
fileio_load(s::Stream{format"GPX"}, ::Type{Vector{Dict}})             = fileio_load(s, Vector{Dict{Symbol,Any}})
fileio_load(f::File{format"GPX_GZ"})                                  = parse_gpx(f.filename)
fileio_load(f::File{format"GPX_GZ"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(parse_gpx(f.filename))
fileio_load(f::File{format"GPX_GZ"}, ::Type{Vector{Dict}})             = fileio_load(f, Vector{Dict{Symbol,Any}})

# --- TCX ---
fileio_load(f::File{format"TCX"})   = open(f) do s; parse_tcx(s.io); end
fileio_load(s::Stream{format"TCX"}) = parse_tcx(s.io)
fileio_load(f::File{format"TCX"},  ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(f))
fileio_load(f::File{format"TCX"},  ::Type{Vector{Dict}})             = fileio_load(f, Vector{Dict{Symbol,Any}})
fileio_load(s::Stream{format"TCX"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(s))
fileio_load(s::Stream{format"TCX"}, ::Type{Vector{Dict}})             = fileio_load(s, Vector{Dict{Symbol,Any}})
fileio_load(f::File{format"TCX_GZ"})                                  = parse_tcx(f.filename)
fileio_load(f::File{format"TCX_GZ"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(parse_tcx(f.filename))
fileio_load(f::File{format"TCX_GZ"}, ::Type{Vector{Dict}})             = fileio_load(f, Vector{Dict{Symbol,Any}})

# --- GZIP dispatch (clean: no Base.loaded_modules inspection needed) ---
function fileio_load(f::File{format"GZIP"})
    fl = lowercase(f.filename)
    if     endswith(fl, ".fit.gz"); parse_fit(f.filename)
    elseif endswith(fl, ".gpx.gz"); parse_gpx(f.filename)
    elseif endswith(fl, ".tcx.gz"); parse_tcx(f.filename)
    else   error("No loader defined for GZIP file: $(f.filename)")
    end
end
fileio_load(f::File{format"GZIP"}, ::Type{Vector{Dict{Symbol,Any}}}) = get_records(fileio_load(f))
fileio_load(f::File{format"GZIP"}, ::Type{Vector{Dict}})             = get_records(fileio_load(f))

# --- get_records ---
function get_records(points::Vector{ActivityPoint})::Vector{Dict{Symbol,Any}}
    records = Dict{Symbol,Any}[]
    sizehint!(records, length(points))
    for p in points
        push!(records, Dict{Symbol,Any}(
            :timestamp     => p.timestamp,
            :position_lat  => p.lat,
            :position_long => p.lon,
            :altitude      => p.ele,
            :heart_rate    => p.hr,
            :cadence       => p.cad
        ))
    end
    return records
end

function get_records(messages::Vector{FitMessage})::Vector{Dict{Symbol,Any}}
    [msg.fields for msg in messages if msg.name == :record]
end

function get_header(messages::Vector{FitMessage})::Union{Dict{Symbol,Any}, Missing}
    for msg in messages
        msg.name == :session && return copy(msg.fields)
    end
    return missing
end

get_records_df(args...) = error("get_records_df requires DataFrames: `using DataFrames`")
load_export(args...; kwargs...) = error("load_export requires CSV and DataFrames: `using CSV, DataFrames`")

end # module
