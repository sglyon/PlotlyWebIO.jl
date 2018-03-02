mutable struct WebIOPlot
    p::PlotlyBase.Plot
    scope::Scope
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

    # setup scope
    deps = [
        "Plotly" => "/pkg/PlotlyJS/plotly-latest.min.js",
        "/pkg/PlotlyWebIO/plotly_webio_bundle.js"
    ]
    scope = Scope(imports=deps)
    scope.dom = dom"div"(id=string("plot-", p.divid))

    # set up observables for plotly.js api function calls and events
    api_obs = setup_api_obs(p, scope)
    event_obs, event_data = setup_events(scope)

    # unpack Observables so we can hook them up in our js below
    svg_obs = api_obs["svg"]
    hover_obs = event_obs["hover"]
    selected_obs = event_obs["selected"]
    click_obs = event_obs["click"]
    relayout_obs = event_obs["relayout"]

    onimport(scope, JSExpr.@js function (Plotly)

        @var gd = this.dom.querySelector($id);
        if (window.Blink !== undefined)
            # // set css style for auto-resize
            gd.style.width = "100%";
            gd.style.height = "100vh";
            gd.style.marginLeft = "0%";
            gd.style.marginTop = "0vh";
        end
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

    out = WebIOPlot(p, scope, "", api_obs, events, event_data, event_obs)
    on(data -> setfield!(out, :svg, data), svg_obs)
    out
end
