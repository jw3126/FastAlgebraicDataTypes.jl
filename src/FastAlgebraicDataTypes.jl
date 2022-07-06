module FastAlgebraicDataTypes
import MLStyle as ML # TODO get rid of dependency

function parse_match(ex)
    matcharms = ML.@match ex begin
        quote $(matcharms...) end => map(parse_matcharm, matcharms)
        _ => error("Expected block got $ex")
    end
end

function parse_matcharm(ex)
    ML.@match ex begin
        :($Ctor($(args...)) => $body) => begin
            @assert Ctor isa Symbol
            Dict{Symbol,Any}(:Ctor => Ctor, :body=>body, :args=>args)
        end
        _ => error("Expected match arm of the form Ctor(args...) => code, got: $ex")
    end
end

function ifelsechain(
        cond_code_pairs,
        rest
    )
    if length(cond_code_pairs) == 0
        return rest
    elseif length(cond_code_pairs) == 1
        cond, code = only(cond_code_pairs)
        Expr(:if, cond, code, rest)
    else
        cond, code = cond_code_pairs[end]
        ifelsechain(
            cond_code_pairs[begin:end-1],
            Expr(:elseif, cond, code, rest),
        )
    end
end

function unwrap_adt(adt)
    Base.getfield(adt, :_data)
end

function show_adt(io::IO, adt)
    show_ctor(io, unwrap_adt(adt))
end

function matchmacro(matchee, matcharms)
    Base.remove_linenums!(matcharms)
    m = gensym("m")
    ret = quote end
    push!(ret.args, :($m=$(unwrap_adt)($matchee)))
    msg = """
    Failed to match $(matchee)
    """
    fallback = Expr(:call, match_error, msg)
    matcharms = parse_match(matcharms)
    cond_code_pairs = map(matcharms) do arm
        Ctor = arm[:Ctor]
        cond = :($m isa $Ctor)
        nargs = length(arm[:args])
        code = Expr(:block,
            Expr(:(=), Expr(:tuple, arm[:args]...), :(Tuple($m::$Ctor)::NTuple{$nargs})),
            arm[:body],
        )
        cond => code
    end
    push!(ret.args,
        ifelsechain(cond_code_pairs, fallback)
    )
    esc(ret)
end

@noinline function match_error(msg::String)
    error(msg)
end

export @match
macro match(matchee, matcharms)
    matchmacro(matchee, matcharms)
end

################################################################################
#### CTor
################################################################################
struct Ctor{Name,Typ,Tup<:Tuple}
    # _name::Val{Name}
    # _parent_type::Val{ParentType}
    _data::Tup
end
Base.Tuple(o::Ctor) = Base.getfield(o, :_data)
@nospecialize
get_name(o::Ctor{name}) where {name} = name
constructedtype(::Type{<:Ctor{name, T}}) where {name, T}= T
function show_ctor(io::IO, ctor::Ctor)
    print(io, string(get_name(ctor)))
    show(io,Tuple(ctor))
    print(io, "::", constructedtype(typeof(ctor)))
end
@specialize
################################################################################
#### @data
###
# @data MyType = CTor1() | CTor1(::Type1) | CTor2(::Type1, ::Type2)

function parse_ctor_def(ex)
    ML.@match ex begin
        :($Ctor($(args...))) => begin
            types = map(args) do arg
                ML.@match arg begin
                    :(::$T) => T
                    _ => error("""
                    Invalid Constructor definition:
                    $ex
                    Invalid arg:
                    $arg
                    """
                   )
                end
            end
            Dict(:Ctor=>Ctor, :types=>types)
        end
        _ => error("Invalid Constructor definition $ex")
    end
end

function extract_ctor_defs(ex)
    ret = Expr[]
    _extract_ctor_defs!(ret, ex)
end
function exprstarswith(ex::Expr, head, args...)
    ex.head == head || return false
    length(args) <= length(ex.args) || return false
    for i in eachindex(args)
        (ex.args[i] == args[i]) || return false
    end
    return true
end
function exprstarswith(ex::Any, args...)
    false
end
function _extract_ctor_defs!(ret, ex)
    if exprstarswith(ex, :call, Symbol("|"))
        for arg in ex.args[2:end]
            _extract_ctor_defs!(ret, arg)
        end
    else
        push!(ret, ex)
    end
    ret
end

function parse_adt_def(ex)
    Base.remove_linenums!(ex)
    ML.@match ex begin
        :($(typename::Symbol) = $(rhs)) => begin
            ctors = map(parse_ctor_def, extract_ctor_defs(rhs))
            return Dict(:typename => typename, :constructors => ctors)
        end
        _ => throw_invalid_adt_def(ex)
    end
end

function throw_invalid_adt_def(ex, hint)
    msg = """
    Syntactically incorrect defintion of algebraic data type
    $(ex)
    """
    if isempty(hint)
        error(msg)
    else
        error("$msg\n$hint")
    end
end

function datamacro(ex)
    d = parse_adt_def(ex)
    T = d[:typename]
    ctortypes = map(d[:constructors]) do item
        :($Ctor{
            $(QuoteNode(item[:Ctor])), 
            $T,
            Tuple{$(item[:types]...)},
            }
         )
    end
    ret = quote
        struct $T
            _data::Union{$(ctortypes...)}
        end
        function Base.show(io::IO, obj::$T)
            $(show_adt)(io, obj)
        end
    end
    for (item, ctortype) in zip(d[:constructors], ctortypes)
        ex = :(const $(item[:Ctor]) = $(ctortype))
        push!(ret.args, ex)
    end
    for item in d[:constructors]
        args = [gensym() for _ in 1:length(item[:types])]
        typed_args = map(args, item[:types]) do arg, Arg
            :($arg::$Arg)
        end
        ex = :(function $(item[:Ctor])($(typed_args...))::$T 
            inner = $(item[:Ctor])($(Expr(:tuple, args...)))
            $T(inner)
        end)

        push!(ret.args, ex)
    end
    ret
end

export @data
macro data(ex)
    esc(datamacro(ex))
end

end
