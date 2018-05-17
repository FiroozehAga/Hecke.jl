################################################################################
#
#    NfOrd/Ideal/Ideal.jl : Ideals in orders of absolute number fields
#
# This file is part of Hecke.
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
#  Copyright (C) 2015, 2016, 2017 Tommy Hofmann
#  Copyright (C) 2015, 2016, 2017 Claus Fieker
#
################################################################################

export show, ideal

export IdealSet, valuation,prime_decomposition_type, prime_decomposition,
       prime_ideals_up_to, factor, divexact, isramified, anti_uniformizer,
       uniformizer, iscoprime, conductor, colon, equation_order

export NfOrdIdl

export deepcopy, parent, order, basis, basis_mat, basis_mat_inv, minimum, norm,
       ==, in, +, *, intersection, lcm, idempotents, mod, pradical

add_assert_scope(:Rres)
new = !true

function toggle()
  global new = !new
end

################################################################################
#
#  Deepcopy
#
################################################################################
# The valuation is an anonymous function which contains A in its environment.
# Thus deepcopying A.valuation will call deepcopy(A) and we run in an
# infinite recursion.
#
# We hack around it by don't deepcopying A.valuation.
# Note that B therefore contains a reference to A (A cannot be freed unless
# B is freed).
function Base.deepcopy_internal(A::NfAbsOrdIdl, dict::ObjectIdDict)
  B = typeof(A)(order(A))
  for i in fieldnames(A)
    if i == :parent
      continue
    end
    if isdefined(A, i)
      if i == :valuation
        setfield!(B, i, getfield(A, i))
      else
        setfield!(B, i, Base.deepcopy_internal(getfield(A, i), dict))
      end
    end
  end
  return B
end

################################################################################
#
#  Parent
#
################################################################################

parent(a::NfAbsOrdIdl) = a.parent

#################################################################################
#
#  Parent constructor
#
#################################################################################

function IdealSet(O::NfOrd)
   return NfAbsOrdIdlSet(O)
end

elem_type(::Type{NfOrdIdlSet}) = NfOrdIdl

elem_type(::NfOrdIdlSet) = NfOrdIdl

parent_type(::Type{NfOrdIdl}) = NfOrdIdlSet

################################################################################
#
#  Hashing
#
################################################################################

# a (bad) hash function
# - slow (due to basis)
# - unless basis is in HNF it si also non-unique
function Base.hash(A::NfAbsOrdIdl, h::UInt)
  return Base.hash(basis_mat(A, Val{false}), h)
end

################################################################################
#
#  String I/O
#
################################################################################

function show(io::IO, a::NfAbsOrdIdlSet)
  print(io, "Set of ideals of $(order(a))\n")
end

function show(io::IO, a::NfAbsOrdIdl)
  if ismaximal_known(order(a)) && ismaximal(order(a))
    return show_maximal(io, a)
  else
    return show_gen(io, a)
  end
end

function show_gen(io::IO, a::NfAbsOrdIdl)
  print(io, "Ideal of (")
  print(io, order(a), ")\n")
  print(io, "with basis matrix\n")
  print(io, basis_mat(a))
end

function show_maximal(io::IO, id::NfAbsOrdIdl)
  compact = get(io, :compact, false)
  if compact
    if has_2_elem(id)
      print(io, "<", id.gen_one, ", ", id.gen_two, ">" )
    else
      print(io, "<no 2-elts present>");
    end
  else
    if has_2_elem(id)
      print(io, "<", id.gen_one, ", ", id.gen_two, ">" )
    else
      print(io, "<no 2-elts present>");
    end

    if has_norm(id)
      print(io, "\nNorm: ", id.norm);
    end
    if has_minimum(id)
      print(io, "\nMinimum: ", id.minimum);
    end
    if isdefined(id, :princ_gen)
      print(io, "\nprincipal generator ", id.princ_gen)
    end
     if isdefined(id, :basis_mat)
       print(io, "\nbasis_mat \n", id.basis_mat)
     end
    if isdefined(id, :gens_normal)
      print(io, "\ntwo normal wrt: ", id.gens_normal)
    end
  end
end

################################################################################
#
#  Copy
#
################################################################################

function copy(i::NfAbsOrdIdl)
  return i
end

################################################################################
#
#  Parent object overloading and user friendly constructors
#
################################################################################

doc"""
***
    ideal(O::NfOrd, x::NfOrdElem) -> NfAbsOrdIdl

> Creates the principal ideal $(x)$ of $\mathcal O$.
"""
function ideal(O::NfOrd, x::NfOrdElem)
  return NfAbsOrdIdl(deepcopy(x))
end

doc"""
***
    ideal(O::NfOrd, x::fmpz_mat, check::Bool = false) -> NfAbsOrdIdl

> Creates the ideal of $\mathcal O$ with basis matrix $x$. If check is set, then it is
> checked whether $x$ defines an ideal (expensive).
"""
function ideal(O::NfOrd, x::fmpz_mat, check::Bool = false)
  x = _hnf(x, :lowerleft) #sub-optimal, but == relies on the basis being thus

  I = NfAbsOrdIdl(O, x)
  if check
    J = ideal(O, 0)
    for i=1:degree(O)
      e = O([x[i,j] for j=1:degree(O)])
      J += ideal(O, e)
    end
    
    @assert J == I
  end

  return I
end


doc"""
***
    ideal(O::NfOrd, x::fmpz, y::NfOrdElem) -> NfAbsOrdIdl

> Creates the ideal $(x,y)$ of $\mathcal O$.
"""
function ideal(O::NfOrd, x::fmpz, y::NfOrdElem)
  return NfAbsOrdIdl(deepcopy(x), deepcopy(y))
end

function ideal(O::NfOrd)
  return NfAbsOrdIdl(O)
end

function (S::NfAbsOrdIdlSet)()
   return NfAbsOrdIdl(order(S))
end

doc"""
***
    ideal(O::NfOrd, a::fmpz) -> NfAbsOrdIdl

> Returns the ideal of $\mathcal O$ which is generated by $a$.
"""
ideal(O::NfOrd, a::fmpz)  = NfAbsOrdIdl(O, deepcopy(a))

doc"""
***
    ideal(O::NfOrd, a::Int) -> NfAbsOrdIdl

> Returns the ideal of $\mathcal O$ which is generated by $a$.
"""
ideal(O::NfOrd, a::Int) = NfAbsOrdIdl(O, a)

################################################################################
#
#  Basic field access
#
################################################################################

doc"""
***
    order(x::NfAbsOrdIdl) -> NfOrd

> Returns the order, of which $x$ is an ideal.
"""
order(a::NfAbsOrdIdlSet) = a.order

doc"""
***
    nf(x::NfAbsOrdIdl) -> AnticNumberField

> Returns the number field, of which $x$ is an integral ideal.
"""
nf(x::NfAbsOrdIdl) = nf(order(x))


doc"""
***
    parent(I::NfAbsOrdIdl) -> NfOrd

> Returns the order of $I$.
"""
order(a::NfAbsOrdIdl) = order(parent(a))

################################################################################
#
#  Principal ideal creation
#
################################################################################

doc"""
    *(O::NfOrd, x::NfOrdElem) -> NfAbsOrdIdl
    *(x::NfOrdElem, O::NfOrd) -> NfAbsOrdIdl

> Returns the principal ideal $(x)$ of $\mathcal O$.
"""
function *(O::NfOrd, x::NfOrdElem)
  parent(x) != O && error("Order of element does not coincide with order")
  return ideal(O, x)
end

*(x::NfOrdElem, O::NfOrd) = O*x
*(x::Int, O::NfOrd) = ideal(O, x)
*(x::BigInt, O::NfOrd) = ideal(O, fmpz(x))
*(x::fmpz, O::NfOrd) = ideal(O, x)

###########################################################################################
#
#   Basis
#
###########################################################################################

doc"""
***
    has_basis(A::NfAbsOrdIdl) -> Bool

> Returns whether A has a basis already computed.
"""
@inline has_basis(A::NfAbsOrdIdl) = isdefined(A, :basis)

function assure_has_basis(A::NfAbsOrdIdl)
  if isdefined(A, :basis)
    return nothing
  else
    assure_has_basis_mat(A)
    O = order(A)
    M = A.basis_mat
    Ob = basis(O, Val{false})
    B = Vector{elem_type(O)}(degree(O))
    y = O()
    for i in 1:degree(O)
      z = O()
      for k in 1:degree(O)
        mul!(y, M[i, k], Ob[k])
        add!(z, z, y)
      end
      B[i] = z
    end
    A.basis = B
    return nothing
  end
end

doc"""
***
    basis(A::NfAbsOrdIdl) -> Array{NfOrdElem, 1}

> Returns the basis of A.
"""
@inline function basis{T}(A::NfAbsOrdIdl, copy::Type{Val{T}} = Val{true})
  assure_has_basis(A)
  if copy == Val{true}
    return deepcopy(A.basis)
  else
    return A.basis
  end
end

################################################################################
#
#  Basis matrix
#
################################################################################

doc"""
***
    has_basis_mat(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ knows its basis matrix.
"""
@inline has_basis_mat(A::NfAbsOrdIdl) = isdefined(A, :basis_mat)

doc"""
***
  basis_mat(A::NfAbsOrdIdl) -> fmpz_mat

> Returns the basis matrix of $A$.
"""
function basis_mat(A::NfAbsOrdIdl, copy::Type{Val{T}} = Val{true}) where T
  assure_has_basis_mat(A)
  if copy == Val{true}
    return deepcopy(A.basis_mat)
  else
    return A.basis_mat
  end
end

function assure_has_basis_mat(A::NfAbsOrdIdl)
  if isdefined(A, :basis_mat)
    return nothing
  end

  if !issimple(nf(order(A))) && isdefined(A, :is_prime) && A.is_prime == 1 && A.norm == A.minimum &&
     !isindex_divisor(order(A), A.minimum)
    # A is a prime ideal of degree 1
    A.basis_mat = basis_mat_prime_deg_1(A)
    return nothing
  end

  if has_princ_gen(A)
    m = representation_matrix(A.princ_gen)
    A.basis_mat = _hnf_modular_eldiv(m, minimum(A), :lowerleft)
    return nothing
  end

  @hassert :NfOrd 1 has_2_elem(A)
  K = nf(order(A))
  n = degree(K)
  c = _hnf_modular_eldiv(representation_matrix(A.gen_two), abs(A.gen_one), :lowerleft)
  A.basis_mat = c
  return nothing
end

function basis_mat_prime_deg_1(A::NfAbsOrdIdl)
  @assert A.is_prime == 1
  @assert A.minimum == A.norm
  O = order(A)
  n = degree(O)
  b = identity_matrix(FlintZZ, n)

  K, mK = ResidueField(O, A)
  assure_has_basis(O)
  bas = basis(O, Val{false})
  if isone(bas[1])
    b[1, 1] = A.minimum
  else
    b[1, 1] = fmpz(coeff(mK(-bas[1]), 0))
  end
  for i in 2:n
    b[i, 1] = fmpz(coeff(mK(-bas[i]), 0))
  end
  # b is Hermite normal form, but lower left
  return b
end

################################################################################
#
#  Basis matrix inverse
#
################################################################################

doc"""
***
    has_basis_mat_inv(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ knows its inverse basis matrix.
"""
@inline has_basis_mat_inv(A::NfAbsOrdIdl) = isdefined(A, :basis_mat_inv)

doc"""
***
  basis_mat_inv(A::NfAbsOrdIdl) -> fmpz_mat

> Returns the inverse basis matrix of $A$.
"""
function basis_mat_inv(A::NfAbsOrdIdl, copy::Type{Val{T}} = Val{true}) where T
  assure_has_basis_mat_inv(A)
  if copy == Val{true}
    return deepcopy(A.basis_mat_inv)
  else
    return A.basis_mat_inv
  end
end

doc"""
***
    basis_mat_inv(A::NfAbsOrdIdl) -> FakeFmpqMat

> Returns the inverse of the basis matrix of $A$.
"""
function assure_has_basis_mat_inv(A::NfAbsOrdIdl)
  if isdefined(A, :basis_mat_inv)
    return nothing
  else
    A.basis_mat_inv = FakeFmpqMat(pseudo_inv(basis_mat(A, Val{false})))
    return nothing
  end
end

################################################################################
#
#  Minimum
#
################################################################################

doc"""
***
    has_minimum(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ knows its mininum.
"""
function has_minimum(A::NfAbsOrdIdl)
  return isdefined(A, :minimum)
end

doc"""
***
    minimum(A::NfAbsOrdIdl) -> fmpz

> Returns the smallest nonnegative element in $A \cap \mathbf Z$.
"""
function minimum(A::NfAbsOrdIdl, copy::Type{Val{T}} = Val{true}) where T
  assure_has_minimum(A)
  if copy == Val{true}
    return deepcopy(A.minimum)
  else
    return A.minimum
  end
end

function assure_has_minimum(A::NfAbsOrdIdl)
  if has_minimum(A)
    return nothing
  end

  if has_princ_gen(A)
    b = A.princ_gen.elem_in_nf
    if iszero(b)
      A.minimum = fmpz(0)
      A.iszero = 1
    else
      if new && issimple(nf(order(A))) && order(A).ismaximal == 1
        A.minimum = _minmod(A.gen_one, A.gen_two)
        @hassert :Rres 1 A.minimum == denominator(inv(b), order(A))
      else
        bi = inv(b)
        A.minimum =  denominator(bi, order(A))
      end
    end
    return nothing
  end

  if has_weakly_normal(A)
    K = A.parent.order.nf
    if iszero(A.gen_two)
      # A = (A.gen_one, 0) = (A.gen_one)
      d = abs(A.gen_one)
    else
      if new && issimple(nf(order(A))) && order(A).ismaximal == 1
        d = _minmod(A.gen_one, A.gen_two)
        @hassert :Rres 1 d == gcd(A.gen_one, denominator(inv(A.gen_two.elem_in_nf), order(A)))
      else
        d = denominator(inv(K(A.gen_two)), order(A))
        d = gcd(d, FlintZZ(A.gen_one))
      end
    end
    A.minimum = d
    return nothing
  end

  @hassert :NfOrd 2 isone(basis(order(A), Val{false})[1])
  A.minimum = basis_mat(A, Val{false})[1, 1]
  return nothing
end

################################################################################
#
#  Norm
#
################################################################################

doc"""
***
    has_norm(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ knows its norm.
"""
function has_norm(A::NfAbsOrdIdl)
  return isdefined(A, :norm)
end

function assure_has_norm(A::NfAbsOrdIdl)
  if has_norm(A)
    return nothing
  end

  if has_princ_gen_special(A)
    A.norm = princ_gen_special(A)^degree(order(A))
    return nothing
  end

  if has_princ_gen(A)
    A.norm = abs(norm(A.princ_gen))
    return nothing
  end

  if has_2_elem(A) && A.gens_weakly_normal == 1
    if new 
      A.norm = _normmod(A.gen_one^degree(order(A)), A.gen_two)
      @hassert :Rres 1 A.norm == gcd(norm(order(A)(A.gen_one)), norm(A.gen_two))
    else  
      A.norm = gcd(norm(order(A)(A.gen_one)), norm(A.gen_two))
    end  
    return nothing
  end

  assure_has_basis_mat(A)
  A.norm = abs(det(basis_mat(A, Val{false})))
  return nothing
end

doc"""
***
    norm(A::NfAbsOrdIdl) -> fmpz

> Returns the norm of $A$, that is, the cardinality of $\mathcal O/A$, where
> $\mathcal O$ is the order of $A$.
"""
function norm(A::NfAbsOrdIdl, copy::Type{Val{T}} = Val{true}) where T
  assure_has_norm(A)
  if copy == Val{true}
    return deepcopy(A.norm)
  else
    return A.norm
  end
end

################################################################################
#
#  Principal generators
#
################################################################################

doc"""
***
    has_basis_princ_gen(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ knows if it is generated by one element.
"""
function has_princ_gen(A::NfAbsOrdIdl)
  return isdefined(A, :princ_gen)
end

doc"""
***
    has_basis_princ_gen_special(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ knows if it is generated by a rational integer.
"""
function has_princ_gen_special(A::NfAbsOrdIdl)
  return isdefined(A, :princ_gen_special)
end

princ_gen_special(A::NfAbsOrdIdl) = A.princ_gen_special[A.princ_gen_special[1] + 1]

################################################################################
#
#  Equality
#
################################################################################

doc"""
***
    ==(x::NfAbsOrdIdl, y::NfAbsOrdIdl)

> Returns whether $x$ and $y$ are equal.
"""
function ==(x::NfAbsOrdIdl, y::NfAbsOrdIdl)
  return basis_mat(x, Val{false}) == basis_mat(y, Val{false})
end

################################################################################
#
#  Inclusion of elements in ideals
#
################################################################################

doc"""
***
    in(x::NfOrdElem, y::NfAbsOrdIdl)
    in(x::nf_elem, y::NfAbsOrdIdl)
    in(x::fmpz, y::NfAbsOrdIdl)

> Returns whether $x$ is contained in $y$.
"""
function in(x::NfOrdElem, y::NfAbsOrdIdl)
  parent(x) != order(y) && error("Order of element and ideal must be equal")
  v = matrix(FlintZZ, 1, degree(parent(x)), elem_in_basis(x))
  t = FakeFmpqMat(v, fmpz(1))*basis_mat_inv(y, Val{false})
  return isone(t.den) 
end

function in(x::nf_elem, y::NfAbsOrdIdl)
  parent(x) != nf(order(y)) && error("Number field of element and ideal must be equal")
  return in(order(y)(x),y)
end

in(x::fmpz, y::NfAbsOrdIdl) = in(order(y)(x),y)
in(x::Integer, y::NfAbsOrdIdl) = in(order(y)(x),y)

###########################################################################################
#
#  Inverse
#
###########################################################################################

doc"""
***
    inv(A::NfAbsOrdIdl) -> NfOrdFracIdl

> Computes the inverse of A, that is, the fractional ideal $B$ such that
> $AB = \mathcal O_K$.
"""
function inv(A::NfAbsOrdIdl)
  if ismaximal_known(order(A)) && ismaximal(order(A))
    return inv_maximal(A)
  else
    error("Not implemented (yet)!")
  end
end

function inv_maximal(A::NfAbsOrdIdl)
  if has_2_elem(A) && has_weakly_normal(A)
    assure_2_normal(A)
    O = order(A)
    if iszero(A.gen_two)
      return ideal(O, 1)//A.gen_one
    end
    if new
      alpha = _invmod(A.gen_one, A.gen_two)
      _, d = ppio(denominator(alpha, O), A.gen_one)
    else  
      alpha = inv(elem_in_nf(A.gen_two))
      d = denominator(alpha, O)
      m = A.gen_one
      _, d = ppio(d, m)
    end  
    Ai = parent(A)()
    dn = denominator(d*alpha, O)
    Ai.gen_one = dn
    Ai.gen_two = O(d*alpha*dn, false)
    temp = dn^degree(A.parent.order)//norm(A)
    @hassert :NfOrd 1 denominator(temp) == 1
    Ai.norm = numerator(temp)
    Ai.gens_normal = A.gens_normal
    AAi = NfOrdFracIdl(Ai, dn)
    return AAi
  else
    # I don't know if this is a good idea
    _assure_weakly_normal_presentation(A)
    assure_2_normal(A)
    return inv(A)
  end
  error("Not implemented yet")
end

###########################################################################################
#
#  Simplification
#
###########################################################################################
#CF: missing a function to compute the gcd(...) for the minimum
#    without 1st computing the complete inv
# .../ enter rresx and rres!

function (A::Nemo.AnticNumberField)(a::Nemo.fmpz_poly)
  return A(FlintQQ["x"][1](a))
end

function _minmod(a::fmpz, b::NfOrdElem)
  if isone(a) 
    return a
  end
  Zk = parent(b)
  k = number_field(Zk)
  d = denominator(b.elem_in_nf)
  d, _ = ppio(d, a)
  e, _ = ppio(basis_mat(Zk, Val{false}).den, a) 

  S = ResidueRing(FlintZZ, a*d*e, cached=false)
  St = PolynomialRing(S, cached=false)[1]
  B = St(d*b.elem_in_nf)
  F = St(k.pol)
  m, u, v = rresx(B, F)  # u*B + v*F = m mod modulus(S)
  U = lift(FlintZZ["x"][1], u)
  # m can be zero...
  m = lift(m)
  if iszero(m)
    m = a*d*e
  end
  bi = k(U)//m*d # at this point, bi*d*b = m mod a*d*idx
  d = denominator(bi, Zk)
  return gcd(d, a)
  # min(<a, b>) = min(<ad, bd>)/d and bd is in the equation order, hence max as well
  # min(a, b) = gcd(a, denominator(b))
  # rres(b, f) = <b, f> meet Z = <r> and
  # ub + vf = r
  # so u/r is the inverse and r is the den in the field
  # we want gcd(r, a). so we use rres
  #at this point, min(<a, b*d>) SHOULD be 
end

function _invmod(a::fmpz, b::NfOrdElem)
  Zk = parent(b)
  k = number_field(Zk)
  if isone(a)
    return one(k)
  end
  d = denominator(b.elem_in_nf)
  d, _ = ppio(d, a)
  e, _ = ppio(basis_mat(Zk, Val{false}).den, a) 
  S = ResidueRing(FlintZZ, a^2*d*e, cached=false)
  St = PolynomialRing(S, cached=false)[1]
  B = St(d*b.elem_in_nf)
  F = St(k.pol)
  m, u, v = rresx(B, F)  # u*B + v*F = m mod modulus(S)
  if iszero(m)
    m = a^2*d*e
    c = S(1)
  else
    c = inv(canonical_unit(m))
    m = lift(m*c)
  end
  U = lift(FlintZZ["x"][1], u*c)
  bi = k(U)//m*d # at this point, bi*d*b = m mod a*d*idx
  return bi
end


function _normmod(a::fmpz, b::NfOrdElem)
  if isone(a)
    return a
  end
  Zk = parent(b)
  k = number_field(Zk)
  d = denominator(b.elem_in_nf)
  S = ResidueRing(FlintZZ, a*d^degree(parent(b)), cached=false)
  St = PolynomialRing(S, cached=false)[1]
  B = St(d*b.elem_in_nf)
  F = St(k.pol)
  m = resultant_sircana(B, F)  # u*B + v*F = m mod modulus(S)
  m = gcd(modulus(m), lift(m))
  return divexact(m, d^degree(parent(b)))
end


function simplify(A::NfAbsOrdIdl)
  if has_2_elem(A) && has_weakly_normal(A)
    #if maximum(element_to_sequence(A.gen_two)) > A.gen_one^2
    #  A.gen_two = element_reduce_mod(A.gen_two, A.parent.order, A.gen_one^2)
    #end
    if A.gen_one == 1 # || test other things to avoid the 1 ideal
      A.gen_two = order(A)(1)
      A.minimum = fmpz(1)
      A.norm = fmpz(1)
      return A
    end
    if new
      A.minimum = _minmod(A.gen_one, A.gen_two)
      @hassert :Rres 1 A.minimum == gcd(A.gen_one, denominator(inv(A.gen_two.elem_in_nf), A.parent.order))
    else  
      A.minimum = gcd(A.gen_one, denominator(inv(A.gen_two.elem_in_nf), A.parent.order))
    end  
    A.gen_one = A.minimum
    if false && new
      #norm seems to be cheap, while inv is expensive
      #TODO: improve the odds further: currently, the 2nd gen has small coeffs in the
      #      order basis. For this it would better be small in the field basis....
      n = _normmod(A.gen_one^degree(A.parent.order), A.gen_two)
      @hassert :Rres 1 n == gcd(A.gen_one^degree(A.parent.order), FlintZZ(norm(A.gen_two)))
    else  
      n = gcd(A.gen_one^degree(A.parent.order), FlintZZ(norm(A.gen_two)))
    end  
    if isdefined(A, :norm)
      @assert n == A.norm
    end
    A.norm = n
    A.gen_two = mod(A.gen_two, A.gen_one^2)
    return A
  end
  return A
end

################################################################################
#
#  Trace matrix
#
################################################################################

function trace_matrix(A::NfAbsOrdIdl)
  g = trace_matrix(order(A))
  b = basis_mat(A, Val{false})
#  mul!(b, b, g)   #b*g*b' is what we want.
#                  #g should not be changed? b is a copy.
#  mul!(b, b, b')  #TODO: find a spare tmp-mat and use transpose
  return b*g*b'
end

################################################################################
#
#  Power detection
#
################################################################################

doc"""
    ispower(I::NfAbsOrdIdl) -> Int, NfAbsOrdIdl
    ispower(a::NfOrdFracIdl) -> Int, NfOrdFracIdl
> Writes $a = r^e$ with $e$ maximal. Note: $1 = 1^0$.
"""
function ispower(I::NfAbsOrdIdl)
  m = minimum(I)
  if isone(m)
    return 0, I
  end
  d = discriminant(order(I))
  b, a = ppio(m, d) # hopefully: gcd(a, d) = 1 = gcd(a, b) and ab = m

  e, JJ = ispower_unram(gcd(I, a))

  if isone(e)
    return 1, I
  end

  g = e
  J = one(I)
  lp = factor(b)
  for p = keys(lp.fac)
    lP = prime_decomposition(order(I), Int(p))
    for i=1:length(lP)
      P = lP[i][1]
      v = valuation(I, P)
      gn = gcd(v, g)
      if gn == 1
        return gn, I
      end
      if g != gn
        J = J^div(g, gn)
      end
      if v != 0
        J *= P^div(v, gn)
      end
      g = gn
    end
  end
  return g, JJ^div(e, g)*J
end

function ispower_unram(I::NfAbsOrdIdl)
  m = minimum(I)
  if isone(m)
    return 0, I
  end

  e, ra = ispower(m)
  J = gcd(I, ra)

  II = J^e//I
  II = simplify(II)
  @assert isone(denominator(II))

  f, s = ispower_unram(numerator(II))

  g = gcd(f, e)
  if isone(g)
    return 1, I
  end

  II = inv(s)^div(f, g) * J^div(e, g)
  II = simplify(II)
  @assert isone(denominator(II))
  JJ = numerator(II)
  e = g

  return e, JJ
end

function ispower(I::NfOrdFracIdl)
  num, den = integral_split(I)
  e, r = ispower(num)
  if e == 1
    return e, I
  end
  f, s = ispower(den)
  g = gcd(e, f)
  return g, r^div(e, g)//s^div(f, g)
end

doc"""
    ispower(A::NfAbsOrdIdl, n::Int) -> Bool, NfAbsOrdIdl
    ispower(A::NfOrdFracIdl, n::Int) -> Bool, NfOrdFracIdl
> Computes, if possible, an ideal $B$ s.th. $B^n==A$ holds. In this
> case, {{{true}}} and $B$ are returned.
"""
function ispower(A::NfAbsOrdIdl, n::Int)
  m = minimum(A)
  if isone(m)
    return true, A
  end
  d = discriminant(order(A))
  b, a = ppio(m, d) # hopefully: gcd(a, d) = 1 = gcd(a, b) and ab = m

  fl, JJ = ispower_unram(gcd(A, a), n)
  A = gcd(A, b) # the ramified part

  if !fl
    return fl, A
  end

  J = one(A)
  lp = factor(b)
  for p = keys(lp.fac)
    lP = prime_decomposition(order(A), Int(p))
    for i=1:length(lP)
      P = lP[i][1]
      v = valuation(A, P)
      if v % n != 0
        return false, A
      end
      if v != 0
        J *= P^div(v, n)
      end
    end
  end
  return true, JJ*J
end

function ispower_unram(I::NfAbsOrdIdl, n::Int)
  m = minimum(I)
  if isone(m)
    return true, I
  end

  fl, ra = ispower(m, n)
  if !fl
    return fl, I
  end
  J = gcd(I, ra)

  II = J^n//I
  II = simplify(II)
  @assert isone(denominator(II))

  fl, s = ispower_unram(numerator(II), n)

  if !fl
    return fl, I
  end

  II = inv(s)* J
  II = simplify(II)
  @assert isone(denominator(II))
  JJ = numerator(II)

  return true, JJ
end

#TODO: check if the integral_plit is neccessary or if one can just use
#      the existing denominator
function ispower(A::NfOrdFracIdl, n::Int)
  nu, de = integral_split(A)
  fl, nu = ispower(nu, n)
  if !fl
    return fl, A
  end
  fl, de = ispower(de, n)
  return fl, nu//de
end

function one(A::NfAbsOrdIdl)
  return ideal(order(A), 1)
end

doc"""
***
    isone(A::NfAbsOrdIdl) -> Bool
    isunit(A::NfAbsOrdIdl) -> Bool

> Tests if $A$ is the trivial ideal generated by $1$.
"""
function isone(I::NfAbsOrdIdl)
  return isone(minimum(I))
end

function isunit(I::NfAbsOrdIdl)
  return isunit(minimum(I))
end

################################################################################
#
#  Reduction of element modulo ideal
#
################################################################################

doc"""
***
    mod(x::NfOrdElem, I::NfAbsOrdIdl)

> Returns the unique element $y$ of the ambient order of $x$ with
> $x \equiv y \bmod I$ and the following property: If
> $a_1,\dotsc,a_d \in \Z_{\geq 1}$ are the diagonal entries of the unique HNF
> basis matrix of $I$ and $(b_1,\dotsc,b_d)$ is the coefficient vector of $y$,
> then $0 \leq b_i < a_i$ for $1 \leq i \leq d$.
"""
function mod(x::NfOrdElem, y::NfAbsOrdIdl)
  parent(x) != order(y) && error("Orders of element and ideal must be equal")
  # this function assumes that HNF is lower left
  # !!! This must be changed as soon as HNF has a different shape

  O = order(y)
  a = elem_in_basis(x)
  #a = deepcopy(b)

  if isdefined(y, :princ_gen_special) && y.princ_gen_special[1] != 0
    for i in 1:length(a)
      a[i] = mod(a[i], y.princ_gen_special[1 + y.princ_gen_special[1]])
    end
    return O(a)
  end

  c = basis_mat(y, Val{false})
  t = fmpz(0)
  for i in degree(O):-1:1
    t = fdiv(a[i], c[i,i])
    for j in 1:i
      a[j] = a[j] - t*c[i,j]
    end
  end
  z = O(a)
  return z
end

function mod(x::NfOrdElem, y::NfAbsOrdIdl, preinv::Array{fmpz_preinvn_struct, 1})
  parent(x) != order(y) && error("Orders of element and ideal must be equal")
  # this function assumes that HNF is lower left
  # !!! This must be changed as soon as HNF has a different shape

  O = order(y)
  a = elem_in_basis(x) # this is already a copy

  if isdefined(y, :princ_gen_special) && y.princ_gen_special[1] != 0
    for i in 1:length(a)
      a[i] = mod(a[i], y.princ_gen_special[1 + y.princ_gen_special[1]])
    end
    return O(a)
  else
    return mod(x, basis_mat(y, Val{false}), preinv)
  end
end

function mod(x::NfOrdElem, c::Union{fmpz_mat, Array{fmpz, 2}}, preinv::Array{fmpz_preinvn_struct, 1})
  # this function assumes that HNF is lower left
  # !!! This must be changed as soon as HNF has a different shape

  O = parent(x)
  a = elem_in_basis(x) # this is already a copy

  q = fmpz()
  r = fmpz()
  for i in degree(O):-1:1
    fdiv_qr_with_preinvn!(q, r, a[i], c[i, i], preinv[i])
    for j in 1:i
      submul!(a[j], q, c[i, j])
    end
  end

  z = typeof(x)(O, a)
  return z
end

function mod!(x::NfOrdElem, c::Union{fmpz_mat, Array{fmpz, 2}}, preinv::Array{fmpz_preinvn_struct, 1})
  # this function assumes that HNF is lower left
  # !!! This must be changed as soon as HNF has a different shape

  O = parent(x)
  a = elem_in_basis(x, Val{false}) # this is already a copy

  q = fmpz()
  r = fmpz()
  for i in degree(O):-1:1
    if iszero(a[i])
      continue
    end
    fdiv_qr_with_preinvn!(q, r, a[i], c[i, i], preinv[i])
    for j in 1:i
      submul!(a[j], q, c[i, j])
    end
  end
  # We need to adjust the underlying nf_elem
  t = nf(O)()
  B = O.basis_nf
  zero!(x.elem_in_nf)
  for i in 1:degree(O)
    mul!(t, B[i], a[i])
    add!(x.elem_in_nf, x.elem_in_nf, t)
  end

  @hassert :NfOrd 2 x.elem_in_nf == dot(a, O.basis_nf)

  return x
end

function mod(x::NfOrdElem, Q::NfOrdQuoRing)
  O = parent(x)
  a = elem_in_basis(x) # this is already a copy

  y = ideal(Q)

  if isdefined(y, :princ_gen_special) && y.princ_gen_special[1] != 0
    for i in 1:length(a)
      a[i] = mod(a[i], y.princ_gen_special[1 + y.princ_gen_special[1]])
    end
    return O(a)
  end

  return mod(x, Q.basis_mat_array, Q.preinvn)
end

function mod!(x::NfOrdElem, Q::NfOrdQuoRing)
  O = parent(x)
  a = elem_in_basis(x, Val{false}) # this is already a copy

  y = ideal(Q)

  if isdefined(y, :princ_gen_special) && y.princ_gen_special[1] != 0
    for i in 1:length(a)
      a[i] = mod(a[i], y.princ_gen_special[1 + y.princ_gen_special[1]])
    end
    t = nf(O)()
    B = O.basis_nf
    zero!(x.elem_in_nf)
    for i in 1:degree(O)
      mul!(t, B[i], a[i])
      add!(x.elem_in_nf, x.elem_in_nf, t)
    end
    return x
  end

  return mod!(x, Q.basis_mat_array, Q.preinvn)
end

################################################################################
#
#  p-radical
#
################################################################################

# TH:
# There is some annoying type instability since we pass to nmod_mat or
# something else. Should use the trick with the function barrier.
doc"""
***
    pradical(O::NfOrd, p::fmpz) -> NfAbsOrdIdl

> Given a prime number $p$, this function returns the $p$-radical
> $\sqrt{p\mathcal O}$ of $\mathcal O$, which is
> just $\{ x \in \mathcal O \mid \exists k \in \mathbf Z_{\geq 0} \colon x^k
> \in p\mathcal O \}$. It is not checked that $p$ is prime.
"""
function pradical(O::NfAbsOrd, p::Union{Integer, fmpz})
  if typeof(p) == fmpz && nbits(p) < 64
    return pradical(O, Int(p))
  end
  
  #Trace method if the prime is large enough
  if p> degree(O)
    M = trace_matrix(O)
    W = MatrixSpace(ResidueRing(FlintZZ, p, cached=false), degree(O), degree(O))
    M1 = W(M)
    B,k = nullspace(M1)
    if k ==0
      return ideal(O, p)
    end
    M2=zero_matrix(FlintZZ, cols(B)+degree(O), degree(O))
    for i=1:cols(B)
      for j=1:degree(O)
        M2[i,j]=FlintZZ(B[j,i].data)
      end
    end
    for i=1:degree(O)
      M2[i+cols(B), i]=p
    end
    gens=[O(p)]
    for i=1:cols(B)
      if !iszero_row(M2,i)
        push!(gens, elem_from_mat_row(O, M2, i))
      end
    end
    M2=_hnf_modular_eldiv(M2, fmpz(p), :lowerleft)
    I=NfAbsOrdIdl(O, sub(M2, rows(M2)-degree(O)+1:rows(M2), 1:degree(O)))
    I.gens=gens
    return I
  end
  
  j = clog(fmpz(degree(O)), p)
  @assert p^(j-1) < degree(O)
  @assert degree(O) <= p^j

  R = ResidueRing(FlintZZ, p, cached=false)
  A = zero_matrix(R, degree(O), degree(O))
  B = basis(O)
  for i in 1:degree(O)
    t = powermod(B[i], p^j, p)
    ar = elem_in_basis(t)
    for k in 1:degree(O)
      A[i,k] = ar[k]
    end
  end
  X = kernel(A)
  gens=NfAbsOrdElem[O(p)]
  if length(X)==0
    I=ideal(O,p)
    I.gens=gens
    return I
  end
  #First, find the generators
  for i=1:length(X)
    coords=Array{fmpz,1}(degree(O))
    for j=1:degree(O)
      coords[j]=lift(X[i][j])
    end
    push!(gens, O(coords))
  end
  #Then, construct the basis matrix of the ideal
  m = zero_matrix(FlintZZ, degree(O)+length(X), degree(O))
  for i=1:length(X)
    for j=1:degree(O)
      m[i,j]=lift(X[i][j])
    end
  end
  for i=1:degree(O)
    m[i+length(X),i]=p
  end
  mm = _hnf_modular_eldiv(m, fmpz(p), :lowerleft)
  I = NfAbsOrdIdl(O, sub(mm, rows(m) - degree(O) + 1:rows(m), 1:degree(O)))
  I.gens = gens
  return I
end

################################################################################
#
#  Ring of multipliers, colon, conductor: it's the same(?) method
#
################################################################################

doc"""
***
    ring_of_multipliers(I::NfAbsOrdIdl) -> NfOrd

> Computes the order $(I : I)$, which is the set of all $x \in K$
> with $xI \subseteq I$.
"""
function ring_of_multipliers(a::NfAbsOrdIdl)
  
  O = order(a) 
  n = degree(O)
  if isdefined(a, :gens) && length(a.gens) < n
    B = a.gens
  else
    B = basis(a)
  end
  bmatinv = basis_mat_inv(a, Val{false})
  m = zero_matrix(FlintZZ, n*length(B), n)
  for i=1:length(B)
    M = representation_matrix(B[i])
    mul!(M, M, bmatinv.num)
    if bmatinv.den == 1
      for j=1:n
        for k=1:n
          m[j+(i-1)*n,k] = M[k,j]
        end
      end
    else
      for j=1:n
        for k=1:n
          m[j+(i-1)*n,k] = divexact(M[k,j], bmatinv.den)
        end
      end
    end
  end
  n = hnf_modular_eldiv!(m, minimum(a))
  s = prod(n[i,i] for i=1:degree(O))
  if s==1
    return deepcopy(O)
  end
  # n is upper right HNF
  n = transpose(sub(n, 1:degree(O), 1:degree(O)))
  b = FakeFmpqMat(pseudo_inv(n))
  mul!(b, b, basis_mat(O, Val{false}))
  @hassert :NfOrd 1 defines_order(nf(O), b)[1]
  O1 = Order(nf(O), b, false)
  if isdefined(O, :disc)
    O1.disc = divexact(O.disc, s^2)
  end
  return O1
end

doc"""
    colon(a::NfAbsOrdIdl, b::NfAbsOrdIdl) -> NfOrdFracIdl
> The ideal $(a:b) = \{x \in K | xb \subseteq a\} = \hom(b, a)$
> where $K$ is the number field.
"""
function colon(a::NfAbsOrdIdl, b::NfAbsOrdIdl, contains::Bool = false)
  
  O = order(a)
  n = degree(O)
  if isdefined(b, :gens)
    B = b.gens
  else
    B = basis(b)
  end

  bmatinv = basis_mat_inv(a, Val{false})

  if contains
    m = zero_matrix(FlintZZ, n*length(B), n)
    for i=1:length(B)
      M=representation_matrix(B[i])
      mul!(M, M, bmatinv.num)
      if bmatinv.den==1
        for j=1:n
          for k=1:n
            m[j+(i-1)*n,k]=M[k,j]
          end
        end
      else
        for j=1:n
          for k=1:n
            m[j+(i-1)*n,k]=divexact(M[k,j], bmatinv.den)
          end
        end
      end
    end
    m = hnf_modular_eldiv!(m, minimum(b))
    m = transpose(sub(m, 1:degree(O), 1:degree(O)))
    b, l = pseudo_inv(m)
    return NfAbsOrdIdl(O, b)//l
  else 
    n = FakeFmpqMat(representation_matrix(B[1]),FlintZZ(1))*bmatinv
    m = numerator(n)
    d = denominator(n)
    for i in 2:length(B)
      n = FakeFmpqMat(representation_matrix(B[i]),FlintZZ(1))*bmatinv
      l = lcm(denominator(n), d)
      if l==d
        m = hcat(m, n.num)
      else
        m = hcat(m*div(l, d), n.num*div(l, denominator(n)))
        d = l
      end
    end
    m = hnf(transpose(m))
    # n is upper right HNF
    m = transpose(sub(m, 1:degree(O), 1:degree(O)))
    b, l = pseudo_inv(m)
    return ideal(O, b)//l
  end
end

doc"""
    conductor(R::NfOrd, S::NfOrd) -> NfAbsOrdIdl
> The conductor $\{x \in S | xS\subseteq R\}$
> for orders $R\subseteq S$.
"""
function conductor(R::NfOrd, S::NfOrd)
  #=
     rS in R
     S = sum s_i ZZ, so this means
     r s_i in R for all i

     so need rep mat of s_i as elements(?) of R

     basis_mat: is from nf (equation order) -> ord
       ie. it comtains the basis elements of ord as elements of the field
     basis_mat_inv: the basis of the field as elements of the order

     so to get basis of S relative to R we need
       basis_mat(S)*basis_mat_inv(R)
  =#   
  bmS = basis_mat(S) * basis_mat_inv(R)

  n = FakeFmpqMat(representation_matrix(elem_from_mat_row(R, numerator(bmS), 1)), denominator(bmS))
  m = numerator(n)
  d = denominator(n)
  for i in 2:degree(R)
    n = FakeFmpqMat(representation_matrix(elem_from_mat_row(R, numerator(bmS), i)), denominator(bmS))
    l = lcm(denominator(n), d)
    if l==d
      m = hcat(m, numerator(n))
    else
      m = hcat(m*div(l, d), numerator(n)*div(l, denominator(n)))
      d = l
    end
  end
  m = hnf(transpose(m))
  # n is upper right HNF
  m = transpose(sub(m, 1:degree(R), 1:degree(R)))
  b, l = pseudo_inv(m)
  n = FakeFmpqMat(b*d, l)
  @assert denominator(n) == 1
  return ideal(R, numerator(n), true)
end

doc"""
    conductor(R::NfOrd) -> NfAbsOrdIdl
> The conductor of $R$ in the maximal order.
"""
conductor(R::NfOrd) = conductor(R, maximal_order(R))

#for consistency

maximal_order(R::NfOrd) = MaximalOrder(R)
equation_order(K::AnticNumberField) = EquationOrder(K)


################################################################################
#
#  Conversion to different order
#
################################################################################

doc"""
    ideal(O::NfOrd, I::NfAbsOrdIdl) -> NfOrdFracIdl
> The fractional ideal of $O$ generated by a Z-basis of $I$.
"""
function ideal(O::NfOrd, I::NfAbsOrdIdl)
  k = nf(O)
  bI = basis(I)
  J = ideal(O, k(bI[1]))
  for j=2:degree(O)
    J += ideal(O, k(bI[j]))
  end
  return J
end

################################################################################
#
#  Two element generated ideals
#
################################################################################

doc"""
***
    has_2_elem(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ is generated by two elements.
"""
function has_2_elem(A::NfAbsOrdIdl)
  return isdefined(A, :gen_two)
end

doc"""
***
    has_weakly_normal(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ has weakly normal two element generators.
"""
function has_weakly_normal(A::NfAbsOrdIdl)
  return (isdefined(A, :gens_weakly_normal) &&
        A.gens_weakly_normal == true) || has_2_elem_normal(A)
end

doc"""
***
    has_2_elem_normal(A::NfAbsOrdIdl) -> Bool

> Returns whether $A$ has normal two element generators.
"""
function has_2_elem_normal(A::NfAbsOrdIdl)
  #the one ideal <1, ?> is automatomatically normal>
  return isdefined(A, :gens_normal) && (A.gen_one == 1 || A.gens_normal > 1)
end

################################################################################
#
#  Predicates
#
################################################################################

# check if gen_one,gen_two is a P(gen_one)-normal presentation
# see Pohst-Zassenhaus p. 404
function defines_2_normal(A::NfAbsOrdIdl)
  m = A.gen_one
  gen = A.gen_two
  mg = denominator(inv(gen), order(A))
  # the minimum of ideal generated by g
  g = gcd(m,mg)
  return gcd(m, div(m,g)) == 1
end

###########################################################################################
#
#  2-element normal presentation
#
###########################################################################################

# The following makes sure that A has a weakly normal presentation
# Recall that (x,y) are a weakly normal presentation for A
# if and only if norm(A) = gcd(norm(x), norm(y))
#
# Maybe we should allow an optional paramter (an fmpz),
# which should be the first generator.
# So far, the algorithm just samples (lifts of) random elements of A/m^2,
# where m is the minimum of A.

function _assure_weakly_normal_presentation(A::NfAbsOrdIdl)
  if has_2_elem(A) && has_weakly_normal(A)
    return
  end

  if isdefined(A, :princ_gen)
    x = A.princ_gen
    b = x.elem_in_nf

    bi = inv(b)

    A.gen_one = denominator(bi, order(A))
    A.minimum = A.gen_one
    A.gen_two = x
    A.norm = abs(numerator(norm(b)))
    @hassert :NfOrd 1 gcd(A.gen_one^degree(order(A)),
                    FlintZZ(norm(A.gen_two))) == A.norm

    if A.gen_one == 1
      A.gens_normal = 2*A.gen_one
    else
      A.gens_normal = A.gen_one
    end
    A.gens_weakly_normal = 1
    return nothing
  end

  @hassert :NfOrd 1 has_basis_mat(A)

  O = order(A)

  # Because of the interesting choice for the HNF,
  # we don't know the minimum (although we have a basis matrix)
  # Thanks flint!

  minimum(A)

  @hassert :NfOrd 1 has_minimum(A)

  if minimum(A) == 0
    A.gen_one = minimum(A)
    A.gen_two = zero(O)
    A.gens_weakly_normal = 1
    return nothing
  end

  M = MatrixSpace(FlintZZ, 1, degree(O), false)

  Amin2 = minimum(A)^2
  Amind = minimum(A)^degree(O)

  B = Array{fmpz}(degree(O))

  gen = O()

  r = -Amin2:Amin2

  m = M()

  cnt = 0
  while true
    cnt += 1

    if cnt > 100 && is_2_normal_difficult(A)
      assure_2_normal_difficult(A)
      return
    end

    if cnt > 1000
      println("Having a hard time find weak generators for $A")
    end

    rand!(B, r)

    # Put the entries of B into the (1 x d)-Matrix m
    for i in 1:degree(O)
      s = ccall((:fmpz_mat_entry, :libflint), Ptr{fmpz}, (Ptr{fmpz_mat}, Int, Int), &m, 0, i - 1)
      ccall((:fmpz_set, :libflint), Void, (Ptr{fmpz}, Ptr{fmpz}), s, &B[i])
    end

    if iszero(m)
      continue
    end

    mul!(m, m, basis_mat(A, Val{false}))
    d = denominator(basis_mat(O, Val{false}))
    mul!(m, m, basis_mat(O, Val{false}).num)
    gen = elem_from_mat_row(nf(O), m, 1, d)
    # the following should be done inplace
    #gen = dot(reshape(Array(mm), degree(O)), basis(O))
    if norm(A) == gcd(Amind, numerator(norm(gen)))
      A.gen_one = minimum(A)
      A.gen_two = O(gen, false)
      A.gens_weakly_normal = 1
      return nothing
    end
  end
end

function is_2_normal_difficult(A::NfAbsOrdIdl)
  d = fmpz(2)
  m = minimum(A)
  ZK = order(A)

  if gcd(d, m) == 1 || degree(ZK) < 7
    return false
  end
  return true
end

function assure_2_normal_difficult(A::NfAbsOrdIdl)
  d = fmpz(2)
  m = minimum(A)
  ZK = order(A)

  if gcd(d, m) == 1 || degree(ZK) < 7
    assure_2_normal(A)
    return
  end

  m1, m2 = ppio(m, d)
  A1 = gcd(A, m1)
  A2 = gcd(A, m2)
  assure_2_normal(A2)

  lp = prime_decomposition(ZK, 2)
  v = [valuation(A1, p[1]) for p = lp]

  B1 = prod(lp[i][1]^v[i] for i=1:length(v) if v[i] > 0)
  C = B1 * A2
  A.gen_one = C.gen_one
  A.gen_two = C.gen_two
  A.gens_normal = C.gens_normal
  A.gens_weakly_normal = C.gens_weakly_normal
  A.gens_short = C.gens_short

  return
end

function assure_2_normal(A::NfAbsOrdIdl)
  if has_2_elem(A) && has_2_elem_normal(A)
    return
  end
  O = A.parent.order
  K = nf(O)
  n = degree(K)

  if norm(A) == 1
    A.gen_one = fmpz(1)
    A.gen_two = one(O)
    A.gens_normal = fmpz(1)
    return
  end

  if has_2_elem(A)
    m = minimum(A)
    bas = basis(O)
    # Magic constants
    if m > 1000
      r = -500:500
    else
      r = -div(Int(m)+1,2):div(Int(m)+1,2)
    end
    #gen = K()
    #s = K()
    gen = zero(O)
    s = O()
    cnt = 0
    while true
      cnt += 1
      if cnt > 100 && is_2_normal_difficult(A)
        assure_2_normal_difficult(A)
        return  
      end
      if cnt > 1000
        error("Having a hard time making generators normal for $A")
      end
      #Nemo.rand_into!(bas, r, s)
      rand!(s, O, r)
      #Nemo.mult_into!(s, A.gen_two, s)
      mul!(s, s, A.gen_two)
      #Nemo.add_into!(gen, rand(r)*A.gen_one, gen)
      add!(gen, rand(r)*A.gen_one, gen)
      #Nemo.add_into!(gen, s, gen)
      add!(gen, s, gen)
#      gen += rand(r)*A.gen_one + rand(bas, r)*A.gen_two
      #gen = element_reduce_mod(gen, O, m^2)
      gen = mod(gen, m^2)

      if iszero(gen)
        continue
      end

      mg = denominator(inv(elem_in_nf(gen)), O) # the minimum of <gen>
      g = gcd(m, mg)
      if gcd(m, div(mg, g)) == 1
        if gcd(m^n, norm(gen)) != norm(A)
          @vprint :NfOrd 2 "\n\noffending ideal $A \ngen is $gen\nWrong ideal\n"
          cnt += 10
          continue
        end
        break
      end
    end
    @vprint :NfOrd 2 "used $cnt attempts\n"
    A.gen_one = m
    A.gen_two = gen
    A.gens_normal = m
    return
  end
  error("not implemented yet...")
end

function random_init(I::AbstractArray{T, 1}; reduce::Bool = true, ub::fmpz=fmpz(0), lb::fmpz=fmpz(1)) where {T}

  R = RandIdlCtx()
  R.base = collect(I)
  O = order(R.base[1])
  R.ibase = map(inv, R.base)
  R.exp = zeros(Int, length(R.base))
  R.lb = lb
  R.ub = ub
  R.last = Set{Array{Int, 1}}()
  R.rand = ideal(O, 1)
  while norm(R.rand) <= lb
    i = rand(1:length(R.base))
    R.rand = simplify(R.rand * R.base[i])
    R.exp[i] += 1
  end
  push!(R.last, copy(R.exp))
  return R
end

function random_extend(R::RandIdlCtx, I::AbstractArray{NfAbsOrdIdl, 1})
  for i = I
    if i in R.base
      continue
    end
    push!(R.base, i)
    push!(R.ibase, inv(i))
  end
  z = zeros(Int, length(R.base) - length(R.exp))
  append!(R.exp, z)
  @assert length(R.exp) == length(R.base)
  for i = R.last
    append!(i, z)
  end
  nothing
end

function random_extend(R::RandIdlCtx, f::Float64)
  R.lb = ceil(fmpz, R.lb*f)
  R.ub = ceil(fmpz, R.lb*f)
  while norm(R.rand) < R.lb
    i = rand(1:length(R.base))
    R.rand = simplify(R.rand * R.base[i])
    R.exp[i] += 1
  end
  nothing
end

function random_extend(R::RandIdlCtx, f::fmpz)
  R.lb = R.lb*f
  R.ub = R.lb*f
  while norm(R.rand) < R.lb
    i = rand(1:length(R.base))
    R.rand = simplify(R.rand * R.base[i])
    R.exp[i] += 1
  end
  nothing
end


function random_get(R::RandIdlCtx; reduce::Bool = true, repeat::Int = 1)
  while repeat > 0
    repeat -= 1
    if norm(R.rand) >= R.ub
      delta = -1
    elseif norm(R.rand) <= R.lb
      delta = +1
    else
      delta = rand([-1,1])
    end
    i = 1
    while true
      if delta > 0
        i = rand(1:length(R.base))
      else
        i = rand(find(R.exp))
      end
      R.exp[i] += delta
      if true || !(R.exp in R.last)
        break
      end
      R.exp[i] -= delta
    end  
    if delta > 0
      R.rand = simplify(R.rand * R.base[i])
    else
      R.rand = simplify(R.rand * R.ibase[i]).num
    end
  #  @show R.exp, R.exp in R.last
  end
  push!(R.last, copy(R.exp))
  return R.rand
end



################################################################################
#
#  Conversion to Magma
#
################################################################################

function toMagma(f::IOStream, clg::NfOrdIdl, order::String = "M")
  print(f, "ideal<$(order)| ", clg.gen_one, ", ",
                    elem_in_nf(clg.gen_two), ">")
end

function toMagma(s::String, c::NfOrdIdl, order::String = "M")
  f = open(s, "w")
  toMagma(f, c, order)
  close(f)
end

###################################################################################
#
#  Coprimality between ideals
#
###################################################################################

doc"""
***
    iscoprime(I::NfAbsOrdIdl, J::NfAbsOrdIdl) -> Bool
> Test if ideals $I,J$ are coprime

"""

function iscoprime(I::NfAbsOrdIdl, J::NfAbsOrdIdl)
  
  @assert order(I)==order(J)
  
  if gcd(minimum(I), minimum(J))==1
    return true
  else 
    return isone(I+J)
  end

end 

one(I::NfAbsOrdIdlSet) = ideal(order(I), 1)

