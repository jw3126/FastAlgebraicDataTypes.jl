module TestProp

using FastAlgebraicDataTypes

@data Prop = Lit(::Bool) | Not(::Prop) | And(::Prop, ::Prop) | Or(::Prop, ::Prop) | Var(::Int)

function depth(p::Prop)
    @match p begin
        Lit(x) => 1
        And(x,y) => 1 + max(depth(x), depth(y))
        Or(x, y) => 1 + max(depth(x), depth(y))
        Not(x) => 1 + depth(x)
        Var(i) => 1
    end
end


foo = And(
          Or(
            Lit(true),
            Var(1),
        ),
    Not(Var(2))
)
using Test
@inferred depth(foo) == 3
@test depth(foo) == 3
@test foo == deepcopy(foo)
@test foo === deepcopy(foo)

end
