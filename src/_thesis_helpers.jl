
using HerbCore, HerbConstraints, HerbSearch, HerbGrammar, HerbSpecification, HerbInterpret, MLStyle, Random

#get an unique filename
function get_filename(prefix)
    name = "data/"*prefix*"_run"
    count = 0
    while isfile(name*string(count)*".txt")
        count += 1
    end
    return name*string(count)*".txt"
end

#grammar types
robots = 1
arithmetic = 2
symbolic = 3
lists = 4
lists_grounded = 5

function get_starting_symbol(grammartype::Int)
    return @match grammartype begin
        1 => :Sequence
        2 => :Int
        3 => :S
        4 => :List
        5 => :List
    end
end

function get_thesis_grammar(grammartype::Int, number_of_constraints::Int=typemax(Int))
    grammar, constraints = @match grammartype begin
        1 => get_grammar_robots()
        2 => get_grammar_arithmetic()
        3 => get_grammar_symbolic()
        4 => get_grammar_lists()
        5 => get_grammar_lists_grounded()
    end

    #randomly pick `number_of_constraints` constraints
    if number_of_constraints < length(constraints)
        indices = randperm(length(constraints))[1:number_of_constraints]
        constraints = constraints[indices]
    end

    #add the constraints to the grammar
    for constraint ∈ constraints
        addconstraint!(grammar, constraint)
    end

    return grammar
end

function get_grammar_robots()
    grammar = @csgrammar begin
        Sequence = (moveRight(); Sequence)
        Sequence = (moveDown(); Sequence)
        Sequence = (moveLeft(); Sequence)
        Sequence = (moveUp(); Sequence)
        Sequence = (drop(); Sequence)
        Sequence = (grab(); Sequence)
        Sequence = return
    end
    clearconstraints!(grammar)
    constraints = Vector{AbstractGrammarConstraint}()

    r_right = 1
    r_down = 2
    r_left = 3
    r_up = 4
    r_drop = 5
    r_grab = 6

    # must drop and grab at least once
    push!(constraints, Unique(r_drop))
    push!(constraints, Unique(r_grab))

    # robot must take the shortest path, unless there are intermediate checkpoints (grabbing or dropping)
    push!(constraints, ForbiddenSequence([r_left, r_right], ignore_if = [r_drop, r_grab]))
    push!(constraints, ForbiddenSequence([r_right, r_left], ignore_if = [r_drop, r_grab]))
    push!(constraints, ForbiddenSequence([r_up, r_down], ignore_if = [r_drop, r_grab]))
    push!(constraints, ForbiddenSequence([r_down, r_up], ignore_if = [r_drop, r_grab]))

    # robot must go horizontal, before going vertical between checkpoints (r_grab and r_drop)
    push!(constraints, ForbiddenSequence([r_down, r_right], ignore_if = [r_drop, r_grab]))
    push!(constraints, ForbiddenSequence([r_down, r_left], ignore_if = [r_drop, r_grab]))
    push!(constraints, ForbiddenSequence([r_up, r_right], ignore_if = [r_drop, r_grab]))
    push!(constraints, ForbiddenSequence([r_up, r_left], ignore_if = [r_drop, r_grab]))
    return grammar, constraints
end

function get_grammar_arithmetic()
    grammar = @csgrammar begin
        Int = Int + Int
        Int = Int * Int
        Int = Int - Int
        Int = 0
        Int = |(1:9)
        Int = x
    end
    clearconstraints!(grammar)
    constraints = Vector{AbstractGrammarConstraint}()
    
    plus = 1
    times = 2
    minus = 3
    zero = 4
    one = 5
    two = 6
    three = 7
    
    push!(constraints, Forbidden(RuleNode(times, [VarNode(:a), RuleNode(zero)])))
    push!(constraints, Forbidden(RuleNode(minus, [VarNode(:a), VarNode(:a)])))
    push!(constraints, Forbidden(RuleNode(minus, [VarNode(:a), RuleNode(zero)])))
    push!(constraints, Forbidden(RuleNode(plus, [VarNode(:a), RuleNode(zero)])))
    push!(constraints, Forbidden(RuleNode(times, [VarNode(:a), RuleNode(one)])))
    push!(constraints, Forbidden(RuleNode(minus, [
        RuleNode(times, [VarNode(:a), RuleNode(two)])
        VarNode(:a)
    ])))
    push!(constraints, Forbidden(RuleNode(plus, [VarNode(:a), VarNode(:a)])))
    push!(constraints, Forbidden(RuleNode(minus, [
        RuleNode(times, [VarNode(:a), RuleNode(three)])
        VarNode(:a)
    ])))
    push!(constraints, Forbidden(RuleNode(plus, [RuleNode(zero), VarNode(:a)])))
    push!(constraints, Forbidden(RuleNode(times, [RuleNode(zero), VarNode(:a)])))
    push!(constraints, Forbidden(RuleNode(times, [RuleNode(one), VarNode(:a)])))
    
    push!(constraints, Ordered(RuleNode(plus, [VarNode(:a), VarNode(:b)]), [:a, :b]))
    push!(constraints, Ordered(RuleNode(times, [VarNode(:a), VarNode(:b)]), [:a, :b]))
    return grammar, constraints
end

function get_grammar_symbolic()
    grammar = @csgrammar begin
        S = t1 #terminals
        S = t2
        S = t3
        S = u1(S) #unary functions
        S = u2(S)
        S = u3(S)
        S = b1(S, S) #binary functions
        S = b2(S, S)
        S = b3(S, S)
        S = unique
    end
    clearconstraints!(grammar)
    constraints = Vector{AbstractGrammarConstraint}()

    _t1,_t2,_t3,_u1,_u2,_u3,_b1,_b2,_b3,_unique = 1,2,3,4,5,6,7,8,9,10

    a = VarNode(:a)
    b = VarNode(:b)
    c = VarNode(:c)

    t1 = RuleNode(_t1)
    t2 = RuleNode(_t2)
    t3 = RuleNode(_t3)

    u1(c1::AbstractRuleNode) = RuleNode(_u1, [c1])
    u2(c1::AbstractRuleNode) = RuleNode(_u2, [c1])
    u3(c1::AbstractRuleNode) = RuleNode(_u3, [c1])

    b1(c1::AbstractRuleNode, c2::AbstractRuleNode) = RuleNode(_b1, [c1, c2])
    b2(c1::AbstractRuleNode, c2::AbstractRuleNode) = RuleNode(_b2, [c1, c2])
    b3(c1::AbstractRuleNode, c2::AbstractRuleNode) = RuleNode(_b3, [c1, c2])

    unique = RuleNode(10)

    constraints = Vector{AbstractGrammarConstraint}()

    # contains constraints
    push!(constraints, Contains(_t1))
    push!(constraints, Contains(_t2))
    push!(constraints, Contains(_t3))

    # contains subtree constraints
    push!(constraints, ContainsSubtree(b3(unique, a)))
    push!(constraints, ContainsSubtree(b3(a, u1(a))))
    push!(constraints, ContainsSubtree(b2(a, u1(b))))
    push!(constraints, ContainsSubtree(b1(u2(b), a)))

    # unique constraint
    push!(constraints, Unique(_unique))

    # forbidden sequence constraints
    push!(constraints, ForbiddenSequence([_b1, _b2, _t2]))
    push!(constraints, ForbiddenSequence([_b1, _b3, _t2]))
    push!(constraints, ForbiddenSequence([_u1, _t1]))
    push!(constraints, ForbiddenSequence([_u2, _t1]))
    push!(constraints, ForbiddenSequence([_u3, _t3]))

    # forbidden constraints
    push!(constraints, Forbidden(b1(a, a)))
    push!(constraints, Forbidden(b2(a, a)))
    push!(constraints, Forbidden(b2(a, b1(b, b))))
    push!(constraints, Forbidden(b2(u1(a), b)))
    push!(constraints, Forbidden(u1(u2(u3(a)))))

    # ordered constraints
    push!(constraints, Ordered(b1(a, b), [:a, :b]))
    push!(constraints, Ordered(b1(b1(a, b), u1(c)), [:a, :b, :c]))
    push!(constraints, Ordered(b1(u1(c), b1(a, b)), [:a, :b, :c]))

    return grammar, constraints
end

function get_grammar_lists()
    grammar = @csgrammar begin
        List = []
        List = push!(List, Int)
        List = reverse!(List)
        List = sort!(List)
        List = append!(List, List)
        Int = maximum(List)
        Int = minimum(List)
        Int = sum(List)
        Int = prod(List)
        Int = |(1:3)
        Int = x
        Int = y
    end
    clearconstraints!(grammar)

    #Lists
    _empty,_push,_reverse,_sort,_append = 1,2,3,4,5

    #Integers
    _max,_min,_sum,_prod = 6,7,8,9
    _one,_two,_three,_arg_1,_arg_2 = 10,11,12,13,14

    empty = RuleNode(_empty)
    one = RuleNode(_one) 
    push(node1::AbstractRuleNode, node2::AbstractRuleNode) = RuleNode(2, [node1, node2])
    reverse(node::AbstractRuleNode) = RuleNode(3, [node])
    sort(node::AbstractRuleNode) = RuleNode(4, [node])
    append(node1::AbstractRuleNode, node2::AbstractRuleNode) = RuleNode(5, [node1, node2])

    A = VarNode(:a)
    B = VarNode(:b)
    C = VarNode(:c)
    Constant = DomainRuleNode(grammar, [_one, _two, _three])
    V = VarNode(:v)

    constraints = Vector{AbstractGrammarConstraint}()

    # Jaap
    push!(constraints, Forbidden(reverse(reverse(A))))
    push!(constraints, Forbidden(sort(reverse(A))))
    push!(constraints, Forbidden(sort(sort(A))))
    push!(constraints, Forbidden(sort(append(A, reverse(B)))))
    push!(constraints, Forbidden(sort(append(A, sort(B)))))
    push!(constraints, Forbidden(sort(push(sort(A), V))))

    # Extra
    unaryfunction(node::AbstractRuleNode) = DomainRuleNode(grammar, [_reverse, _sort, _max, _min, _sum, _prod], [node])
    push!(constraints, Forbidden(unaryfunction(empty)))
    push!(constraints, Forbidden(unaryfunction(push(empty, V))))

    push!(constraints, ForbiddenSequence([_reverse, _empty], ignore_if=[_sort, _append]))
    push!(constraints, ForbiddenSequence([_append, _empty], ignore_if=[_reverse, _sort]))

    return grammar, constraints
end

function get_grammar_lists_grounded()
    grammar = @csgrammar begin
        List = []
        List = push!(List, Int)
        List = reverse!(List)
        List = sort!(List)
        List = append!(List, List)
        Int = maximum(List)
        Int = minimum(List)
        Int = sum(List)
        Int = prod(List)
        Int = |(1:3)
        Int = x
        Int = y
    end
    clearconstraints!(grammar)

    #Lists
    _empty,_push,_reverse,_sort,_append = 1,2,3,4,5

    #Integers
    _max,_min,_sum,_prod = 6,7,8,9
    _one,_two,_three,_arg_1,_arg_2 = 10,11,12,13,14

    empty = RuleNode(_empty)
    one = RuleNode(_one) 
    push(node1::AbstractRuleNode, node2::AbstractRuleNode) = RuleNode(2, [node1, node2])
    reverse(node::AbstractRuleNode) = RuleNode(3, [node])
    sort(node::AbstractRuleNode) = RuleNode(4, [node])
    append(node1::AbstractRuleNode, node2::AbstractRuleNode) = RuleNode(5, [node1, node2])

    A = VarNode(:a)
    B = VarNode(:b)
    C = VarNode(:c)
    Constant = DomainRuleNode(grammar, [_one, _two, _three])
    V = VarNode(:v)

    constraints = Vector{AbstractGrammarConstraint}()

    # Jaap
    push!(constraints, Forbidden(reverse(reverse(A))))
    push!(constraints, Forbidden(sort(reverse(A))))
    push!(constraints, Forbidden(sort(sort(A))))
    push!(constraints, Forbidden(sort(append(A, reverse(B)))))
    push!(constraints, Forbidden(sort(append(A, sort(B)))))
    push!(constraints, Forbidden(sort(push(sort(A), V))))

    # Extra
    # unaryfunction(node::AbstractRuleNode) = DomainRuleNode(grammar, [_reverse, _sort, _max, _min, _sum, _prod], [node])
    # push!(constraints, Forbidden(unaryfunction(empty)))
    # push!(constraints, Forbidden(unaryfunction(push(empty, V))))

    push!(constraints, Forbidden(RuleNode(_reverse, [empty])))
    push!(constraints, Forbidden(RuleNode(_sort, [empty])))
    push!(constraints, Forbidden(RuleNode(_max, [empty])))
    push!(constraints, Forbidden(RuleNode(_min, [empty])))
    push!(constraints, Forbidden(RuleNode(_sum, [empty])))
    push!(constraints, Forbidden(RuleNode(_prod, [empty])))

    push!(constraints, Forbidden(RuleNode(_reverse, [push(empty, V)])))
    push!(constraints, Forbidden(RuleNode(_sort, [push(empty, V)])))
    push!(constraints, Forbidden(RuleNode(_max, [push(empty, V)])))
    push!(constraints, Forbidden(RuleNode(_min, [push(empty, V)])))
    push!(constraints, Forbidden(RuleNode(_sum, [push(empty, V)])))
    push!(constraints, Forbidden(RuleNode(_prod, [push(empty, V)])))

    push!(constraints, ForbiddenSequence([_reverse, _empty], ignore_if=[_sort, _append]))
    push!(constraints, ForbiddenSequence([_append, _empty], ignore_if=[_reverse, _sort]))

    return grammar, constraints
end