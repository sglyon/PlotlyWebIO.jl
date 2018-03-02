__precompile__()

module PlotlyWebIO

export WebIOPlot, render

using Reexport
@reexport using PlotlyBase
using WebIO
using JSON
using JSExpr
using JSExpr: @var, @new

include("events.jl")
include("plot_type.jl")
include("plotly_api.jl")

end # module
