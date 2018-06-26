function send_command(scope, cmd, args...)
    scope["_commands"][] = [cmd, args...]
    # The handler for _commands is set up when plot is constructed
    nothing
end

# ----------------------- #
# Plotly.js api functions #
# ----------------------- #

function PlotlyBase.restyle!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::Associative=Dict();
        kwargs...)
    send_command(plt.scope, :restyle, merge(update, PlotlyBase.prep_kwargs(kwargs)), ind-1)
end

function PlotlyBase.restyle!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    restyle!(plt, 1:length(plt.p.data), update; kwargs...)
end

function PlotlyBase.relayout!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    send_command(plt.scope, :relayout, merge(update, PlotlyBase.prep_kwargs(kwargs)))
end

function PlotlyBase.update!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::Associative=Dict();
        layout::Layout=Layout(),
        kwargs...)

    send_command(plt.scope, :update, merge(update, PlotlyBase.prep_kwargs(kwargs)), layout, ind-1)
end

function PlotlyBase.update!(plt::WebIOPlot, update::Associative=Dict(); kwargs...)
    PlotlyBase.update!(plt, 1:length(plt.p.data), update; kwargs...)
end
