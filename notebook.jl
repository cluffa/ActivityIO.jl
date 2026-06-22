### A Pluto.jl notebook ###
# v1.0.1

using Markdown
using InteractiveUtils

# ╔═╡ 92c9658e-6dd1-11f1-8557-c1f0ff9d493c
begin
    using Pkg
    Pkg.activate(temp = true)
    Pkg.add(["FileIO", "Plots", "DataFrames", "SplitApplyCombine", "CSV"])
    Pkg.develop(PackageSpec(path=@__DIR__))

    using DataFrames, SplitApplyCombine, CSV
    using ActivityIO
end

# ╔═╡ 2eac6298-178a-43fa-a49f-7b8e6655f84e
runs = load_export("/Users/alex/Downloads/export_31282795"; activity_type="Run")

# ╔═╡ 84715f3c-7bee-4880-b7d3-56285d7f0372
runs

# ╔═╡ Cell order:
# ╠═92c9658e-6dd1-11f1-8557-c1f0ff9d493c
# ╠═2eac6298-178a-43fa-a49f-7b8e6655f84e
# ╠═84715f3c-7bee-4880-b7d3-56285d7f0372
