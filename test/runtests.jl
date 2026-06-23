using ActivityIO
using Test
using DataFrames
using FileIO
using CSV
using Dates

const DATA = joinpath(@__DIR__, "data")

@testset "ActivityIO.jl Tests" begin

    @testset "FIT Parsing" begin
        sample = joinpath(DATA, "sample.fit.gz")
        @test isfile(sample)
        msgs = parse_fit(sample)
        @test msgs isa Vector{FitMessage}
        @test !isempty(msgs)
        for msg in msgs
            @test msg.name isa Symbol
            @test msg.fields isa Dict{Symbol, Any}
        end
        records = get_records(msgs)
        @test records isa Vector{Dict{Symbol, Any}}
        @test !isempty(records)
        @test haskey(first(records), :timestamp)
        @test haskey(first(records), :heart_rate)
    end

    @testset "GPX Parsing" begin
        sample    = joinpath(DATA, "sample.gpx")
        sample_gz = joinpath(DATA, "sample.gpx.gz")
        @test isfile(sample) && isfile(sample_gz)
        pts1 = parse_gpx(sample)
        pts2 = parse_gpx(sample_gz)
        @test pts1 isa Vector{ActivityPoint}
        @test !isempty(pts1)
        @test length(pts1) == length(pts2)
        p = first(pts1)
        @test !ismissing(p.timestamp)
        @test p.lat isa Float64
        records = get_records(pts1)
        @test haskey(first(records), :timestamp)
        @test haskey(first(records), :position_lat)
    end

    @testset "TCX Parsing" begin
        sample    = joinpath(DATA, "sample.tcx")
        sample_gz = joinpath(DATA, "sample.tcx.gz")
        @test isfile(sample) && isfile(sample_gz)
        pts1 = parse_tcx(sample)
        pts2 = parse_tcx(sample_gz)
        @test pts1 isa Vector{ActivityPoint}
        @test !isempty(pts1)
        @test length(pts1) == length(pts2)
        p = first(pts1)
        @test !ismissing(p.timestamp)
        records = get_records(pts1)
        @test haskey(first(records), :timestamp)
        @test haskey(first(records), :position_lat)
    end

    @testset "DataFrame Conversion" begin
        @test get_records_df(parse_gpx(joinpath(DATA, "sample.gpx"))) isa DataFrame
        @test get_records_df(parse_tcx(joinpath(DATA, "sample.tcx"))) isa DataFrame
        @test get_records_df(parse_fit(joinpath(DATA, "sample.fit.gz"))) isa DataFrame
        df = get_records_df(parse_gpx(joinpath(DATA, "sample.gpx")))
        @test "timestamp" in names(df)
        @test "position_lat" in names(df)
        @test "distance" in names(df)
        @test "speed" in names(df)
        @test df.distance[1] === 0.0
        @test all(d -> ismissing(d) || d >= 0.0, df.distance)
        df_tcx = get_records_df(parse_tcx(joinpath(DATA, "sample.tcx")))
        @test "distance" in names(df_tcx)
        @test "speed" in names(df_tcx)
    end

    @testset "FileIO Loading" begin
        for (sample, T) in [
            (joinpath(DATA, "sample.fit.gz"), Vector{FitMessage}),
            (joinpath(DATA, "sample.gpx"),    Vector{ActivityPoint}),
            (joinpath(DATA, "sample.gpx.gz"), Vector{ActivityPoint}),
            (joinpath(DATA, "sample.tcx"),    Vector{ActivityPoint}),
            (joinpath(DATA, "sample.tcx.gz"), Vector{ActivityPoint}),
        ]
            pts = FileIO.load(sample)
            @test pts isa T
            @test !isempty(pts)
        end

        for sample in [
            joinpath(DATA, "sample.gpx"),
            joinpath(DATA, "sample.gpx.gz"),
            joinpath(DATA, "sample.tcx"),
            joinpath(DATA, "sample.tcx.gz"),
            joinpath(DATA, "sample.fit.gz"),
        ]
            recs = FileIO.load(sample, Vector{Dict{Symbol,Any}})
            @test recs isa Vector{Dict{Symbol,Any}}
            @test !isempty(recs)
            @test haskey(first(recs), :timestamp)

            df = FileIO.load(sample, DataFrame)
            @test df isa DataFrame
            @test !isempty(df)
            @test "timestamp" in names(df)
        end
    end

    @testset "load_export" begin
        export_dir = joinpath(DATA, "export")
        # "Run" matches "Run" (3 rows) and "Trail Run" (1 row) via case-insensitive substring
        acts = load_export(export_dir; activity_type="Run")
        @test acts isa DataFrame
        @test nrow(acts) == 4
        @test hasproperty(acts, :data)
        @test all(r -> r isa DataFrame, acts.data)
        @test any(!isempty, acts.data)
        # case-insensitive: lowercase input matches mixed-case values
        acts_lower = load_export(export_dir; activity_type="run")
        @test nrow(acts_lower) == 4
        # Regex: exact case-insensitive match for "Run" only, not "Trail Run"
        acts_exact = load_export(export_dir; activity_type=r"^Run$"i)
        @test nrow(acts_exact) == 3
        # missing filename → empty DataFrame, not an error
        all_acts = load_export(export_dir)
        @test nrow(all_acts) == 5
        @test isempty(all_acts.data[4])
        @test isempty(all_acts.data[5])
    end

    @testset "get_header" begin
        msgs = parse_fit(joinpath(DATA, "sample.fit.gz"))
        h = get_header(msgs)
        @test h isa Dict{Symbol,Any}
        @test haskey(h, :start_time)
        @test h[:start_time] isa DateTime
        # total_elapsed_time must be in seconds (scaled from ms), not a raw integer
        @test h[:total_elapsed_time] isa AbstractFloat
        @test h[:total_elapsed_time] < 86400  # sanity: less than a day
    end

    @testset "load_export header column" begin
        export_dir = joinpath(DATA, "export")
        acts = load_export(export_dir)
        @test hasproperty(acts, :header)
        # row 1 = FIT → has session header
        @test acts.header[1] isa Dict{Symbol,Any}
        @test acts.header[1][:start_time] isa DateTime
        # rows 2, 3, 4, 5 → all missing (GPX, TCX, missing filename ×2)
        @test ismissing(acts.header[2])
        @test ismissing(acts.header[3])
        @test ismissing(acts.header[4])
        @test ismissing(acts.header[5])
    end

end
