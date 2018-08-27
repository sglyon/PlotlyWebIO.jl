mutable struct WebIOPlot
    p::PlotlyBase.Plot
    scope::Scope
end

Base.getindex(p::WebIOPlot, key) = p.scope[key] # look up Observables

WebIO.render(p::WebIOPlot) = WebIO.render(p.scope)
Base.show(io::IO, mm::MIME"text/plain", p::WebIOPlot) = show(io, mm, p.p)
Base.show(io::IO, mm::MIME"text/html", p::WebIOPlot) = show(io, mm, p.scope)

function WebIOPlot(
        args...;
        events::AbstractDict=Dict(),
        options::AbstractDict=Dict("showLink"=> false),
        kwargs...
    )
    # build plot, get json, setup options
    p = Plot(args...; kwargs...)
    lowered = JSON.lower(p)
    id = string("#plot-", p.divid)

    # setup scope
    deps = [
        "Plotly" => joinpath(@__DIR__, "..", "assets", "plotly-latest.min.js"),
        joinpath(@__DIR__, "..", "assets", "plotly_webio_bundle.js")
    ]
    scope = Scope(imports=deps)
    scope.dom = dom"div"(id=string("plot-", p.divid), events=events)

    # INPUT: Observables for plot events
    scope["svg"] = Observable("")
    scope["hover"] = Observable(Dict())
    scope["selected"] = Observable(Dict())
    scope["click"] = Observable(Dict())
    scope["relayout"] = Observable(Dict())

    # OUTPUT: setup an observable which sends modify commands
    scope["_commands"] = Observable{Any}([])

    # Do the respective action when _commands is triggered
    onjs(scope["_commands"], @js function (args)
        @var fn = args.shift()
        @var elem = this.plotElem
        @var Plotly = this.Plotly
        args.unshift(elem) # use div as first argument

        Plotly[fn].apply(this, args).then(function(gd)
            Plotly.toImage(elem, Dict("format" => "svg"))
        end).then(function(data)
            # TODO: make this optional
            @var svg_data = data.replace("data:image/svg+xml,", "")
            $(scope["svg"])[] = decodeURIComponent(svg_data)
        end)
    end)

    onimport(scope, JSExpr.@js function (Plotly)

        # set up container element
        @var gd = this.dom.querySelector($id);

        # save some vars for later
        this.plotElem = gd
        this.Plotly = Plotly
        if (window.Blink !== undefined)
            # set css style for auto-resize
            gd.style.width = "100%";
            gd.style.height = "100vh";
            gd.style.marginLeft = "0%";
            gd.style.marginTop = "0vh";
        end

        window.onresize = () -> Plotly.Plots.resize(gd)

        function save_svg()
            Plotly.toImage(gd, $(Dict("format" => "svg"))).then(function(data)
                @var svg_data = data.replace("data:image/svg+xml,", "")
                $(scope["svg"])[] = decodeURIComponent(svg_data)
            end)
        end

        # Draw plot in container
        Plotly.newPlot(
            gd, $(lowered[:data]), $(lowered[:layout]), $(options)
        ).then(save_svg);

        # hook into plotly events
        gd.on("plotly_hover", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "hover");
            if !(filtered_data.isnil)
                $(scope["hover"])[] = filtered_data.out
            end
        end)

        gd.on("plotly_unhover", () -> $(scope["hover"])[] = Dict())

        gd.on("plotly_selected", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "selected");
            if !(filtered_data.isnil)
                $(scope["selected"])[] = filtered_data.out
            end
        end)

        gd.on("plotly_deselect", () -> $(scope["selected"])[] = Dict())

        gd.on("plotly_relayout", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "relayout");
            if !(filtered_data.isnil)
                $(scope["relayout"])[] = filtered_data.out
            end
        end)

        gd.on("plotly_click", function (data)
            @var filtered_data = WebIO.CommandSets.Plotly.filterEventData(gd, data, "click");
            if !(filtered_data.isnil)
                $(scope["click"])[] = filtered_data.out
            end
        end)
    end)

    # create no-op `on` callback for svg so it is _always_ sent
    # to us
    on(scope["svg"]) do x end

    WebIOPlot(p, scope)
end
