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


function setup_events(widget::Widget)
    # set up observables for event data
    event_data = Dict{String,Dict}()
    event_obs = Dict{String,Observable}()
    for name in ["hover", "selected", "click", "relayout"]
        event_obs[name] = Observable(widget, string("on-", name), Dict())
        event_data[name] = Dict()
        on(data -> setindex!(event_data, data, name), event_obs[name])
    end
    # TODO: hook up event_functions

    event_obs, event_data
end
