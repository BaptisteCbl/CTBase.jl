"""
$(TYPEDEF)

Abstract node for plot.
"""
abstract type AbstractPlotTreeElement end

"""
$(TYPEDEF)

A leaf of a plot tree.
"""
struct PlotLeaf <: AbstractPlotTreeElement
    value::Tuple{Symbol,Integer}
    PlotLeaf(value::Tuple{Symbol,Integer}) = new(value) 
end

"""
$(TYPEDEF)

A node of a plot tree.
"""
struct PlotNode <: AbstractPlotTreeElement
    layout::Union{Symbol, Matrix{Any}}
    children::Vector{<:AbstractPlotTreeElement}
    PlotNode(layout::Union{Symbol, Matrix{Any}}, 
        children::Vector{<:AbstractPlotTreeElement}) = new(layout, children)
end

# --------------------------------------------------------------------------------------------------
# internal plots
"""
$(TYPEDSIGNATURES)

Update the plot `p` with the i-th component of a vectorial function of time `f(t) ∈ Rᵈ` where
`f` is given by the symbol `s`.
The argument `s` can be `:state`, `:control` or `:costate`.
"""
function __plot_time!(p::Union{Plots.Plot, Plots.Subplot}, sol::OptimalControlSolution, s::Symbol, i::Integer; 
    t_label, label::String, kwargs...)
    return CTBase.plot!(p, sol, :time, (s, i); xlabel=t_label, label=label, kwargs...) # use simple plot
end

"""
$(TYPEDSIGNATURES)

Plot the i-th component of a vectorial function of time `f(t) ∈ Rᵈ` where `f` is given by the symbol `s`.
The argument `s` can be `:state`, `:control` or `:costate`.
"""
function __plot_time(sol::OptimalControlSolution, s::Symbol, i::Integer; t_label, label::String, kwargs...)
    return __plot_time!(Plots.plot(), sol, s, i; t_label=t_label, label=label, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Update the plot `p` with a vectorial function of time `f(t) ∈ Rᵈ` where `f` is given by the symbol `s`.
The argument `s` can be `:state`, `:control` or `:costate`.
"""
function __plot_time!(p::Union{Plots.Plot, Plots.Subplot}, sol::OptimalControlSolution, d::Dimension, s::Symbol; 
    t_label, labels::Vector{String}, title::String, kwargs...)
    Plots.plot!(p; xlabel="time", title=title, kwargs...)
    for i in range(1, d)
        __plot_time!(p, sol, s, i; t_label=t_label, label=labels[i], kwargs...)
    end
    return p
end

"""
$(TYPEDSIGNATURES)

Plot a vectorial function of time `f(t) ∈ Rᵈ` where `f` is given by the symbol `s`.
The argument `s` can be `:state`, `:control` or `:costate`.
"""
function __plot_time(sol::OptimalControlSolution, d::Dimension, s::Symbol; t_label, labels::Vector{String}, title::String, kwargs...)
    return __plot_time!(Plots.plot(), sol, d, s; t_label=t_label, labels=labels, title=title, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Generate a{r*h} where `r` is a real number and `h` is the height of the plot.
"""
function __width(r::Real)::Expr
    i = Expr(:call, :*, r, :h)
    a = Expr(:curly, :a, i)
    return a
end

"""
$(TYPEDSIGNATURES)

Plot a leaf.
"""
function __plot_tree(leaf::PlotLeaf, depth::Integer; kwargs...)
    return Plots.plot()
end

"""
$(TYPEDSIGNATURES)

Plot a node.
"""
function __plot_tree(node::PlotNode, depth::Integer=0; kwargs...)
    #
    subplots=()
    #
    for c ∈ node.children
        pc = __plot_tree(c, depth+1)
        subplots = (subplots..., pc)
    end
    #
    kwargs_plot = depth==0 ? kwargs : ()
    ps = @match node.layout begin
        :row    => plot(subplots...; layout=(1, size(subplots, 1)), kwargs_plot...)
        :column => plot(subplots...; layout=(size(subplots, 1), 1), kwargs_plot...)
        _ => plot(subplots...; layout=node.layout, kwargs_plot...)
    end

    return ps
end

"""
$(TYPEDSIGNATURES)

Initial plot.
"""
function __initial_plot(sol::OptimalControlSolution; layout::Symbol=:split,
    control::Symbol=:components, kwargs...)

    # parameters
    n = sol.state_dimension
    m = sol.control_dimension
    
    if layout==:group

        @match control begin
            :components => begin
                px = Plots.plot() # state
                pp = Plots.plot() # costate
                pu = Plots.plot() # control
                return Plots.plot(px, pp, pu, layout=(1, 3); kwargs...)
            end
            :norm => begin
                px = Plots.plot() # state
                pp = Plots.plot() # costate
                pn = Plots.plot() # control norm
                return Plots.plot(px, pp, pn, layout=(1, 3); kwargs...)
            end
            :all => begin
                px = Plots.plot() # state
                pp = Plots.plot() # costate
                pu = Plots.plot() # control
                pn = Plots.plot() # control norm
                return Plots.plot(px, pp, pu, pn, layout=(2, 2); kwargs...)
            end
            _ => throw(IncorrectArgument("No such choice for control. Use :components, :norm or :all"))
        end


    elseif layout==:split

        # create tree plot
        state_plots   = Vector{PlotLeaf}()
        costate_plots = Vector{PlotLeaf}()
        control_plots = Vector{PlotLeaf}()

        for i ∈ 1:n
            push!(state_plots,   PlotLeaf((:state,   i)))
            push!(costate_plots, PlotLeaf((:costate, i)))
        end
        l = m
        @match control begin
            :components => begin
                for i ∈ 1:m
                    push!(control_plots, PlotLeaf((:control, i)))
                end
            end
            :norm => begin
                push!(control_plots, PlotLeaf((:control_norm, -1)))
                l = 1
            end
            :all => begin
                for i ∈ 1:m
                    push!(control_plots, PlotLeaf((:control, i)))
                end
                push!(control_plots, PlotLeaf((:control_norm, -1)))
                l = m+1
            end
            _ => throw(IncorrectArgument("No such choice for control. Use :components, :norm or :all"))
        end

        #
        node_x  = PlotNode(:column, state_plots)
        node_p  = PlotNode(:column, costate_plots)
        node_u  = PlotNode(:column, control_plots)
        node_xp = PlotNode(:row, [node_x, node_p])

        #
        r = round(n/(n+l), digits=2)
        a = __width(r)
        @eval lay = @layout [$a
                            b]
        root = PlotNode(lay, [node_xp, node_u])

        # plot
        return __plot_tree(root; kwargs...)

    else

        throw(IncorrectArgument("No such choice for layout. Use :group or :split"))

    end

end

"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol` using the layout `layout`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function CTBase.plot!(p::Plots.Plot, sol::OptimalControlSolution; layout::Symbol=:split,
    control::Symbol=:components ,state_style=(), control_style=(), costate_style=(), kwargs...)

    #
    n = sol.state_dimension
    m = sol.control_dimension
    x_labels = sol.state_components_names
    u_labels = sol.control_components_names
    u_label = sol.control_name
    t_label = sol.time_name

    if layout==:group
        
        __plot_time!(p[1], sol, n, :state;   t_label=t_label, labels=x_labels,      title="state",   lims=:auto, state_style...)
        __plot_time!(p[2], sol, n, :costate; t_label=t_label, labels="p".*x_labels, title="costate", lims=:auto, costate_style...)
        @match control begin
            :components => begin
                __plot_time!(p[3], sol, m, :control; t_label=t_label, labels=u_labels, title="control", lims=:auto, control_style...)
            end
            :norm => begin
                __plot_time!(p[3], sol, :control_norm, -1; t_label=t_label, label="‖"*u_label*"‖", title="control norm", lims=:auto, control_style...)
            end
            :all => begin
                __plot_time!(p[3], sol, m, :control; t_label=t_label, labels=u_labels, title="control", lims=:auto, control_style...)
                __plot_time!(p[4], sol, :control_norm, -1; t_label=t_label, label="‖"*u_label*"‖", title="control norm", lims=:auto, control_style...)
            end
            _ => throw(IncorrectArgument("No such choice for control. Use :components, :norm or :all"))
        end

    elseif layout==:split

        for i ∈ 1:n
            __plot_time!(p[i],   sol, :state,   i; t_label=t_label, label=x_labels[i],     state_style...)
            __plot_time!(p[i+n], sol, :costate, i; t_label=t_label, label="p"*x_labels[i], costate_style...)
        end
        @match control begin
            :components => begin
                for i ∈ 1:m
                    __plot_time!(p[i+2*n], sol, :control, i; t_label=t_label, label=u_labels[i], control_style...)
                end
            end
            :norm => begin
                __plot_time!(p[2*n+1], sol, :control_norm, -1; t_label=t_label, label="‖"*u_label*"‖", control_style...)
            end
            :all => begin
                for i ∈ 1:m
                    __plot_time!(p[i+2*n], sol, :control, i; t_label=t_label, label=u_labels[i], control_style...)
                end
                __plot_time!(p[2*n+m+1], sol, :control_norm, -1; t_label=t_label, label="‖"*u_label*"‖", control_style...)
            end
            _ => throw(IncorrectArgument("No such choice for control. Use :components, :norm or :all"))
        end

    else

        throw(IncorrectArgument("No such choice for layout. Use :group or :split"))

    end

    return p

end


"""
$(TYPEDSIGNATURES)

Plot the optimal control solution `sol` using the layout `layout`.

**Notes.**

- The argument `layout` can be `:group` or `:split` (default).
- The keyword arguments `state_style`, `control_style` and `costate_style` are passed to the `plot` function of the `Plots` package. The `state_style` is passed to the plot of the state, the `control_style` is passed to the plot of the control and the `costate_style` is passed to the plot of the costate.
"""
function CTBase.plot(sol::OptimalControlSolution; layout::Symbol=:split, state_style=(), control_style=(), costate_style=(), kwargs...)
    p = __initial_plot(sol; layout=layout, kwargs...)
    return plot!(p, sol; layout=layout, state_style=state_style, control_style=control_style, costate_style=costate_style, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return `x` and `y` for the plot of the optimal control solution `sol` 
corresponding respectively to the argument `xx` and the argument `yy`.

**Notes.**

- The argument `xx` can be `:time`, `:state`, `:control` or `:costate`.
- If `xx` is `:time`, then, a label is added to the plot.
- The argument `yy` can be `:state`, `:control` or `:costate`.
"""
@recipe function f(sol::OptimalControlSolution,
    xx::Union{Symbol,Tuple{Symbol,Integer}}, 
    yy::Union{Symbol,Tuple{Symbol,Integer}})
    x = __get_data_plot(sol, xx)
    y = __get_data_plot(sol, yy)
    if xx isa Symbol && xx==:time
        s, i = @match yy begin
            ::Symbol => (yy, 1)
            _        => yy
        end
        label = @match s begin
            :state   => sol.state_components_names[i]
            :control => sol.control_components_names[i]
            :costate => "p"*sol.state_components_names[i]
            :control_norm => "‖"*sol.control_name*"‖"
            _        => error("Internal error, no such choice for label")
        end
        # change ylims if the gap between min and max is less than a tol
        tol = 1e-3
        ymin = minimum(y)
        ymax = maximum(y)
        if abs(ymax-ymin) ≤ abs(ymin)*tol
            ymiddle = (ymin+ymax)/2.0
            ylims --> (0.9*ymiddle, 1.1*ymiddle)
        end
    end
    return x, y
end

"""
$(TYPEDSIGNATURES)

Get the data for plotting.
"""
function __get_data_plot(sol::OptimalControlSolution, 
    xx::Union{Symbol,Tuple{Symbol,Integer}})

    T = sol.times
    X = sol.state.(T)
    U = sol.control.(T)
    P = sol.costate.(T)

    vv, ii = @match xx begin
        ::Symbol => (xx, 1)
        _        => xx
    end

    m = size(T, 1)
    return @match vv begin
        :time    => T
        :state   => [X[i][ii] for i in 1:m]
        :control => [U[i][ii] for i in 1:m]
        :costate => [P[i][ii] for i in 1:m]
        :control_norm => [norm(U[i]) for i in 1:m]
        _        => error("Internal error, no such choice for xx")
    end

end