function send_command(scope, cmd, args...)
    scope["_commands"][] = [cmd, args...]
    # The handler for _commands is set up when plot is constructed
    nothing
end

# ----------------------- #
# Plotly.js api functions #
# ----------------------- #

# for each of these we first update the Julia object, then update the display

function restyle!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::AbstractDict=Dict();
        kwargs...)
        restyle!(plt.p, ind, update; kwargs...)
        send_command(plt.scope, :restyle, merge(update, prep_kwargs(kwargs)), ind .- 1)
end

function restyle!(plt::WebIOPlot, update::AbstractDict=Dict(); kwargs...)
    restyle!(plt.p, update; kwargs...)
    send_command(plt.scope, :restyle, merge(update, prep_kwargs(kwargs)))
end

function relayout!(plt::WebIOPlot, update::AbstractDict=Dict(); kwargs...)
    relayout!(plt.p, update; kwargs...)
    send_command(plt.scope, :relayout, merge(update, prep_kwargs(kwargs)))
end

function update!(
        plt::WebIOPlot, ind::Union{Int,AbstractVector{Int}},
        update::AbstractDict=Dict();
        layout::Layout=Layout(),
        kwargs...)
    update!(plt.p, ind, update; layout=layout, kwargs...)
    send_command(plt.scope, :update, merge(update, prep_kwargs(kwargs)), layout, ind .- 1)
end

function update!(
        plt::WebIOPlot, update::AbstractDict=Dict(); layout::Layout=Layout(),
        kwargs...
    )
    update!(plt.p, update; layout=layout, kwargs...)
    send_command(plt.scope, :update, merge(update, prep_kwargs(kwargs)), layout)
end

function addtraces!(plt::WebIOPlot, traces::AbstractTrace...)
    addtraces!(plt.p, traces...)
    send_command(plt.scope, :addTraces, traces)
end

function addtraces!(plt::WebIOPlot, i::Int, traces::AbstractTrace...)
    addtraces!(plt.p, i, traces...)
    send_command(plt.scope, :addTraces, traces, i-1)
end

function deletetraces!(plt::WebIOPlot, inds::Int...)
    deletetraces!(plt.p, inds...)
    send_command(plt.scope, :deleteTraces, collect(inds) .- 1)
end

function movetraces!(plt::WebIOPlot, to_end::Int...)
    movetraces!(plt.p, to_end...)
    send_command(plt.scope, :moveTraces, traces, collect(to_end) .- 1)
end

function movetraces!(
        plt::WebIOPlot, src::AbstractVector{Int}, dest::AbstractVector{Int}
    )
    movetraces!(plt.p, src, dest)
    send_command(plt.scope, :moveTraces, traces, src .- 1, dest .- 1)
end

function redraw!(plt::WebIOPlot)
    redraw!(plt.p)
    send_command(plt.scope, :redraw)
end

function purge!(plt::WebIOPlot)
    purge!(plt.p)
    send_command(plt.scope, :purge)
end

function to_image(plt::WebIOPlot; kwargs...)
    to_image(plt.p)
    send_command(plt.scope, :toImage, Dict(kwargs))
end

function download_image(plt::WebIOPlot; kwargs...)
    download_image(plt.p)
    send_command(plt.scope, :downloadImage, Dict(kwargs))
end

# unexported (by plotly.js) api methods
function extendtraces!(plt::WebIOPlot, update::AbstractDict=Dict(),
              indices::AbstractVector{Int}=[1], maxpoints=-1;)
    extendtraces!(plt.p, update, indices, maxpoints)
    send_command(
        plt.scope, :extendTraces, prep_kwargs(update), indices .- 1, maxpoints
    )
end

function prependtraces!(plt::WebIOPlot, update::AbstractDict=Dict(),
               indices::AbstractVector{Int}=[1], maxpoints=-1;)
    prependtraces!(plt.p, update, indices, maxpoints)
    send_command(
        plt.scope, :prependTraces, prep_kwargs(update), indices .- 1, maxpoints
    )
end

for f in [:restyle, :relayout, :update, :addtraces, :deletetraces,
          :movetraces, :redraw, :extendtraces, :prependtraces, :purge]
    f! = Symbol(f, "!")
    @eval function $(f)(plt::WebIOPlot, args...; kwargs...)
        out = WebIOPlot(deepcopy(plt.p))
        $(f!)(out, args...; kwargs...)
        out
    end
end
