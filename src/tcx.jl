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
    doc = parsexml(content)
    root = root(doc)

    points = ActivityPoint[]

    for trackpoint in eachmatch(".//Trackpoint", root)
        time_elem = findfirst("./Time", trackpoint)
        timestamp = isnothing(time_elem) ? missing : parse_timestamp(content(time_elem))

        position_elem = findfirst("./Position", trackpoint)
        if isnothing(position_elem)
            lat = missing
            lon = missing
        else
            lat_elem = findfirst("./LatitudeDegrees", position_elem)
            lon_elem = findfirst("./LongitudeDegrees", position_elem)
            lat = isnothing(lat_elem) ? missing : parse(Float64, content(lat_elem))
            lon = isnothing(lon_elem) ? missing : parse(Float64, content(lon_elem))
        end

        ele_elem = findfirst("./AltitudeMeters", trackpoint)
        ele = isnothing(ele_elem) ? missing : parse(Float64, content(ele_elem))

        hr_elem = findfirst(".//Value[parent::HeartRateBpm]", trackpoint)
        hr = isnothing(hr_elem) ? missing : round(Int, parse(Float64, content(hr_elem)))

        cad_elem = findfirst("./Cadence", trackpoint)
        cad = isnothing(cad_elem) ? missing : round(Int, parse(Float64, content(cad_elem)))

        push!(points, ActivityPoint(timestamp, lat, lon, ele, hr, cad))
    end

    return points
end
