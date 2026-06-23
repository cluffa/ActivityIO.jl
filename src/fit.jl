function detect_fit_magic(io)
    try
        if markable(io)
            mark(io)
            bytes = read(io, 14)
            reset(io)
            if length(bytes) >= 12
                return String(@view bytes[9:12]) == ".FIT"
            end
        end
    catch
    end
    return false
end

# --- Binary helpers ---

@inline read_u16(io::IO, arch::UInt8) = arch == 0x00 ? ltoh(read(io, UInt16)) : ntoh(read(io, UInt16))
@inline read_u32(io::IO, arch::UInt8) = arch == 0x00 ? ltoh(read(io, UInt32)) : ntoh(read(io, UInt32))
@inline read_u64(io::IO, arch::UInt8) = arch == 0x00 ? ltoh(read(io, UInt64)) : ntoh(read(io, UInt64))
@inline read_i16(io::IO, arch::UInt8) = reinterpret(Int16, read_u16(io, arch))
@inline read_i32(io::IO, arch::UInt8) = reinterpret(Int32, read_u32(io, arch))
@inline read_i64(io::IO, arch::UInt8) = reinterpret(Int64, read_u64(io, arch))
@inline read_f32(io::IO, arch::UInt8) = reinterpret(Float32, read_u32(io, arch))
@inline read_f64(io::IO, arch::UInt8) = reinterpret(Float64, read_u64(io, arch))

@inline read_t(io::IO, ::Type{UInt8},    ::UInt8)      = read(io, UInt8)
@inline read_t(io::IO, ::Type{Int8},     ::UInt8)      = reinterpret(Int8, read(io, UInt8))
@inline read_t(io::IO, ::Type{UInt16},   arch::UInt8)  = read_u16(io, arch)
@inline read_t(io::IO, ::Type{Int16},    arch::UInt8)  = read_i16(io, arch)
@inline read_t(io::IO, ::Type{UInt32},   arch::UInt8)  = read_u32(io, arch)
@inline read_t(io::IO, ::Type{Int32},    arch::UInt8)  = read_i32(io, arch)
@inline read_t(io::IO, ::Type{UInt64},   arch::UInt8)  = read_u64(io, arch)
@inline read_t(io::IO, ::Type{Int64},    arch::UInt8)  = read_i64(io, arch)
@inline read_t(io::IO, ::Type{Float32},  arch::UInt8)  = read_f32(io, arch)
@inline read_t(io::IO, ::Type{Float64},  arch::UInt8)  = read_f64(io, arch)

# ponytail: generic helper to read single or array values
function read_val(io::IO, ::Type{T}, size::UInt8, architecture::UInt8, invalid=nothing) where {T}
    num_elements = Int(size ÷ sizeof(T))
    if num_elements <= 1
        val = read_t(io, T, architecture)
        return (!isnothing(invalid) && val == invalid) ? missing : val
    else
        if isnothing(invalid)
            vals = Vector{T}(undef, num_elements)
            for i in 1:num_elements; vals[i] = read_t(io, T, architecture); end
            return vals
        else
            vals = Vector{Union{T, Missing}}(undef, num_elements)
            all_missing = true
            for i in 1:num_elements
                v = read_t(io, T, architecture)
                if v == invalid
                    vals[i] = missing
                else
                    vals[i] = v
                    all_missing = false
                end
            end
            return all_missing ? missing : vals
        end
    end
end

function read_field_value(io::IO, size::UInt8, base_type::UInt8, architecture::UInt8)
    if base_type == 0x07
        raw = read(io, size)
        nul = findfirst(==(0x00), raw)
        isnothing(nul) && return String(raw)
        nul == 1 && return ""
        resize!(raw, nul - 1)
        return String(raw)
    end
    if     base_type == 0x00 || base_type == 0x02 || base_type == 0x0A || base_type == 0x0D
        read_val(io, UInt8,    size, architecture, 0xFF)
    elseif base_type == 0x01;   read_val(io, Int8,    size, architecture, 0x7F)
    elseif base_type == 0x83;   read_val(io, Int16,   size, architecture, 0x7FFF)
    elseif base_type == 0x84 || base_type == 0x8B
        read_val(io, UInt16,   size, architecture, 0xFFFF)
    elseif base_type == 0x85;   read_val(io, Int32,   size, architecture, 0x7FFFFFFF)
    elseif base_type == 0x86 || base_type == 0x8C
        read_val(io, UInt32,   size, architecture, 0xFFFFFFFF)
    elseif base_type == 0x88;   read_val(io, Float32, size, architecture)
    elseif base_type == 0x89;   read_val(io, Float64, size, architecture)
    elseif base_type == 0x8E;   read_val(io, Int64,   size, architecture, 0x7FFFFFFFFFFFFFFF)
    elseif base_type == 0x8F || base_type == 0x90
        read_val(io, UInt64,   size, architecture, 0xFFFFFFFFFFFFFFFF)
    else
        read_val(io, UInt8,    size, architecture, 0xFF)
    end
end

# --- FIT data structures ---

struct FitHeader
    header_size::UInt8
    protocol_version::UInt8
    profile_version::UInt16
    data_size::UInt32
    data_type::String
    crc::UInt16
end

struct FieldDef
    num::UInt8
    size::UInt8
    base_type::UInt8
end

struct DevFieldDef
    num::UInt8
    size::UInt8
    developer_data_index::UInt8
end

struct MsgDef
    local_num::UInt8
    global_num::UInt16
    architecture::UInt8
    fields::Vector{FieldDef}
    dev_fields::Vector{DevFieldDef}
    name::Symbol
    field_mapping::Dict{UInt8, Symbol}
end

struct FitMessage
    name::Symbol
    global_num::UInt16
    fields::Dict{Symbol, Any}
end

# --- Mappings ---

const MESSAGE_NAMES = Dict{UInt16, Symbol}(
    0  => :file_id,
    18 => :session,
    19 => :lap,
    20 => :record,
    21 => :event,
    23 => :device_info,
    49 => :activity
)

const FIELD_NAMES = Dict{Symbol, Dict{UInt8, Symbol}}(
    :record => Dict(
        253 => :timestamp,
        0   => :position_lat,
        1   => :position_long,
        2   => :altitude,
        3   => :heart_rate,
        4   => :cadence,
        5   => :distance,
        6   => :speed,
        7   => :power,
        29  => :accumulated_power,
        39  => :vertical_oscillation,
        40  => :stance_time_percent,
        41  => :stance_time,
        42  => :activity_type,
        53  => :fractional_cadence,
        73  => :enhanced_speed,
        78  => :enhanced_altitude,
        83  => :vertical_ratio,
        84  => :stance_time_balance,
        85  => :step_length,
        87  => :cycle_length16,
        99  => :respiration_rate,
        108 => :enhanced_respiration_rate
    ),
    :file_id => Dict(
        0 => :type, 1 => :manufacturer, 2 => :product,
        3 => :serial_number, 4 => :time_created
    ),
    :session => Dict(
        253 => :timestamp,
        0   => :event,
        1   => :event_type,
        2   => :start_time,
        3   => :start_position_lat,
        4   => :start_position_long,
        5   => :sport,
        6   => :sub_sport,
        7   => :total_elapsed_time,
        8   => :total_timer_time,
        9   => :total_distance,
        10  => :total_cycles,
        11  => :total_calories,
        14  => :avg_speed,
        15  => :max_speed,
        16  => :avg_heart_rate,
        17  => :max_heart_rate,
        18  => :avg_cadence,
        19  => :max_cadence,
        20  => :avg_power,
        21  => :max_power,
        22  => :total_ascent,
        23  => :total_descent,
        124 => :enhanced_avg_speed,
        125 => :enhanced_max_speed
    )
)

const EMPTY_FIELD_MAP    = Dict{UInt8, Symbol}()
const UNKNOWN_FIELD_SYMBOLS = [Symbol("field_", i) for i in 0:255]
const GARMIN_EPOCH       = DateTime(1989, 12, 31, 0, 0, 0)

const SPORT_NAMES = Dict{UInt8, Symbol}(
    0 => :generic, 1 => :running, 2 => :cycling, 3 => :transition,
    4 => :fitness_equipment, 5 => :swimming, 6 => :basketball, 7 => :soccer,
    8 => :tennis, 9 => :american_football, 10 => :training, 11 => :walking,
    12 => :cross_country_skiing, 13 => :alpine_skiing, 14 => :snowboarding,
    15 => :rowing, 16 => :mountaineering, 17 => :hiking, 18 => :multisport,
    19 => :paddling, 20 => :flying, 21 => :e_biking, 22 => :motorcycling,
    23 => :boating, 24 => :driving, 25 => :golf, 26 => :hang_gliding,
    27 => :horseback_riding, 28 => :hunting, 29 => :fishing,
    30 => :inline_skating, 31 => :rock_climbing, 32 => :sailing,
    33 => :ice_skating, 34 => :sky_diving, 35 => :snowshoeing,
    36 => :snowmobiling, 37 => :stand_up_paddleboarding, 38 => :surfing,
    39 => :wakeboarding, 40 => :water_skiing, 41 => :kayaking, 42 => :rafting,
    43 => :windsurfing, 44 => :kitesurfing, 45 => :tactical, 46 => :jumpmaster,
    47 => :boxing, 48 => :floor_climbing, 49 => :baseball,
    50 => :softball_fast_pitch, 51 => :softball_slow_pitch,
    56 => :shooting, 57 => :auto_racing, 0xFE => :all
)

const SUB_SPORT_NAMES = Dict{UInt8, Symbol}(
    0 => :generic, 1 => :treadmill, 2 => :street, 3 => :trail, 4 => :track,
    5 => :spin, 6 => :indoor_cycling, 7 => :road, 8 => :mountain,
    9 => :downhill, 10 => :recumbent, 11 => :cyclocross, 12 => :hand_cycling,
    13 => :track_cycling, 14 => :indoor_rowing, 15 => :elliptical,
    16 => :stair_climbing, 17 => :lap_swimming, 18 => :open_water,
    19 => :flexibility_training, 20 => :strength_training, 21 => :warm_up,
    22 => :match, 23 => :exercise, 24 => :challenge, 25 => :indoor_skiing,
    26 => :cardio_training, 27 => :indoor_walking, 28 => :e_bike_fitness,
    29 => :bmx, 30 => :casual_walking, 31 => :speed_walking,
    32 => :bike_to_run_transition, 33 => :run_to_bike_transition,
    34 => :swim_to_bike_transition, 35 => :atv, 36 => :motocross,
    37 => :backcountry, 38 => :resort, 39 => :rc_drone, 40 => :wingsuit,
    41 => :whitewater, 42 => :skate_skiing, 43 => :yoga, 44 => :pilates,
    45 => :indoor_running, 46 => :gravel_cycling, 47 => :e_bike_mountain,
    48 => :commuting, 49 => :mixed_surface, 50 => :navigate, 51 => :track_me,
    52 => :map, 53 => :single_gas_diving, 54 => :multi_gas_diving,
    55 => :gauge_diving, 56 => :apnea_diving, 57 => :apnea_hunting,
    58 => :virtual_activity, 59 => :obstacle,
    62 => :breathing, 65 => :sail_race, 67 => :ultra, 0xFE => :all
)

function apply_semantic_scale!(fields::Dict{Symbol, Any}, msg_name::Symbol)
    ts = get(fields, :timestamp, missing)
    if !ismissing(ts)
        fields[:timestamp] = GARMIN_EPOCH + Second(ts::Integer)
    end
    if msg_name == :session
        st = get(fields, :start_time, missing)
        !ismissing(st) && (fields[:start_time] = GARMIN_EPOCH + Second(st::Integer))
        for k in (:start_position_lat, :start_position_long)
            v = get(fields, k, missing)
            !ismissing(v) && (fields[k] = (v::Number) * 180.0 / (2^31))
        end
        for k in (:avg_speed, :max_speed, :enhanced_avg_speed, :enhanced_max_speed)
            v = get(fields, k, missing)
            !ismissing(v) && (fields[k] = (v::Number) / 1000.0)
        end
        dist = get(fields, :total_distance, missing)
        !ismissing(dist) && (fields[:total_distance] = (dist::Number) / 100.0)
        for k in (:total_elapsed_time, :total_timer_time)
            v = get(fields, k, missing)
            !ismissing(v) && (fields[k] = (v::Number) / 1000.0)
        end
    elseif msg_name == :record
        lat = get(fields, :position_lat, missing)
        !ismissing(lat) && (fields[:position_lat] = (lat::Number) * 180.0 / (2^31))
        lon = get(fields, :position_long, missing)
        !ismissing(lon) && (fields[:position_long] = (lon::Number) * 180.0 / (2^31))
        dist = get(fields, :distance, missing)
        !ismissing(dist) && (fields[:distance] = (dist::Number) / 100.0)
        speed = get(fields, :speed, missing)
        !ismissing(speed) && (fields[:speed] = (speed::Number) / 1000.0)
        espeed = get(fields, :enhanced_speed, missing)
        !ismissing(espeed) && (fields[:enhanced_speed] = (espeed::Number) / 1000.0)
        alt = get(fields, :altitude, missing)
        !ismissing(alt) && (fields[:altitude] = (alt::Number) / 5.0 - 500.0)
        ealt = get(fields, :enhanced_altitude, missing)
        !ismissing(ealt) && (fields[:enhanced_altitude] = (ealt::Number) / 5.0 - 500.0)
    end
end

# --- Core parser ---

function parse_fit(file_path::String)::Vector{FitMessage}
    if !isfile(file_path)
        error("File not found: $file_path")
    end
    io = endswith(file_path, ".gz") ? GZip.open(file_path, "r") : open(file_path, "r")
    try
        return parse_fit(io)
    finally
        close(io)
    end
end

function parse_fit(io::IO)::Vector{FitMessage}
    header_size = read(io, UInt8)
    header_size != 12 && header_size != 14 && error("Invalid FIT header size: $header_size")

    protocol_version = read(io, UInt8)
    profile_version  = read(io, UInt16)
    data_size        = read(io, UInt32)
    sig              = String(read(io, 4))
    sig != ".FIT"    && error("Invalid FIT file signature: $sig")
    header_size == 14 && read(io, UInt16)  # crc

    defs     = Vector{Union{Nothing, MsgDef}}(nothing, 16)
    messages = FitMessage[]
    sizehint!(messages, data_size ÷ 30)

    bytes_read     = 0
    last_timestamp = UInt32(0)

    while bytes_read < data_size
        header_byte = read(io, UInt8)
        bytes_read += 1

        if (header_byte & 0x80) != 0
            # Compressed timestamp
            local_num   = (header_byte >> 5) & 0x03
            time_offset = UInt32(header_byte & 0x1F)
            msg_def     = defs[local_num + 1]
            isnothing(msg_def) && error("Compressed timestamp for undefined local message $local_num")
            new_ts = (last_timestamp & 0xFFFFFFE0) | time_offset
            time_offset < (last_timestamp & 0x1F) && (new_ts += 0x20)
            last_timestamp = new_ts
            parsed_fields = Dict{Symbol, Any}()
            sizehint!(parsed_fields, length(msg_def.fields) + 1)
            for fdef in msg_def.fields
                val = read_field_value(io, fdef.size, fdef.base_type, msg_def.architecture)
                bytes_read += fdef.size
                parsed_fields[get(msg_def.field_mapping, fdef.num, UNKNOWN_FIELD_SYMBOLS[fdef.num + 1])] = val
            end
            for dev_fdef in msg_def.dev_fields
                read(io, dev_fdef.size); bytes_read += dev_fdef.size
            end
            parsed_fields[:timestamp] = last_timestamp
            apply_semantic_scale!(parsed_fields, msg_def.name)
            push!(messages, FitMessage(msg_def.name, msg_def.global_num, parsed_fields))

        elseif (header_byte & 0x40) != 0
            # Definition message
            local_num    = header_byte & 0x0F
            has_dev_data = (header_byte & 0x20) != 0
            read(io, UInt8)  # reserved
            architecture = read(io, UInt8)
            global_num   = read_u16(io, architecture)
            num_fields   = read(io, UInt8)
            bytes_read  += 5
            fields = Vector{FieldDef}(undef, num_fields)
            for i in 1:num_fields
                fields[i] = FieldDef(read(io, UInt8), read(io, UInt8), read(io, UInt8))
                bytes_read += 3
            end
            dev_fields = DevFieldDef[]
            if has_dev_data
                num_dev = read(io, UInt8); bytes_read += 1
                dev_fields = Vector{DevFieldDef}(undef, num_dev)
                for i in 1:num_dev
                    dev_fields[i] = DevFieldDef(read(io, UInt8), read(io, UInt8), read(io, UInt8))
                    bytes_read += 3
                end
            end
            msg_name      = get(MESSAGE_NAMES, global_num, Symbol("msg_", global_num))
            field_mapping = get(FIELD_NAMES, msg_name, EMPTY_FIELD_MAP)
            defs[local_num + 1] = MsgDef(local_num, global_num, architecture, fields, dev_fields, msg_name, field_mapping)

        else
            # Data message
            local_num = header_byte & 0x0F
            msg_def   = defs[local_num + 1]
            isnothing(msg_def) && error("Data message for undefined local message $local_num")
            parsed_fields = Dict{Symbol, Any}()
            sizehint!(parsed_fields, length(msg_def.fields))
            for fdef in msg_def.fields
                val = read_field_value(io, fdef.size, fdef.base_type, msg_def.architecture)
                bytes_read += fdef.size
                parsed_fields[get(msg_def.field_mapping, fdef.num, UNKNOWN_FIELD_SYMBOLS[fdef.num + 1])] = val
            end
            for dev_fdef in msg_def.dev_fields
                read(io, dev_fdef.size); bytes_read += dev_fdef.size
            end
            ts_raw = get(parsed_fields, :timestamp, missing)
            !ismissing(ts_raw) && ts_raw isa Integer && (last_timestamp = UInt32(ts_raw))
            apply_semantic_scale!(parsed_fields, msg_def.name)
            push!(messages, FitMessage(msg_def.name, msg_def.global_num, parsed_fields))
        end
    end

    return messages
end
