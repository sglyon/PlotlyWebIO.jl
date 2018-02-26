# ------------ #
# Web IO stuff #
# ------------ #
function setup_api_obs(p::PlotlyBase.Plot, widget::Widget)
    svg_obs = Observable(widget, "svg-string", "")
    api_obs = Dict{String,Observable}("svg" => svg_obs)
    id = string("#plot-", p.divid)


    # build strings for javascript callback functions
    io = IOBuffer()
    set_svg_expr = WebIO.obs_set_expr(io, svg_obs, "decodeURIComponent(svg_data)")
    set_svg = String(io)
    gd_string = """var gd = this.dom.querySelector("$id");"""
    save_svg_string =
        """.then((function(gd) {
          return Plotly.toImage(gd, {
            "format": "svg"
          })
        })).then((function(data) {
          var svg_data = data.replace("data:image/svg+xml,", "");
          return $set_svg
        }))
      })"""

    # set up observables
    restyle_obs = Observable(widget, "restyle_args", RestyleArgs())
    api_obs["restyle"] = restyle_obs

    relayout_obs = Observable(widget, "relayout_args", RelayoutArgs())
    api_obs["relayout"] = relayout_obs

    update_obs = Observable(widget, "update_args", UpdateArgs())
    api_obs["update"] = update_obs


    onjs(restyle_obs, WebIO.JSString(
        """(function(val) {
          $(gd_string)
          return this.Plotly.update(gd, val.data, val.traces)$(save_svg_string)"""
    ))

    onjs(relayout_obs, WebIO.JSString(
        """(function(val) {
          $(gd_string)
          return this.Plotly.update(gd, val.data)$(save_svg_string)"""
    ))

    onjs(update_obs, WebIO.JSString(
        """(function(val) {
          $(gd_string)
          return this.Plotly.update(gd, val.data, val.layout, val.traces)$(save_svg_string)"""
    ))

    # TODO: addtraces, deletetraces, movetraces, redraw, purge, to_image,
    # download_image, extendtraces, prependtraces

    api_obs
end

# ----------------------- #
# Plotly.js api functions #
# ----------------------- #

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
