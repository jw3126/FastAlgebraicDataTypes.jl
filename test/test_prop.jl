module TestProp

using Test
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

function is_and_or(p::Prop)
    @match p begin
        And(x,y) => true
        Or(x,y) => true
        _ => false
    end
end

@test !is_and_or(Lit(true))
@test !is_and_or(Var(1))
@test !is_and_or(Not(Var(1)))
@test is_and_or(Or(Var(1), Lit(true)))
@test is_and_or(And(Var(1), Lit(true)))

foo = And(
          Or(
            Lit(true),
            Var(1),
        ),
    Not(Var(2))
)
@inferred depth(foo) == 3
@test depth(foo) == 3
@test foo == deepcopy(foo)
@test foo === deepcopy(foo)

end
