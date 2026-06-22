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
    doc = parsexml(read(io, String))
    doc_root = root(doc)

    points = ActivityPoint[]

    for elem in findall(".//*[local-name()='trkpt' or local-name()='wpt' or local-name()='rtept']", doc_root)
        haskey(elem, "lat") && haskey(elem, "lon") || continue

        lat = parse(Float64, elem["lat"])
        lon = parse(Float64, elem["lon"])

        ele_elem  = findfirst(".//*[local-name()='ele']", elem)
        ele       = isnothing(ele_elem)  ? missing : parse(Float64, nodecontent(ele_elem))

        time_elem = findfirst(".//*[local-name()='time']", elem)
        timestamp = isnothing(time_elem) ? missing : parse_timestamp(nodecontent(time_elem))

        hr_elem   = findfirst(".//*[local-name()='hr']", elem)
        hr        = isnothing(hr_elem)   ? missing : round(Int, parse(Float64, nodecontent(hr_elem)))

        cad_elem  = findfirst(".//*[local-name()='cad']", elem)
        cad       = isnothing(cad_elem)  ? missing : round(Int, parse(Float64, nodecontent(cad_elem)))

        push!(points, ActivityPoint(timestamp, lat, lon, ele, hr, cad))
    end

    return points
end
