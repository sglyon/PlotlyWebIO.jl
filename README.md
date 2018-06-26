# PlotlyWebIO

[![Build Status](https://travis-ci.org/sglyon/PlotlyWebIO.jl.svg?branch=master)](https://travis-ci.org/sglyon/PlotlyWebIO.jl)

[![Coverage Status](https://coveralls.io/repos/sglyon/PlotlyWebIO.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/sglyon/PlotlyWebIO.jl?branch=master)

[![codecov.io](http://codecov.io/github/sglyon/PlotlyWebIO.jl/coverage.svg?branch=master)](http://codecov.io/github/sglyon/PlotlyWebIO.jl?branch=master)

This is the work in progress prototype for a new display system for Plotly.js charts in Julia. The goal is to eventually replace the display code in PlotlyJS.jl with the code here, once WebIO.jl has matured and once the code here is usable and functioning properly.

# Usage

## Event handling

PlotlyWebIO.jl allows users to subscribe to events fired by the plotly.js library (e.g. `plotly_hover`, `plotly_click`, `plotly_unhover`, etc.) using Julia functions. This means you can trigger Julia functions in response to browser events. These Julia functions can run arbitrary Julia code, including sending instructions back to the javascript frontend.

The description below is from @shashi comment in #6:

plot["hover"]` is forwarded to `plot.scope["hover"]`, this means you can now add handlers like this:
```
on(plot["hover"]) do event_data
  ... handle a hover event ...
end
```
or
```
# JS
onjs(plot["hover"], @js (event) -> ...)
```
If you want to directly handle raw [PlotlyJS events](https://plot.ly/javascript/plotlyjs-events/) you can pass an `events` kwarg (dict of event name to js function) which is forwarded to the plotDiv. (These events have to be named `plotly_hover` etc. with the prefix and all. This is JS-only!

## Developers

To update build of plotly_webio_bundle.js do

```
cd assets
npx webpack ./index.js ./plotly_webio_bundle.js
```
