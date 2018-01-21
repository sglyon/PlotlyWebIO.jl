__precompile__()

module PlotlyWebIO

export WebIOPlot, render

using Reexport
@reexport using PlotlyJS
using WebIO
import WebIO.render
using JSON

mutable struct WebIOPlot
    p::PlotlyJS.Plot
    svg::String
    api_obs::Dict{Any,Any}
end

WebIOPlot(args...; kwargs...) = WebIOPlot(Plot(args...; kwargs...), "", Dict())

function render(p::WebIOPlot)
    # widget = Widget(dependencies=["/pkg/PlotlyJS/plotly-latest.min.js"])
    # TODO: figure out how to load locally in IJulia
    widget = Widget(dependencies=["https://cdn.plot.ly/plotly-latest.min.js"])
    svg_obs = Observable(widget, "svg-string", "")
    on(svg_obs) do svg
        p.svg = svg
    end

    lowered = JSON.lower(p.p)
    options = Dict("showLink"=> false)

    ondependencies(widget, WebIO.@js function (Plotly)
        @var gd = this.dom.querySelector("#theplot");
        Plotly.newPlot(
            gd, $(lowered[:data]), $(lowered[:layout]), $(options)
        ).then(function(gd)
            Plotly.toImage(gd, $(Dict("format" => "svg")))
        end
        ).then(function(data)
            @var svg_data = data.replace("data:image/svg+xml,", "")
            $svg_obs[] = decodeURIComponent(svg_data)
        end
        );
        window.onresize = function()
            Plotly.Plots.resize(gd)
        end
    end)

    # set up restyle
    restyle_obs = Observable(widget, "restyle_args", RestyleArgs())
    p.api_obs["restyle"] = restyle_obs

    onjs(restyle_obs, @js function(val)
        @var gd = this.dom.querySelector("#theplot");
        Plotly.restyle(gd, val.data, val.traces).then(function(gd)
            Plotly.toImage(gd, $(Dict("format" => "svg")))
        end
        ).then(function(data)
            @var svg_data = data.replace("data:image/svg+xml,", "")
            $svg_obs[] = decodeURIComponent(svg_data)
        end
        );
    end)

    # set up relayout
    relayout_obs = Observable(widget, "relayout_args", RelayoutArgs())
    p.api_obs["relayout"] = relayout_obs

    onjs(relayout_obs, @js function(val)
        @var gd = this.dom.querySelector("#theplot");
        Plotly.relayout(gd, val.data).then(function(gd)
            Plotly.toImage(gd, $(Dict("format" => "svg")))
        end
        ).then(function(data)
            @var svg_data = data.replace("data:image/svg+xml,", "")
            $svg_obs[] = decodeURIComponent(svg_data)
        end
        );
    end)

    # set up update
    update_obs = Observable(widget, "update_args", UpdateArgs())
    p.api_obs["update"] = update_obs

    onjs(update_obs, @js function(val)
        @var gd = this.dom.querySelector("#theplot");
        Plotly.update(gd, val.data, val.layout, val.traces).then(function(gd)
            Plotly.toImage(gd, $(Dict("format" => "svg")))
        end
        ).then(function(data)
            @var svg_data = data.replace("data:image/svg+xml,", "")
            svg = decodeURIComponent(svg_data)
            $svg_obs[] = svg
        end
        );
    end)

    # TODO: addtraces, deletetraces, movetraces, redraw, purge, to_image,
    # download_image, extendtraces, prependtraces

    style = Dict(
        # "width" => "100%",
        # "height" => "100vh",
        # "margin-left" => "0%",
        # "margin-top" => "0vh",
    )

    widget(dom"div#theplot"(style=style))
end


abstract type PlotlyAPIArgs end
struct RestyleArgs <: PlotlyAPIArgs
    traces
    data
end

RestyleArgs() = RestyleArgs(nothing, Dict())

function PlotlyJS.restyle!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::Associative=Dict();
        kwargs...)
    args = RestyleArgs(ind-1, merge(update, PlotlyJS.prep_kwargs(kwargs)))
    plt.api_obs["restyle"][] = args
end

function PlotlyJS.restyle!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    restyle!(plt, 1:length(plt.p.data), update; kwargs...)
end

struct RelayoutArgs <: PlotlyAPIArgs
    data
end

RelayoutArgs() = RelayoutArgs(Dict())
function PlotlyJS.relayout!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    args = RelayoutArgs(merge(update, PlotlyJS.prep_kwargs(kwargs)))
    plt.api_obs["relayout"][] = args
end

struct UpdateArgs <: PlotlyAPIArgs
    traces
    data
    layout
end

UpdateArgs() = UpdateArgs(nothing, Dict(), Dict())

function PlotlyJS.update!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::Associative=Dict();
        layout::Layout=Layout(),
        kwargs...)
    args = UpdateArgs(ind-1, merge(update, PlotlyJS.prep_kwargs(kwargs)), layout)
    plt.api_obs["update"][] = args
end

function PlotlyJS.update!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    PlotlyJS.update!(plt, 1:length(plt.p.data), update; kwargs...)
end


end # module
