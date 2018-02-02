__precompile__()

module PlotlyWebIO

export WebIOPlot, render

using Reexport
@reexport using PlotlyBase
using WebIO
import WebIO.render
using JSON

do_nothing(args...) = nothing
log_args(args...) = (@show args; nothing)

mutable struct PlotlyEvents
    plotly_click
    plotly_hover
    plotly_unhover
    plotly_selecting
    plotly_selected
end

function PlotlyEvents()
    PlotlyEvents(do_nothing, do_nothing, do_nothing, do_nothing, do_nothing)
end

function log_events()
    PlotlyEvents(log_args, log_args, log_args, log_args, log_args)
end

function setup_api_obs(p::PlotlyBase.Plot, widget::Widget)
    svg_obs = Observable(widget, "svg-string", "")
    api_obs = Dict{String,Observable}("svg" => svg_obs)
    id = string("#plot-", p.divid)

    # set up restyle
    restyle_obs = Observable(widget, "restyle_args", RestyleArgs())
    api_obs["restyle"] = restyle_obs

    onjs(restyle_obs, @js function(val)
        @var gd = this.dom.querySelector($id);
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
    api_obs["relayout"] = relayout_obs

    onjs(relayout_obs, @js function(val)
        @var gd = this.dom.querySelector($id);
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
    api_obs["update"] = update_obs

    onjs(update_obs, @js function(val)
        @var gd = this.dom.querySelector($id);
        Plotly.update(gd, val.data, val.layout, val.traces).then(function(gd)
            Plotly.toImage(gd, $(Dict("format" => "svg")))
        end
        ).then(function(data)
            @var svg_data = data.replace("data:image/svg+xml,", "")
            $svg_obs[] = decodeURIComponent(svg_data)
        end
        );
    end)

    # TODO: addtraces, deletetraces, movetraces, redraw, purge, to_image,
    # download_image, extendtraces, prependtraces

    api_obs
end

function bind_events!(
        widget::Widget,
        event_obs::Dict{String,Observable}, event_data::Dict{String,Dict},
        event_functions::PlotlyEvents
    )
    # set up observables for event data
    for name in ["hover", "selected", "click", "relayout"]
        event_obs[name] = Observable(widget, string("on-", name), Dict())
        event_data[name] = Dict()
        on(data -> setindex!(event_data, data, name), event_obs[name])
    end
    # TODO: hook up event_functions
end

mutable struct WebIOPlot
    p::PlotlyBase.Plot
    widget::Widget
    svg::String
    api_obs::Dict{String,Observable}
    event_functions::PlotlyEvents
    event_data::Dict{String,Dict}
    event_obs::Dict{String,Observable}
end
Base.show(io::IO, mm::MIME"text/plain", p::WebIOPlot) = show(io, mm, p.p)

function WebIOPlot(args...; events::PlotlyEvents=PlotlyEvents(), kwargs...)
    p = Plot(args...; kwargs...)
    # TODO: figure out how to load locally in IJulia)
    # deps = [
    #     "/pkg/PlotlyJS/plotly-latest.min.js",
    #     "/pkg/PlotlyWebIO/plotly_webio_bundle.js"
    # ]
    deps = [
        "https://cdn.plot.ly/plotly-latest.min.js",
        "https://github.com/sglyon/PlotlyWebIO.jl/releases/download/assets/plotly_webio_bundle.js"
    ]
    widget = Widget(dependencies=deps)
    api_obs = setup_api_obs(p, widget)

    event_data = Dict{String,Dict}()
    event_obs = Dict{String,Observable}()
    bind_events!(widget, event_obs, event_data, events)

    WebIOPlot(p, widget, "", api_obs, events, event_data, event_obs)
end


function render(p::WebIOPlot)
    lowered = JSON.lower(p.p)
    options = Dict("showLink"=> false)

    id = string("#plot-", p.p.divid)

    # unpack Observables so we can hook them up in our js below
    svg_obs = p.api_obs["svg"]
    hover_obs = p.event_obs["hover"]
    selected_obs = p.event_obs["selected"]
    click_obs = p.event_obs["click"]
    relayout_obs = p.event_obs["relayout"]

    # get ready to recieve svg data
    on(data -> setfield!(p, :svg, data), svg_obs)

    ondependencies(p.widget, WebIO.@js function (Plotly)

        @var gd = this.dom.querySelector($id);
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

        # I think this triggers too often (even on scroll/zoom)
        # gd.on("plotly_afterplot", function()
        #     Plotly.toImage(gd, $(Dict("format" => "svg"))).then(function(data)
        #         @var svg_data = data.replace("data:image/svg+xml,", "")
        #         $svg_obs[] = decodeURIComponent(svg_data)
        #     end)
        # end
        # )

        gd.on("plotly_hover", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "hover");
            if !(filtered_data.isnil)
                $hover_obs[] = filtered_data.out
            end
        end)

        gd.on("plotly_unhover", function (data)
            $hover_obs[] = $(Dict())
        end)

        gd.on("plotly_selected", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "selected");
            if !(filtered_data.isnil)
                $selected_obs[] = filtered_data.out
            end
        end)

        gd.on("plotly_deselect", function (data)
            $selected_obs[] = $(Dict())
        end)

        gd.on("plotly_relayout", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "relayout");
            if !(filtered_data.isnil)
                $relayout_obs[] = filtered_data.out
            end
        end)

        gd.on("plotly_click", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "click");
            if !(filtered_data.isnil)
                $click_obs[] = filtered_data.out
            end
        end)
    end)

    # TODO
    style = Dict(
        # "width" => "100%",
        # "height" => "100vh",
        # "margin-left" => "0%",
        # "margin-top" => "0vh",
    )

    p.widget(dom"div"(id=string("plot-", p.p.divid), style=style))
end


abstract type PlotlyAPIArgs end
struct RestyleArgs <: PlotlyAPIArgs
    traces
    data
end

RestyleArgs() = RestyleArgs(nothing, Dict())

function PlotlyBase.restyle!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::Associative=Dict();
        kwargs...)
    args = RestyleArgs(ind-1, merge(update, PlotlyBase.prep_kwargs(kwargs)))
    plt.api_obs["restyle"][] = args
end

function PlotlyBase.restyle!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    restyle!(plt, 1:length(plt.p.data), update; kwargs...)
end

struct RelayoutArgs <: PlotlyAPIArgs
    data
end

RelayoutArgs() = RelayoutArgs(Dict())
function PlotlyBase.relayout!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    args = RelayoutArgs(merge(update, PlotlyBase.prep_kwargs(kwargs)))
    plt.api_obs["relayout"][] = args
end

struct UpdateArgs <: PlotlyAPIArgs
    traces
    data
    layout
end

UpdateArgs() = UpdateArgs(nothing, Dict(), Dict())

function PlotlyBase.update!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::Associative=Dict();
        layout::Layout=Layout(),
        kwargs...)
    args = UpdateArgs(ind-1, merge(update, PlotlyBase.prep_kwargs(kwargs)), layout)
    plt.api_obs["update"][] = args
end

function PlotlyBase.update!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    PlotlyBase.update!(plt, 1:length(plt.p.data), update; kwargs...)
end

end # module
