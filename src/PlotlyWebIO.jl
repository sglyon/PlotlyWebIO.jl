__precompile__()

module PlotlyWebIO

export WebIOPlot, render

using Reexport
@reexport using PlotlyBase
using WebIO
using JSON
using JSExpr
using JSExpr: @var, @new

# need to import some functions because methods are meta-generated
import PlotlyBase:
    restyle!, relayout!, update!, addtraces!, deletetraces!, movetraces!,
    redraw!, extendtraces!, prependtraces!, purge!, to_image, download_image,
    restyle, relayout, update, addtraces, deletetraces, movetraces, redraw,
    extendtraces, prependtraces, prep_kwargs, sizes, savefig, _tovec


include("plot_type.jl")
include("plotly_api.jl")

end # module
