"""
$(TYPEDEF)

Abstract type for functions.
"""
abstract type AbstractCTFunction <: Function end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

The default value for `variable_dependence` is `:v_indep`.

!!! warning

    When the state is of dimension 1, consider `x0` and `xf` as a scalar. When the constraint is dimension 1, return a scalar.

## Examples

```@example
julia> B = BoundaryConstraint((x0, xf) -> [xf[2]-x0[1], 2xf[1]+x0[2]^2]) # variable_dependence=:v_indep by default
julia> B([0, 0], [1, 1])
[1, 2]
julia> B([0, 0], [1, 1], [])
[1, 2]
julia> B = BoundaryConstraint((x0, xf, v) -> [v[3]+xf[2]-x0[1], v[1]-v[2]+2xf[1]+x0[2]^2], variable_dependence=:v_dep)
julia> B([0, 0], [1, 1], [1, 2, 3])
[4, 1]
```
"""
struct BoundaryConstraint{variable_dependence}
    f::Function
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

The default value for `variable_dependence` is `:v_indep`.

!!! warning

    When the state is of dimension 1, consider `x0` and `xf` as a scalar.

## Examples

```@example
julia> G = Mayer((x0, xf) -> [xf[2]-x0[1]]) # variable_dependence=:v_indep by default
julia> G([0, 0], [1, 1])
MethodError
julia> G = Mayer((x0, xf) -> xf[2]-x0[1])
julia> G([0, 0], [1, 1])
1
julia> G([0, 0], [1, 1], [])
1
julia> G = Mayer((x0, xf, v) -> v[3]+xf[2]-x0[1], variable_dependence=:v_dep)
julia> G([0, 0], [1, 1], [1, 2, 3])
4
```
"""
struct Mayer{variable_dependence}
    f::Function
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

The default values for `time_dependence` and `variable_dependence` are `:t_indep` and `:v_indep` respectively.

!!! warning

    When the state and adjoint are of dimension 1, consider `x` and `p` as scalars.

## Examples

```@example
julia> Hamiltonian((x, p) -> x + p, time_dependence=:dummy)
IncorrectArgument 
julia> Hamiltonian((x, p) -> x + p, variable_dependence=:dummy)
IncorrectArgument
julia> H = Hamiltonian((x, p) -> [x[1]^2+2p[2]]) # time_dependence=:t_indep, variable_dependence=:v_indep
julia> H([1, 0], [0, 1])
MethodError # H must return a scalar
julia> H = Hamiltonian((x, p) -> x[1]^2+2p[2])
julia> H([1, 0], [0, 1])
3
julia> t = 1
julia> v = []
julia> H(t, [1, 0], [0, 1])
MethodError
julia> H([1, 0], [0, 1], v)
MethodError 
julia> H(t, [1, 0], [0, 1], v)
3
julia> H = Hamiltonian((x, p, v) -> [x[1]^2+2p[2]+v[3]], variable_dependence=:v_dep)
julia> H([1, 0], [0, 1], [1, 2, 3])
6
julia> H(t, [1, 0], [0, 1], [1, 2, 3])
6
julia> H = Hamiltonian((t, x, p) -> [t+x[1]^2+2p[2]], time_dependence=:t_dep)
julia> H(1, [1, 0], [0, 1])
4
julia> H(1, [1, 0], [0, 1], v)
4
julia> H = Hamiltonian((t, x, p, v) -> [t+x[1]^2+2p[2]+v[3]], time_dependence=:t_dep, variable_dependence=:v_dep)
julia> H(1, [1, 0], [0, 1], [1, 2, 3])
7
```
"""
struct Hamiltonian{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

The default values for `time_dependence` and `variable_dependence` are `:t_indep` and `:v_indep` respectively.

!!! warning

    When the state and adjoint are of dimension 1, consider `x` and `p` as scalars.

## Examples

```@example
julia> HamiltonianVectorField((x, p) -> [x[1]^2+2p[2], x[2]-3p[2]^2], time_dependence=:dummy)
IncorrectArgument
julia> HamiltonianVectorField((x, p) -> [x[1]^2+2p[2], x[2]-3p[2]^2], variable_dependence=:dummy)
IncorrectArgument
julia> Hv = HamiltonianVectorField((x, p) -> [x[1]^2+2p[2], x[2]-3p[2]^2]) # time_dependence=:t_indep, variable_dependence=:v_indep
julia> Hv([1, 0], [0, 1])
[3, -3]
julia> t = 1
julia> v = []
julia> Hv(t, [1, 0], [0, 1])
MethodError
julia> Hv([1, 0], [0, 1], v)
MethodError
julia> Hv(t, [1, 0], [0, 1], v)
[3, -3]
julia> Hv = HamiltonianVectorField((x, p, v) -> [x[1]^2+2p[2]+v[3], x[2]-3p[2]^2+v[4]], variable_dependence=:v_dep)
julia> Hv([1, 0], [0, 1], [1, 2, 3, 4])
[6, -3]
julia> Hv(t, [1, 0], [0, 1], [1, 2, 3, 4])
[6, -3]
julia> Hv = HamiltonianVectorField((t, x, p) -> [t+x[1]^2+2p[2], x[2]-3p[2]^2], time_dependence=:t_dep)
julia> Hv(1, [1, 0], [0, 1])
[4, -3]
julia> Hv(1, [1, 0], [0, 1], v)
[4, -3]
julia> Hv = HamiltonianVectorField((t, x, p, v) -> [t+x[1]^2+2p[2]+v[3], x[2]-3p[2]^2+v[4]], time_dependence=:t_dep, variable_dependence=:v_dep)
julia> Hv(1, [1, 0], [0, 1], [1, 2, 3, 4])
[7, -3]
```
"""
struct HamiltonianVectorField{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

The default value for `time_dependence` and `variable_dependence` are `:t_indep` and `:v_indep` respectively.

!!! warning

    When the state is of dimension 1, consider `x` as a scalar.

## Examples

```@example
julia> VectorField(x -> [x[1]^2, 2x[2]], time_dependence=:dummy)
IncorrectArgument
julia> VectorField(x -> [x[1]^2, 2x[2]], variable_dependence=:dummy)
IncorrectArgument
julia> V = VectorField(x -> [x[1]^2, 2x[2]]) # time_dependence=:t_indep, variable_dependence=:v_indep
julia> V([1, -1])
[1, -2]
julia> t = 1
julia> v = []
julia> V(t, [1, -1])
MethodError
julia> V([1, -1], v)
MethodError
julia> V(t, [1, -1], v)
[1, -2]
julia> V = VectorField((x, v) -> [x[1]^2, 2x[2]+v[3]], variable_dependence=:v_dep)
julia> V([1, -1], [1, 2, 3])
[1, 1]
julia> V(t, [1, -1], [1, 2, 3])
[1, 1]
julia> V = VectorField((t, x) -> [t+x[1]^2, 2x[2]], time_dependence=:t_dep)
julia> V(1, [1, -1])
[2, -2]
julia> V(1, [1, -1], v)
[2, -2]
julia> V = VectorField((t, x, v) -> [t+x[1]^2, 2x[2]+v[3]], time_dependence=:t_dep, variable_dependence=:v_dep)
julia> V(1, [1, -1], [1, 2, 3])
[2, 1]
```
"""
struct VectorField{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

The default value for `time_dependence` and `variable_dependence` are `:t_indep` and `:v_indep` respectively.

!!! warning

    When the state is of dimension 1, consider `x` as a scalar. Same for the control.

## Examples

```@example
julia> Lagrange((x, u) -> 2x[2]-u[1]^2, time_dependence=:dummy)
IncorrectArgument
julia> Lagrange((x, u) -> 2x[2]-u[1]^2, variable_dependence=:dummy)
IncorrectArgument
julia> L = Lagrange((x, u) -> [2x[2]-u[1]^2], time_dependence=:t_indep, variable_dependence=:v_indep)
julia> L([1, 0], [1])
MethodError
julia> L = Lagrange((x, u) -> 2x[2]-u[1]^2, time_dependence=:t_indep, variable_dependence=:v_indep)
julia> L([1, 0], [1])
-1
julia> t = 1
julia> v = []
julia> L(t, [1, 0], [1])
MethodError
julia> L([1, 0], [1], v)
MethodError
julia> L(t, [1, 0], [1], v)
-1
julia> L = Lagrange((x, u, v) -> 2x[2]-u[1]^2+v[3], time_dependence=:t_indep, variable_dependence=:v_dep)
julia> L([1, 0], [1], [1, 2, 3])
2
julia> L(t, [1, 0], [1], [1, 2, 3])
2
julia> L = Lagrange((t, x, u) -> t+2x[2]-u[1]^2, time_dependence=:t_dep, variable_dependence=:v_indep)
julia> L(1, [1, 0], [1])
0
julia> L(1, [1, 0], [1], v)
0
julia> L = Lagrange((t, x, u, v) -> t+2x[2]-u[1]^2+v[3], time_dependence=:t_dep, variable_dependence=:v_dep)
julia> L(1, [1, 0], [1], [1, 2, 3])
3
```
"""
struct Lagrange{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `Lagrange`, but the function `f` is assumed to return a vector of the same dimension as the state `x`.

"""
struct Dynamics{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `VectorField` in the usage, but the dimension of the output of the function `f` is arbitrary.

"""
struct StateConstraint{time_dependence, variable_dependence}
    f::Function
end

"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `VectorField` in the usage, but the dimension of the output of the function `f` is arbitrary.

"""
struct ControlConstraint{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `Lagrange` in the usage, but the dimension of the output of the function `f` is arbitrary.

"""
struct MixedConstraint{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

!!! warning

    When the variable is of dimension 1, consider `v` as a scalar.

"""
struct VariableConstraint
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `VectorField` in the usage, but the dimension of the output of the function `f` is arbitrary.

"""
struct FeedbackControl{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `Hamiltonian` in the usage, but the dimension of the output of the function `f` is arbitrary.

"""
struct ControlLaw{time_dependence, variable_dependence}
    f::Function
end


"""
$(TYPEDEF)

**Fields**

$(TYPEDFIELDS)

Similar to `ControlLaw` in the usage.

"""
struct Multiplier{time_dependence, variable_dependence}
    f::Function
end
