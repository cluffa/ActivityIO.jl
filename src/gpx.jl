function parse_timestamp(s::AbstractString)::DateTime
    dt = DateTime(s[1:19], dateformat"yyyy-mm-ddTHH:MM:SS")
    length(s) < 20 && return dt
    s[20] == 'Z' && return dt
    sign = s[20] == '+' ? 1 : -1
    h, m = parse(Int, s[21:22]), parse(Int, s[24:25])
    dt - Minute(sign * (60h + m))
end

# ponytail: Regex-based parsing to avoid heavy XML/libxml2 dependencies.
function parse_gpx(file_path::String)::Vector{ActivityPoint}
    if !isfile(file_path)
        error("File not found: $file_path")
    end
    io = endswith(file_path, ".gz") ? GZip.open(file_path, "r") : open(file_path, "r")
    try
        return parse_gpx(io)
    finally
        close(io)
    end
end

function parse_gpx(io::IO)::Vector{ActivityPoint}
    content = read(io, String)

    # ponytail: attrs group lets lat/lon appear in any order
    trkpt_rx = r"<(trkpt|wpt|rtept)\s+([^>]+)>([\s\S]*?)<\/\1>"
    lat_rx    = r"lat=\"([^\"]+)\""
    lon_rx    = r"lon=\"([^\"]+)\""
    ele_rx    = r"<ele>([^<]+)</ele>"
    time_rx   = r"<time>([^<]+)</time>"
    hr_rx     = r"<(?:gpxtpx:)?hr>([^<]+)</(?:gpxtpx:)?hr>"
    cad_rx    = r"<(?:gpxtpx:)?cad>([^<]+)</(?:gpxtpx:)?cad>"

    points = ActivityPoint[]
    for m in eachmatch(trkpt_rx, content)
        attrs = m.captures[2]
        block = m.captures[3]

        lat_m = match(lat_rx, attrs)
        lon_m = match(lon_rx, attrs)
        (isnothing(lat_m) || isnothing(lon_m)) && continue

        lat       = parse(Float64, lat_m.captures[1])
        lon       = parse(Float64, lon_m.captures[1])
        ele_m     = match(ele_rx, block)
        ele       = isnothing(ele_m) ? missing : parse(Float64, ele_m.captures[1])
        time_m    = match(time_rx, block)
        timestamp = isnothing(time_m) ? missing : parse_timestamp(time_m.captures[1])
        hr_m      = match(hr_rx, block)
        hr        = isnothing(hr_m) ? missing : round(Int, parse(Float64, hr_m.captures[1]))
        cad_m     = match(cad_rx, block)
        cad       = isnothing(cad_m) ? missing : round(Int, parse(Float64, cad_m.captures[1]))

        push!(points, ActivityPoint(timestamp, lat, lon, ele, hr, cad))
    end
    return points
end
