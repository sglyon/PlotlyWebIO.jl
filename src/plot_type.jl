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

    # build string to send to javascript
    io = IOBuffer()
    # do plot
    print(io, """function(Plotly) {
        var gd = this.dom.querySelector("$id");

        if (window.Blink !== undefined) {
            // set css style for auto-resize
            gd.style.width = "100%";
            gd.style.height = "100vh";
            gd.style.marginLeft = "0%";
            gd.style.marginTop = "0vh";
        }
        Plotly.newPlot(gd,"""
    )
    JSON.print(io, lowered[:data])
    print(io, ", ")
    JSON.print(io, lowered[:layout])
    print(io, """, {"showLink": false})""")

    # save to svg
    print(io, """.then((function(gd) {
        return Plotly.toImage(gd, {"format": "svg"})
    })).then((function(data) {
      var svg_data = data.replace("data:image/svg+xml,", "");
      return """
    )
    WebIO.obs_set_expr(io, svg_obs, :(decodeURIComponent(svg_data)))
    println(io, "}));")

    # make plot resize when window does
    println(io, "window.onresize = (function() {Plotly.Plots.resize(gd)});")

    # set up event listeners that populate event obs data
    for (event_name, obs) in zip(["hover", "selected", "relayout", "click"],
                                 [hover_obs, selected_obs, relayout_obs, click_obs])
        print(io, "gd.on('plotly_", event_name, "', (function(data) {")
        print(io, "var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, ")
        print(io, "'", event_name, "');\nreturn !(filtered_data.isnil) ? (")
        WebIO.obs_set_expr(io, obs, :(filtered_data.out))
        print(io, "): undefined")
        println(io, "}));\n")
    end

    # set up event listeners that _empty_ event obs data
    for (event_name, obs) in zip(["unhover", "deselect"], [hover_obs, selected_obs])
        print(io, "gd.on('plotly_", event_name, "', function() {")
        WebIO.obs_set_expr(io, obs, Dict())
        println(io, "});\n")
    end
    print(io, "}")

    onimport(scope, WebIO.JSString(String(io)))

    out = WebIOPlot(p, scope, "", api_obs, events, event_data, event_obs)
    on(data -> setfield!(out, :svg, data), svg_obs)
    out
end
