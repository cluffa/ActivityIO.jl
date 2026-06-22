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
    doc = parsexml(read(io, String))
    doc_root = root(doc)

    points = ActivityPoint[]

    for trackpoint in findall(".//*[local-name()='Trackpoint']", doc_root)
        time_elem = findfirst(".//*[local-name()='Time']", trackpoint)
        timestamp = isnothing(time_elem) ? missing : parse_timestamp(nodecontent(time_elem))

        lat_elem = findfirst(".//*[local-name()='LatitudeDegrees']", trackpoint)
        lat      = isnothing(lat_elem) ? missing : parse(Float64, nodecontent(lat_elem))

        lon_elem = findfirst(".//*[local-name()='LongitudeDegrees']", trackpoint)
        lon      = isnothing(lon_elem) ? missing : parse(Float64, nodecontent(lon_elem))

        ele_elem = findfirst(".//*[local-name()='AltitudeMeters']", trackpoint)
        ele      = isnothing(ele_elem) ? missing : parse(Float64, nodecontent(ele_elem))

        hr_elem  = findfirst(".//*[local-name()='HeartRateBpm']//*[local-name()='Value']", trackpoint)
        hr       = isnothing(hr_elem)  ? missing : round(Int, parse(Float64, nodecontent(hr_elem)))

        cad_elem = findfirst(".//*[local-name()='Cadence']", trackpoint)
        cad      = isnothing(cad_elem) ? missing : round(Int, parse(Float64, nodecontent(cad_elem)))

        push!(points, ActivityPoint(timestamp, lat, lon, ele, hr, cad))
    end

    return points
end
