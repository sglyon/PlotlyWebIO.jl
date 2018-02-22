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
    # build plot, get json, setup options
    p = Plot(args...; kwargs...)
    lowered = JSON.lower(p)
    options = Dict("showLink"=> false)
    id = string("#plot-", p.divid)

    # setup widget
    # deps = [
    #     "/pkg/PlotlyJS/plotly-latest.min.js",
    #     "/pkg/PlotlyWebIO/plotly_webio_bundle.js"
    # ]
    deps = [
        "https://cdn.plot.ly/plotly-latest.min.js",
        "https://cdn.jsdelivr.net/gh/sglyon/PlotlyWebIO.jl@assets/assets/plotly_webio_bundle.js"
    ]
    widget = Widget(imports=deps)
    # TODO: this is an auto-resize style appropriate for blink windows, but
    #       not for IJulia.
    style = Dict(
        # "width" => "100%",
        # "height" => "100vh",
        # "margin-left" => "0%",
        # "margin-top" => "0vh",
    )
    widget.dom = dom"div"(id=string("plot-", p.divid), style=style)

    # set up observables for plotly.js api function calls and events
    api_obs = setup_api_obs(p, widget)
    event_obs, event_data = setup_events(widget)

    # unpack Observables so we can hook them up in our js below
    svg_obs = api_obs["svg"]
    hover_obs = event_obs["hover"]
    selected_obs = event_obs["selected"]
    click_obs = event_obs["click"]
    relayout_obs = event_obs["relayout"]

    onimport(widget, WebIO.@js function (Plotly)

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

        # hook into plotly events
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

    out = WebIOPlot(p, widget, "", api_obs, events, event_data, event_obs)
    on(data -> setfield!(out, :svg, data), svg_obs)
    out
end
