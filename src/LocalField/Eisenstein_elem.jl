###############################################################################
#
#   Type and parent object methods
#
###############################################################################

parent_type(::Type{eisf_elem}) = EisensteinField

@doc Markdown.doc"""
    parent(a::eisf_elem)
> Return the parent of the given number field element.
"""
parent(a::eisf_elem) = a.parent

elem_type(::Type{EisensteinField{T}}) where T = eisf_elem

@doc Markdown.doc"""
    base_ring(a::EisensteinField)
> Returns the base ring of `a`.
"""
base_ring(a::EisensteinField) = a.base_ring

@doc Markdown.doc"""
    base_field(a::EisensteinField)
> Returns the base ring of `a`.
"""
base_field(a::EisensteinField) = base_ring(a)

@doc Markdown.doc"""
    base_ring(a::eisf_elem)
> Returns the base ring of the parent of `a`.
"""
base_ring(a::eisf_elem) = a.base_ring

@doc Markdown.doc"""
    base_field(a::eisf_elem)
> Returns the base ring of the parent of `a`.
"""
base_field(a::eisf_elem) = base_ring(a)

isdomain_type(::Type{eisf_elem}) = true

isexact_type(::Type{eisf_elem}) = false

@doc Markdown.doc"""
    var(a::EisensteinField)
> Returns the identifier (as a symbol, not a string), that is used for printing
> the generator of the given number field.
"""
var(a::EisensteinField) = a.S

function check_parent(a::eisf_elem, b::eisf_elem)
   a.parent != b.parent && error("Incompatible EisensteinField elements")
end


###############################################################################
#
#   Basic manipulation
#
###############################################################################


function hash(a::eisf_elem, h::UInt)
    error("Not Implemented")
    return
end

function deepcopy(a::eisf_elem)
    r = parent(a)()
    r.data_ring_elt = deepcopy(a.data_ring_elt)
    return r
end

@doc Markdown.doc"""
    gen(a::EisensteinField)
> Return the generator of the given EisensteinField.
"""
function gen(a::EisensteinField)
    r = eisf_elem(a)
    r.data_ring_elt = gen(a.data_ring)
   return r
end



@doc Markdown.doc"""
    one(a::EisensteinField)
> Return the multiplicative identity, i.e. one, in the given number field.
"""
function one(a::EisensteinField)
    return a(1)
end

@doc Markdown.doc"""
    zero(a::EisensteinField)
> Return the multiplicative identity, i.e. one, in the given number field.
"""
function zero(a::EisensteinField)
    return a(0)
end

#TODO: THIS IS VERY WRONG. The fix should occur in AbstractAlgebra.
#TODO: Make this more efficient.
function zero!(a::eisf_elem)
    a.data_ring_elt = zero(parent(a)).data_ring_elt
    a
end


# @doc Markdown.doc"""
#     isgen(a::eisf_elem)
# > Return `true` if the given number field element is the generator of the
# > number field, otherwise return `false`.
# """
# function isgen(a::eisf_elem)
#    return ccall((:eisf_elem_is_gen, :libantic), Bool,
#                 (Ref{eisf_elem}, Ref{EisensteinField}), a, a.parent)
# end

@doc Markdown.doc"""
    isone(a::eisf_elem)
> Return `true` if the given number field element is the multiplicative
> identity of the number field, i.e. one, otherwise return `false`.
"""
function isone(a::eisf_elem)
   return a == parent(a)(1)
end

@doc Markdown.doc"""
    iszero(a::eisf_elem)
> Return `true` if the given number field element is the additive
> identity of the number field, i.e. zero, otherwise return `false`.
"""
function iszero(a::eisf_elem)
   return a == parent(a)(0)
end

@doc Markdown.doc"""
    isunit(a::eisf_elem)
> Return `true` if the given number field element is invertible, i.e. nonzero,
> otherwise return `false`.
"""
isunit(a::eisf_elem) = !iszero(a)


#######################################################
if false

@doc Markdown.doc"""
    coeff(x::eisf_elem, n::Int)
> Return the $n$-th coefficient of the polynomial representation of the given
> number field element. Coefficients are numbered from $0$, starting with the
> constant coefficient.
"""
function coeff(x::eisf_elem, n::Int)
   n < 0 && throw(DomainError("Index must be non-negative: $n"))
   z = fmpq()
   ccall((:eisf_elem_get_coeff_fmpq, :libantic), Nothing,
     (Ref{fmpq}, Ref{eisf_elem}, Int, Ref{EisensteinField}), z, x, n, parent(x))
   return z
end

function num_coeff!(z::fmpz, x::eisf_elem, n::Int)
   n < 0 && throw(DomainError("Index must be non-negative: $n"))
   ccall((:eisf_elem_get_coeff_fmpz, :libantic), Nothing,
     (Ref{fmpz}, Ref{eisf_elem}, Int, Ref{EisensteinField}), z, x, n, parent(x))
   return z
end

@doc Markdown.doc"""
    denominator(a::eisf_elem)
> Return the denominator of the polynomial representation of the given number
> field element.
"""
function denominator(a::eisf_elem)
   z = fmpz()
   ccall((:eisf_elem_get_den, :libantic), Nothing,
         (Ref{fmpz}, Ref{eisf_elem}, Ref{EisensteinField}),
         z, a, a.parent)
   return z
end

function elem_from_mat_row(a::EisensteinField, b::fmpz_mat, i::Int, d::fmpz)
   Generic._checkbounds(nrows(b), i) || throw(BoundsError())
   ncols(b) == degree(a) || error("Wrong number of columns")
   z = a()
   ccall((:eisf_elem_set_fmpz_mat_row, :libantic), Nothing,
        (Ref{eisf_elem}, Ref{fmpz_mat}, Int, Ref{fmpz}, Ref{EisensteinField}),
        z, b, i - 1, d, a)
   return z
end

function elem_to_mat_row!(a::fmpz_mat, i::Int, d::fmpz, b::eisf_elem)
   ccall((:eisf_elem_get_fmpz_mat_row, :libantic), Nothing,
         (Ref{fmpz_mat}, Int, Ref{fmpz}, Ref{eisf_elem}, Ref{EisensteinField}),
         a, i - 1, d, b, b.parent)
   nothing
 end


function deepcopy_internal(d::eisf_elem, dict::IdDict)
   z = eisf_elem(parent(d), d)
   return z
end

end #if

# TODO: Decide whether this is a "relative" or absolute method.
@doc Markdown.doc"""
    degree(a::EisensteinField)
> Return the degree of the given Eisenstein field over it's base. i.e. the degree of its
> defining polynomial.
"""
degree(a::EisensteinField) = degree(a.pol)


@doc Markdown.doc"""
    absolute_degree(a::NALocalField)
> Return the absolute degree of the given Eisenstein field over the ground padic field.
"""
absolute_degree(a::PadicField) = 1
absolute_degree(a::QadicField) = degree(a)

function absolute_degree(a::NALocalField)
    return degree(a)*absolute_degree(base_ring(a))
end
    
# By our definition, the generator of a field of eisenstein type is the uniformizer.
uniformizer(a::EisensteinField) = gen(a)


###############################################################################
#
#   AbstractString I/O
#
###############################################################################

function show(io::IO, a::EisensteinField{T}) where T
   print(io, "Eisenstein extension over local field of type $T")
   print(io, " with defining polynomial ", a.pol)
end

function show(io::IO, x::eisf_elem)
   print(io, x.data_ring_elt)
end

needs_parentheses(::eisf_elem) = true

displayed_with_minus_in_front(::eisf_elem) = false

show_minus_one(::Type{eisf_elem}) = true

canonical_unit(x::eisf_elem) = x

###############################################################################
#
#   Unary operators
#
###############################################################################

function -(a::eisf_elem)
    b = a.parent(a)
    b.data_ring_elt = -a.data_ring_elt
    return b
end

function valuation(a::eisf_elem)
    coeffs = coefficients(a)

    min = valuation(coeffs[0])
    for i = 1:length(coeffs)-1
        newv = valuation(coeffs[i]) + (i)//absolute_degree(parent(a))
        if newv < min
            min = newv
        end
    end
    return min
end

#TODO: Replace `inv` with a Hensel lifting version.
inv(a::eisf_elem) = one(parent(a))//a

################################################################################
#
#  Lifting and residue fields
#
################################################################################


function lift(x::FinFieldElem, K::EisensteinField)
    return K(lift(x, base_ring(K)))
end


# function residue_image(a::padic)
#     Fp = ResidueRing(FlintZZ,parent(a).p)
#     return Fp(lift(a))
# end

# function residue_image(a::qadic)
#     display("WARNING!!!! Lazy testing code, assumes that the residue field is given "*
#             "by a Conway polynomial.")

#     Qq = parent(a)
#     R,x = PolynomialRing(FlintZZ,"x")

#     Fp = FlintFiniteField(prime(Qq))
#     Fq = FlintFiniteField(prime(Qq), degree(Qq), "b")[1]
#     return Fq(change_base_ring(lift(R,a),Fp))
# end

coefficients(a::eisf_elem) = coefficients(a.data_ring_elt.data)

coeff(a::eisf_elem,i::Int) = coeff(a.data_ring_elt.data, i)

function setcoeff!(a::eisf_elem, i::Int64, c::NALocalFieldElem)
    setcoeff!(a.data_ring_elt.data, i, c)
end

function ResidueField(K::EisensteinField)
    k, mp_struct = ResidueField(base_ring(K))

    # Unpack the map structure to get the maps to/from the residue field.
    base_res  = mp_struct.f
    base_lift = mp_struct.g

    T = elem_type(k)
    
    _residue = function(x::eisf_elem)
        v = valuation(x)
        v < 0 && error("element $x is not integral.")
        return base_res(coeff(x,0))
    end

    #TODO: See if the residue field elem type can be declared dynamically.
    function _lift(x)
        return K(base_lift(x))
    end
    
    return k, MapFromFunc(_residue, _lift, K, k)
end


# function residue_image(a::eisf_elem)
#     coeffs = coefficients(a.data_ring_elt.data)
    
#     for i = 0:length(coeffs)-1
#         newv = valuation(coeffs[i]) + (i)//degree(a.parent.pol)
#         if newv < 0
#             error("Valuation of input is negative.")
#         end
#     end
#     return residue_image(coeffs[0])
# end


###############################################################################
#
#   Binary operators
#
###############################################################################

function +(a::eisf_elem, b::eisf_elem)
    check_parent(a, b)
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt + b.data_ring_elt
    return r
end

function -(a::eisf_elem, b::eisf_elem)
    check_parent(a, b)
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt - b.data_ring_elt
    return r
end

function *(a::eisf_elem, b::eisf_elem)
    check_parent(a, b)
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt * b.data_ring_elt
    return r
end

function /(a::eisf_elem, b::eisf_elem)
    check_parent(a, b)
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt // b.data_ring_elt
    return r
end

divexact(a::eisf_elem, b::eisf_elem) = a/b

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

function +(a::eisf_elem, b::Union{Int,fmpz,fmpq,FlintLocalFieldElem})
   r = a.parent()
   r.data_ring_elt = a.data_ring_elt + b
   return r
end

function -(a::eisf_elem, b::Union{Int,fmpz,fmpq,FlintLocalFieldElem})
   r = a.parent()
   r.data_ring_elt = a.data_ring_elt - b
   return r
end

function -(a::Union{Int,fmpz,fmpq,FlintLocalFieldElem}, b::eisf_elem)
   r = b.parent()
   r.data_ring_elt = a - b.data_ring_elt
   return r
end

+(a::eisf_elem, b::Integer) = a + fmpz(b)

-(a::eisf_elem, b::Integer) = a - fmpz(b)

-(a::Integer, b::eisf_elem) = fmpz(a) - b

+(a::Integer, b::eisf_elem) = b + a

+(a::fmpq, b::eisf_elem) = b + a

+(a::Rational, b::eisf_elem) = fmpq(a) + b

+(a::eisf_elem, b::Rational) = b + a

-(a::Rational, b::eisf_elem) = fmpq(a) - b

-(a::eisf_elem, b::Rational) = a - fmpq(b)

function *(a::eisf_elem, b::Union{Int,fmpz,fmpq,FlintLocalFieldElem})
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt*b
    return r
end

function *(a::Rational, b::eisf_elem)
  return fmpq(a) * b
end

*(a::eisf_elem, b::Rational) = b * a

*(a::eisf_elem, b::Integer) = a * fmpz(b)

*(a::Integer, b::eisf_elem) = b * a

*(a::fmpz, b::eisf_elem) = b * a

*(a::fmpq, b::eisf_elem) = b * a


function /(a::eisf_elem, b::Union{Int,fmpz,fmpq,FlintLocalFieldElem})
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt/b
    return r
end

//(a::eisf_elem, b::Int) = a / parent(a)(b)

//(a::eisf_elem, b::fmpz) = a / parent(a)(b)

//(a::eisf_elem, b::Integer) = a // parent(a)(fmpz(b))

//(a::eisf_elem, b::fmpq) = a / parent(a)(b)

//(a::Integer, b::eisf_elem) = parent(b)(a) / b

//(a::fmpz, b::eisf_elem) = parent(b)(a) / b

//(a::fmpq, b::eisf_elem) = parent(b)(a) / b

//(a::Rational, b::eisf_elem) = parent(b)(fmpq(a)) / b

//(a::eisf_elem, b::Rational) = a / parent(a)(fmpq(b))

###############################################################################
#
#   Powering
#
###############################################################################

function ^(a::eisf_elem, n::Int)
    r = a.parent()
    r.data_ring_elt = a.data_ring_elt^n
   return r
end

###############################################################################
#
#   Comparison
#
###############################################################################

function ==(a::eisf_elem, b::eisf_elem)
    check_parent(a, b)
    return a.data_ring_elt == b.data_ring_elt
end

################################################################################
#
#  Unsafe operations
#
################################################################################

@inline function add!(z::eisf_elem, x::eisf_elem, y::eisf_elem)
  add!(z.data_ring_elt, x.data_ring_elt, y.data_ring_elt)
  return z
end

@inline function sub!(z::eisf_elem, x::eisf_elem, y::eisf_elem)
  sub!(z.data_ring_elt, x.data_ring_elt, y.data_ring_elt)
  return z
end

@inline function mul!(z::eisf_elem, x::eisf_elem, y::eisf_elem)
  mul!(z.data_ring_elt, x.data_ring_elt, y.data_ring_elt)
  return z
end

function addeq!(z::eisf_elem, x::eisf_elem)
  addeq!(z.data_ring_elt, x.data_ring_elt)
  return z
end


###############################################################################
#
#   Parent object call overloads
#
###############################################################################

@doc Markdown.doc"""
    (a::EisensteinField)()

> Return an empty (0) element.    
"""
function (a::EisensteinField)()
    z = eisf_elem(a)
    #u = z.u
    z.data_ring_elt = a.data_ring()
    return z
end

#TODO: Perhaps do some santiy checks as to not to drive the user insane.
#TODO: The number field case likely has a useful pattern here.
function (a::EisensteinField)(b::eisf_elem)
    parent(b) == a && return b

    if parent(b) == base_ring(a)
        r = eisf_elem(a)
        r.data_ring_elt = a.data_ring(b)
        return r
    end
    
    return a(base_ring(a)(b))
end

function (a::EisensteinField)(b::FlintLocalFieldElem)
    parent(b) != base_ring(a) && error("Cannot coerce element")
    r = eisf_elem(a)
    r.data_ring_elt = a.data_ring(b)
   return r
end

function (a::EisensteinField)(c::fmpz)
    z = eisf_elem(a)
    z.data_ring_elt = a.data_ring(c)
    return z
end

function (a::EisensteinField)(c::fmpq)
    z = eisf_elem(a)
    z.data_ring_elt = a.data_ring(c)
    return z
end

(a::EisensteinField)(c::Integer) = a(fmpz(c))

(a::EisensteinField)(c::Rational) = a(fmpq(c))

### Comment block.
if false

function (a::EisensteinField)(c::fmpq)
   z = eisf_elem(a)
   ccall((:eisf_elem_set_fmpq, :libantic), Nothing,
         (Ref{eisf_elem}, Ref{fmpq}, Ref{EisensteinField}), z, c, a)
   return z
end

# Debatable if we actually want this functionality...
function (a::EisensteinField)(pol::fmpq_poly)
   pol = parent(a.pol)(pol) # check pol has correct parent
   z = eisf_elem(a)
   if length(pol) >= length(a.pol)
      pol = mod(pol, a.pol)
   end
   ccall((:eisf_elem_set_fmpq_poly, :libantic), Nothing,
         (Ref{eisf_elem}, Ref{fmpq_poly}, Ref{EisensteinField}), z, pol, a)
   return z
end

function (a::FmpqPolyRing)(b::eisf_elem)
   parent(parent(b).pol) != a && error("Cannot coerce from field to polynomial ring")
   r = a()
   ccall((:eisf_elem_get_fmpq_poly, :libantic), Nothing,
         (Ref{fmpq_poly}, Ref{eisf_elem}, Ref{EisensteinField}), r, b, parent(b))
   return r
end

end #if
    
###############################################################################
#
#   Random generation
#
###############################################################################

if false
    
function rand(K::EisensteinField, r::UnitRange{Int64})
   R = parent(K.pol)
   n = degree(K.pol)
   return K(rand(R, (n-1):(n-1), r)) 
end

end #if
    
###############################################################################
#
#   EisensteinField constructor
#
###############################################################################

@doc Markdown.doc"""
    EisenteinField(f::fmpq_poly, s::AbstractString; cached::Bool = true, check::Bool = true)
> Return a tuple $R, x$ consisting of the parent object $R$ and generator $x$
> of the local field $\mathbb{Q}_p/(f)$ where $f$ is the supplied polynomial.
> The supplied string `s` specifies how the generator of the field extension
> should be printed.

> WARNING: Defaults are actually cached::Bool = false, check::Bool = false
"""
function EisensteinField(f::AbstractAlgebra.Generic.Poly{<:NALocalFieldElem}, s::AbstractString;
                         cached::Bool = false, check::Bool = true)
    S = Symbol(s)
    return EisensteinField(f, S, cached, check)
    #parent_obj = EisensteinField(f, S, cached, check)
   #return parent_obj, gen(parent_obj)
end
