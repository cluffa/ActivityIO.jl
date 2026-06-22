function parse_timestamp(s::AbstractString)::DateTime
    dt = DateTime(s[1:19], dateformat"yyyy-mm-ddTHH:MM:SS")
    length(s) < 20 && return dt
    s[20] == 'Z' && return dt
    sign = s[20] == '+' ? 1 : -1
    length(s) < 25 && return dt  # offset has hours only, no :MM
    h, m = parse(Int, s[21:22]), parse(Int, s[24:25])
    dt - Minute(sign * (60h + m))
end

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
    doc = parsexml(content)
    root = root(doc)

    points = ActivityPoint[]

    # Handle both namespaced and non-namespaced elements
    for elem in eachmatch(".//(trkpt|wpt|rtept)", root)
        lat_attr = attribute(elem, "lat")
        lon_attr = attribute(elem, "lon")

        isnothing(lat_attr) || isnothing(lon_attr) && continue

        lat = parse(Float64, lat_attr)
        lon = parse(Float64, lon_attr)

        # Extract child elements
        ele_elem = findfirst("./ele", elem)
        ele = isnothing(ele_elem) ? missing : parse(Float64, content(ele_elem))

        time_elem = findfirst("./time", elem)
        timestamp = isnothing(time_elem) ? missing : parse_timestamp(content(time_elem))

        # Handle gpxtpx namespace for extensions
        hr_elem = findfirst("./(hr|gpxtpx:hr)", elem)
        hr = isnothing(hr_elem) ? missing : round(Int, parse(Float64, content(hr_elem)))

        cad_elem = findfirst("./(cad|gpxtpx:cad)", elem)
        cad = isnothing(cad_elem) ? missing : round(Int, parse(Float64, content(cad_elem)))

        push!(points, ActivityPoint(timestamp, lat, lon, ele, hr, cad))
    end

    return points
end
