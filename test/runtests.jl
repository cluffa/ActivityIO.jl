using ActivityIO
using Test
using DataFrames
using FileIO
using CSV

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
        export_dir = "/Users/alex/Documents/data/export_31282795"
        if isdir(export_dir)
            acts = load_export(export_dir; activity_type="Run")
            @test acts isa DataFrame
            @test !isempty(acts)
            @test hasproperty(acts, :data)
            @test acts.data[1] isa DataFrame
            @test any(!isempty, acts.data)
        else
            @test_skip "Garmin export not available"
        end
    end

end
