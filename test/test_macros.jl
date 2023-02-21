function test_macros()
end

f(x) = 2x

# no fields
@callable struct MyStruct end
@test MyStruct(f)(2) == 4

# with other fields
@callable struct MyStructWithFields
    a::Real
    b
end
#
m = MyStructWithFields(f, 20, 30)
@test m(2) == 4
@test m.a == 20
@test m.b == 30
#

# Parametric structures
@callable struct MyParamStruct1{T}
    a::T
    b
end
#
m = MyParamStruct1{Real}(f, 20, 30)
@test m(2) == 4
@test m.a == 20
@test m.b == 30
#

@callable struct MyParamStruct2{T, R}
    a::T
    b::R
end
#
m = MyParamStruct2{Real, Real}(f, 20, 30)
@test m(2) == 4
@test m.a == 20
@test m.b == 30
#