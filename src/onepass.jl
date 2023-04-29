# onepass
# todo:
# - args not nothing (also: test try catch on this...)
# - add tests on nested begin end

"""
$(TYPEDEF)

**Fields**

"""
@with_kw mutable struct ParsingInfo
    t::Union{Symbol, Nothing}=nothing
    t0::Union{Real, Symbol, Expr, Nothing}=nothing
    tf::Union{Real, Symbol, Expr, Nothing}=nothing
    x::Union{Symbol, Nothing}=nothing
    u::Union{Symbol, Nothing}=nothing
    v::Union{Symbol, Nothing}=nothing
    aliases::OrderedDict{Symbol, Union{Real, Symbol, Expr}}=__init_aliases()
    lnum::Integer=0
    line::String=""
end

__init_aliases() = begin
    al = OrderedDict{Symbol, Union{Real, Symbol, Expr}}()
    al[:R¹] = :( R^1 )
    al[:R²] = :( R^2 )
    al[:R³] = :( R^3 )
    al[:R⁴] = :( R^4 )
    al[:R⁵] = :( R^5 )
    al[:R⁶] = :( R^6 )
    al[:R⁷] = :( R^7 )
    al[:R⁸] = :( R^8 )
    al[:R⁹] = :( R^9 )
    al
end

__sub(i) = join(Char(0x2080 + d) for d in reverse!(digits(i)))

"""
$(TYPEDSIGNATURES)

Foo

# Example
```jldoctest
Foo
```
"""
parse!(p, ocp, e; log=false) = begin
    p.lnum = p.lnum + 1
    p.line = string(e)
    for a ∈ keys(p.aliases)
        e = subs(e, a, p.aliases[a])
    end
    @match e begin
        :( $v ∈ R^$q, variable       ) => p_variable!(p, ocp, v, q; log)
        :( $v ∈ R   , variable       ) => p_variable!(p, ocp, v   ; log)
        :( $v       , variable       ) => p_variable!(p, ocp, v   ; log)
        :( $t ∈ [ $t0, $tf ], time   ) => p_time!(p, ocp, t, t0, tf; log)
        :( $x ∈ R^$n, state          ) => p_state!(p, ocp, x, n; log)
        :( $x ∈ R   , state          ) => p_state!(p, ocp, x   ; log)
        :( $x       , state          ) => p_state!(p, ocp, x   ; log)
        :( $u ∈ R^$m, control        ) => p_control!(p, ocp, u, m; log)
        :( $u ∈ R   , control        ) => p_control!(p, ocp, u   ; log)
        :( $u       , control        ) => p_control!(p, ocp, u   ; log)
        :( $a = $e1                  ) => p_alias!(p, ocp, a, e1; log)
        :( $x'($t) == $e1            ) => p_dynamics!(p, ocp, x, t, e1; log)
        :( $e1 == $e2                ) => p_constraint_eq!(p, ocp, e1, e2; log)
        :( $e1 == $e2, $label        ) => p_constraint_eq!(p, ocp, e1, e2, label; log)
        :( $e1 ≤  $e2 ≤  $e3         ) => p_constraint_ineq!(p, ocp, e1, e2, e3      ; log)
        :( $e1 ≤  $e2 ≤  $e3, $label ) => p_constraint_ineq!(p, ocp, e1, e2, e3,label; log)
        :( ∫($e1) → min              ) => p_lagrange!(p, ocp, e1, :min; log)
        :( ∫($e1) → max              ) => p_lagrange!(p, ocp, e1, :max; log)
        :( $e1 → min                 ) => p_mayer!(p, ocp, e1, :min; log)
        :( $e1 → max                 ) => p_mayer!(p, ocp, e1, :max; log)
        _ => begin
	    p.lnum = p.lnum - 1
	    if e isa LineNumberNode
                e
            elseif e isa Expr && e.head == :block
                Expr(:block, map(e -> parse!(p, ocp, e; log), e.args)...) # !!! assumes that map is done sequentially
            else
                __throw("unknown syntax ($e)")
            end end
    end
end

__throw(s) = begin
    println("ParsingError: " * s)
    :( throw(ParsingError($s)) )
end

__wrap(e, n, line) = quote
    try
        $e
    catch ex
	println("Line ", $n, ": ", $line)
        throw(ex)
    end
end

p_variable!(p, ocp, v, q=1; log=false) = begin
    log && println("variable: $v, dim: $q")
    !(v isa Symbol) && return __throw("forbidden variable name: $v")
    p.v = v
    vv = QuoteNode(v)
    qq = q isa Integer ? q : 9
    for i ∈ 1:qq p.aliases[Symbol(v, __sub(i))] = :( $v[$i] ) end
    __wrap(:( variable!($ocp, $q, $vv) ), p.lnum, p.line)
end

p_alias!(p, ocp, a, e; log=false) = begin
    log && println("alias: $a = $e")
    !(a isa Symbol) && return __throw("forbidden alias name: $a")
    aa = QuoteNode(a)
    ee = QuoteNode(e)
    p.aliases[a] = e
    __wrap(:( LineNumberNode(0, "alias: " * string($aa) * " = " * string($ee)) ), p.lnum, p.line)
end

p_time!(p, ocp, t, t0, tf; log=false) = begin
    log && println("time: $t, initial time: $t0, final time: $tf")
    !(t isa Symbol) && return __throw("forbidden time name: $t")
    p.t = t
    p.t0 = t0
    p.tf = tf
    tt = QuoteNode(t)
    code = @match (has(t0, p.v), has(tf, p.v)) begin
        (false, false) => :( time!($ocp, $t0, $tf, $tt) )
        (true , false) => @match t0 begin
            :( $v1[$i] ) => (v1 == p.v) ?
	        :( time!($ocp, Index($i), $tf, $tt) ) : __throw("bad time declaration")
            :( $v1     ) => (v1 == p.v) ?
	        quote
		    ($ocp.variable_dimension ≠ 1) &&
		        throw(IncorrectArgument("variable must be of dimension one for a time"))
	            time!($ocp, Index(1), $tf, $tt)
		end : __throw("bad time declaration")
            _            => __throw("bad time declaration") end
        (false, true ) => @match tf begin
            :( $v1[$i] ) => (v1 == p.v) ?
	        :( time!($ocp, $t0, Index($i), $tt) ) : __throw("bad time declaration")
            :( $v1     ) => (v1 == p.v) ?
	        quote
		    ($ocp.variable_dimension ≠ 1) &&
		        throw(IncorrectArgument("variable must be of dimension one for a time"))
	            time!($ocp, $t0, Index(1), $tt)
		end : __throw("bad time declaration")
            _            => __throw("bad time declaration") end
        _              => @match (t0, tf) begin
            (:( $v1[$i] ), :( $v2[$j] )) => (v1 == v2 == p.v) ?
	        :( time!($ocp, Index($i), Index($j), $tt) ) : __throw("bad time declaration")
            _ => __throw("bad time declaration") end
    end
    __wrap(code, p.lnum, p.line)
end

p_state!(p, ocp, x, n=1; log=false) = begin
    log && println("state: $x, dim: $n")
    !(x isa Symbol)  && return __throw("forbidden state name: $x")
    p.x = x
    xx = QuoteNode(x)
    nn = n isa Integer ? n : 9
    for i ∈ 1:nn p.aliases[Symbol(x, __sub(i))] = :( $x[$i] ) end
    __wrap(:( state!($ocp, $n, $xx) ), p.lnum, p.line)
end

p_control!(p, ocp, u, m=1; log=false) = begin
    log && println("control: $u, dim: $m")
    !(u isa Symbol)  && return __throw("forbidden control name: $u")
    p.u = u
    uu = QuoteNode(u)
    mm =  m isa Integer ? m : 9
    for i ∈ 1:mm p.aliases[Symbol(u, __sub(i))] = :( $u[$i] ) end
    __wrap(:( control!($ocp, $m, $uu) ), p.lnum, p.line)
end

p_constraint_eq!(p, ocp, e1, e2, label=gensym(); log=false) = begin
    log && println("constraint: $e1 == $e2,    ($label)")
    label isa Integer && ( label = Symbol(:eq, label) )
    !(label isa Symbol) && return __throw("forbidden label: $label")
    llabel = QuoteNode(label)
    code = @match constraint_type(e1, p.t, p.t0, p.tf, p.x, p.u, p.v) begin
        (:initial , nothing) => :( constraint!($ocp, :initial,       $e2, $llabel) )
        (:initial , val    ) => :( constraint!($ocp, :initial, $val, $e2, $llabel) )
        (:final   , nothing) => :( constraint!($ocp, :final  ,       $e2, $llabel) )
        (:final   , val    ) => :( constraint!($ocp, :final  , $val, $e2, $llabel) )
        (:boundary, ee1    ) => begin
            gs = gensym()
            x0 = Symbol(p.x, "#0")
            xf = Symbol(p.x, "#f")
            args = isnothing(p.v) ? [ x0, xf ] : [ x0, xf, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 == $e2") # todo: not enough (p.x alone could be nothing)
            quote
                function $gs($(args...))
                    $ee1
                end
                constraint!($ocp, :boundary, $gs, $e2, $llabel)
            end end
        (:control_fun, ee1) => begin
            gs = gensym()
            args = isnothing(p.v) ? [ p.u ] : [ p.u, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 == $e2")
            quote
                function $gs($(args...))
                    $ee1
                end
                constraint!($ocp, :control, $gs, $e2, $llabel)
            end end
        (:state_fun, ee1) => begin
            gs = gensym()
            args = isnothing(p.v) ? [ p.x ] : [ p.x, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 == $e2")
            quote
                function $gs($(args...))
                    $ee1
                end
                constraint!($ocp, :state, $gs, $e2, $llabel)
            end end
        (:mixed, ee1) => begin
            gs = gensym()
            args = isnothing(p.v) ? [ p.x, p.u ] : [ p.x, p.u, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 == $e2")
            quote
                function $gs($(args...))
                    $ee1
                end
                constraint!($ocp, :mixed, $gs, $e2, $llabel)
            end end
        _ => __throw("bad constraint declaration ($e1 == $e2)")
    end
    __wrap(code, p.lnum, p.line)
end

p_constraint_ineq!(p, ocp, e1, e2, e3, label=gensym(); log=false) = begin
    log && println("constraint: $e1 ≤ $e2 ≤ $e3,    ($label)")
    label isa Integer && ( label = Symbol(:eq, label) )
    !(label isa Symbol) && return __throw("forbidden label: $label")
    llabel = QuoteNode(label)
    code = @match constraint_type(e2, p.t, p.t0, p.tf, p.x, p.u, p.v) begin
        (:initial , nothing) => :( constraint!($ocp, :initial,       $e1, $e3, $llabel) )
        (:initial , val    ) => :( constraint!($ocp, :initial, $val, $e1, $e3, $llabel) )
        (:final   , nothing) => :( constraint!($ocp, :final  ,       $e1, $e3, $llabel) )
        (:final   , val    ) => :( constraint!($ocp, :final  , $val, $e1, $e3, $llabel) )
        (:boundary, ee2    ) => begin
            gs = gensym()
            x0 = Symbol(p.x, "#0")
            xf = Symbol(p.x, "#f")
            args = isnothing(p.v) ? [ x0, xf ] : [ x0, xf, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 ≤ $e2 ≤ $e3")
            quote
                function $gs($(args...))
                    $ee2
                end
                constraint!($ocp, :boundary, $gs, $e1, $e3, $llabel)
            end end
        (:control_range, nothing) => :( constraint!($ocp, :control,       $e1, $e3, $llabel) )
        (:control_range, val    ) => :( constraint!($ocp, :control, $val, $e1, $e3, $llabel) )
        (:control_fun, ee2) => begin
            gs = gensym()
            args = isnothing(p.v) ? [ p.u ] : [ p.u, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 ≤ $e2 ≤ $e3")
            quote
                function $gs($(args...))
                    $ee2
                end
                constraint!($ocp, :control, $gs, $e1, $e3, $llabel)
            end end
        (:state_range, nothing) => :( constraint!($ocp, :state,       $e1, $e3, $llabel) )
        (:state_range, val    ) => :( constraint!($ocp, :state, $val, $e1, $e3, $llabel) )
        (:state_fun, ee2) => begin
            gs = gensym()
            args = isnothing(p.v) ? [ p.x ] : [ p.x, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 ≤ $e2 ≤ $e3")
            quote
                function $gs($(args...))
                    $ee2
                end
                constraint!($ocp, :state, $gs, $e1, $e3, $llabel)
            end end
        (:mixed, ee2) => begin
            gs = gensym()
            args = isnothing(p.v) ? [ p.x, p.u ] : [ p.x, p.u, p.v ]
            (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse contraint ($e1 ≤ $e2 ≤ $e3")
            quote
                function $gs($(args...))
                    $ee2
                end
                constraint!($ocp, :mixed, $gs, $e1, $e3, $llabel)
            end end
        _ => __throw("bad constraint declaration ($e1 ≤ $e2 ≤ $e3)")
    end
    __wrap(code, p.lnum, p.line)
end

p_dynamics!(p, ocp, x, t, e; log=false) = begin
    log && println("dynamics: $x'($t) == $e")
    x ≠ p.x && return __throw("wrong state for dynamics")
    t ≠ p.t && return __throw("wrong time for dynamics")
    e = replace_call(e, p.t)
    gs = gensym()
    args = isnothing(p.v) ? [ p.x, p.u ] : [ p.x, p.u, p.v ]
    (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse dynamics ($x'($t) == $e)")
    __wrap(quote
        function $gs($(args...))
            $e
        end
        constraint!($ocp, :dynamics, $gs)
    end, p.lnum, p.line)
end

p_lagrange!(p, ocp, e, type; log=false) = begin
    log && println("objective: ∫($e) → $type")
    e = replace_call(e, p.t)
    ttype = QuoteNode(type)
    gs = gensym()
    args = isnothing(p.v) ? [ p.x, p.u ] : [ p.x, p.u, p.v ]
    (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse objective (∫($e) → $type)")
    __wrap(quote
        function $gs($(args...))
            $e
        end
        objective!($ocp, :lagrange, $gs, $ttype)
    end, p.lnum, p.line)
end

p_mayer!(p, ocp, e, type; log=false) = begin
    log && println("objective: $e → $type")
    gs = gensym()
    x0 = Symbol(p.x, "#0")
    xf = Symbol(p.x, "#f")
    ee = replace_call(e , p.x, p.t0, x0)
    ee = replace_call(ee, p.x, p.tf, xf)
    ttype = QuoteNode(type)
    args = isnothing(p.v) ? [ x0, xf ] : [ x0, xf, p.v ]
    (typeof(args) == Vector{Nothing}) && return __throw("not enough context to parse objective ($e → $type") # todo: not enough (p.x alone could be nothing)
    __wrap(quote
        function $gs($(args...))
            $ee
        end
        objective!($ocp, :mayer, $gs, $ttype)
    end, p.lnum, p.line)
end

"""
$(TYPEDSIGNATURES)

Implement def1 macro core.

"""
macro _def1(ocp, e, log=false)
    try
        p = ParsingInfo()
        esc( parse!(p, ocp, e; log=log) )
    catch ex
        :( throw($ex) ) # can be catched by user 
    end
end

"""
$(TYPEDSIGNATURES)

Define an optimal control problem. One pass parsing of the definition.

# Example
```jldoctest
@def1 begin
    t ∈ [ 0, 1 ], time
    x ∈ R^2, state
    u ∈ R  , control
    x(0) == [ 1, 2 ]
    x(1) == [ 0, 0 ]
    x'(t) == [ x[2](t), u(t) ]
    ∫( u(t)^2 ) → min
end
```
"""
macro def1(e, log=false)
    esc( quote ocp = Model(); @_def1 ocp $e $log; ocp end )
end
