using CTBase
using Test

#
# functions and types that are not exported
const get_priority_print_callbacks = CTBase.get_priority_print_callbacks
const get_priority_stop_callbacks = CTBase.get_priority_stop_callbacks
const vec2vec  = CTBase.vec2vec

#
const gFD = getFullDescription

#
@testset verbose = true showtiming = true "Base" begin
    for name in (
        :utils,
        :exceptions,
        :callbacks,
        :descriptions,
        :functions,
        :model,
        )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
