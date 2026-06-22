const _TP_RX   = r"<Trackpoint>([\s\S]*?)<\/Trackpoint>"
const _TIME_RX = r"<Time>([^<]+)</Time>"
const _LAT_RX  = r"<LatitudeDegrees>([^<]+)</LatitudeDegrees>"
const _LON_RX  = r"<LongitudeDegrees>([^<]+)</LongitudeDegrees>"
const _ELE_RX  = r"<AltitudeMeters>([^<]+)</AltitudeMeters>"
const _HR_RX   = r"<HeartRateBpm[^>]*>\s*<Value>([^<]+)</Value>\s*</HeartRateBpm>"
const _CAD_RX  = r"<Cadence>([^<]+)</Cadence>"

# ponytail: Regex-based parsing to avoid heavy XML/libxml2 dependencies.
function parse_tcx(file_path::String)::Vector{ActivityPoint}
    if !isfile(file_path)
        error("File not found: $file_path")
    end
    io = endswith(file_path, ".gz") ? GZip.open(file_path, "r") : open(file_path, "r")
    try
        return parse_tcx(io)
    finally
        close(io)
    end
end

function parse_tcx(io::IO)::Vector{ActivityPoint}
    content = read(io, String)
    points = ActivityPoint[]
    for m in eachmatch(_TP_RX, content)
        block     = m.captures[1]
        time_m    = match(_TIME_RX, block)
        timestamp = isnothing(time_m) ? missing : parse_timestamp(time_m.captures[1])
        lat_m     = match(_LAT_RX, block)
        lat       = isnothing(lat_m) ? missing : parse(Float64, lat_m.captures[1])
        lon_m     = match(_LON_RX, block)
        lon       = isnothing(lon_m) ? missing : parse(Float64, lon_m.captures[1])
        ele_m     = match(_ELE_RX, block)
        ele       = isnothing(ele_m) ? missing : parse(Float64, ele_m.captures[1])
        hr_m      = match(_HR_RX, block)
        hr        = isnothing(hr_m) ? missing : round(Int, parse(Float64, hr_m.captures[1]))
        cad_m     = match(_CAD_RX, block)
        cad       = isnothing(cad_m) ? missing : round(Int, parse(Float64, cad_m.captures[1]))
        push!(points, ActivityPoint(timestamp, lat, lon, ele, hr, cad))
    end
    return points
end
