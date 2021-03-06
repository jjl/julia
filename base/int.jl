# This file is a part of Julia. License is MIT: http://julialang.org/license

## integer arithmetic ##

# The tuples and types that do not include 128 bit sizes are necessary to handle certain
# issues on 32-bit machines, and also to simplify promotion rules, as they are also used
# elsewhere where Int128/UInt128 support is separated out, such as in hashing2.jl

const Signed64Types    = (Int8,Int16,Int32,Int64)
const Unsigned64Types  = (UInt8,UInt16,UInt32,UInt64)
const IntTypes         = tuple(Signed64Types..., Int128, Unsigned64Types..., UInt128)

typealias UnionIntTypes    Union{IntTypes...}
typealias UnionS64Types    Union{Signed64Types...}
typealias UnionU64Types    Union{Unsigned64Types...}
typealias Integer64        Union{Signed64Types..., Unsigned64Types...}
typealias SignedIntTypes   Union{Signed64Types..., Int128}
typealias UnsignedIntTypes Union{Unsigned64Types..., UInt128}

## integer comparisons ##

<{T<:SignedIntTypes}(x::T, y::T)  = slt_int(unbox(T,x),unbox(T,y))

-{T<:UnionIntTypes}(x::T)       = box(T, neg_int(unbox(T,x)))
-{T<:UnionIntTypes}(x::T, y::T) = box(T, sub_int(unbox(T,x),unbox(T,y)))
+{T<:UnionIntTypes}(x::T, y::T) = box(T, add_int(unbox(T,x),unbox(T,y)))
*{T<:UnionIntTypes}(x::T, y::T) = box(T, mul_int(unbox(T,x),unbox(T,y)))

/(x::Integer, y::Integer) = float(x)/float(y)
inv(x::Integer) = float(one(x))/float(x)

isodd(n::Integer) = rem(n,2) != 0
iseven(n::Integer) = !isodd(n)

signbit(x::Integer) = x < 0
signbit(x::Unsigned) = false

flipsign{T<:SignedIntTypes}(x::T, y::T) = box(T,flipsign_int(unbox(T,x),unbox(T,y)))

flipsign(x::Signed, y::Signed)  = convert(typeof(x), flipsign(promote(x,y)...))
flipsign(x::Signed, y::Float16) = flipsign(x, reinterpret(Int16,y))
flipsign(x::Signed, y::Float32) = flipsign(x, reinterpret(Int32,y))
flipsign(x::Signed, y::Float64) = flipsign(x, reinterpret(Int64,y))
flipsign(x::Signed, y::Real)    = flipsign(x, -oftype(x,signbit(y)))

copysign(x::Signed, y::Signed)  = flipsign(x, x$y)
copysign(x::Signed, y::Float16) = copysign(x, reinterpret(Int16,y))
copysign(x::Signed, y::Float32) = copysign(x, reinterpret(Int32,y))
copysign(x::Signed, y::Float64) = copysign(x, reinterpret(Int64,y))
copysign(x::Signed, y::Real)    = copysign(x, -oftype(x,signbit(y)))

"""
    abs(x)

The absolute value of `x`.

When `abs` is applied to signed integers, overflow may occur,
resulting in the return of a negative value. This overflow occurs only
when `abs` is applied to the minimum representable value of a signed
integer. That is, when `x == typemin(typeof(x))`, `abs(x) == x < 0`,
not `-x` as might be expected.
"""
function abs end

abs(x::Unsigned) = x
abs(x::Signed) = flipsign(x,x)

"""
    Base.checked_abs(x)

Calculates `abs(x)`, checking for overflow errors where applicable.
For example, standard two's complement signed integers (e.g. `Int`)
cannot represent `abs(typemin(Int))`, thus leading to an overflow.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_abs end

checked_abs(x::Unsigned) = abs(x)
function checked_abs{T<:SignedIntTypes}(x::T)
    x == typemin(T) && throw(OverflowError())
    abs(x)
end

"""
    Base.checked_neg(x)

Calculates `-x`, checking for overflow errors where applicable. For
example, standard two's complement signed integers (e.g. `Int`) cannot
represent `-typemin(Int)`, thus leading to an overflow.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_neg end

function checked_neg(x::Unsigned)
    x != 0 && throw(OverflowError())
    x
end
function checked_neg{T<:SignedIntTypes}(x::T)
    x == typemin(T) && throw(OverflowError())
    -x
end

~(n::Integer) = -n-1

unsigned(x::Signed) = reinterpret(typeof(convert(Unsigned,zero(x))), x)
unsigned(x::Bool) = convert(Unsigned, x)
unsigned(x) = convert(Unsigned, x)
signed(x::Unsigned) = reinterpret(typeof(convert(Signed,zero(x))), x)
signed(x) = convert(Signed, x)

div(x::Signed, y::Unsigned) = flipsign(signed(div(unsigned(abs(x)),y)),x)
div(x::Unsigned, y::Signed) = unsigned(flipsign(signed(div(x,unsigned(abs(y)))),y))

rem(x::Signed, y::Unsigned) = flipsign(signed(rem(unsigned(abs(x)),y)),x)
rem(x::Unsigned, y::Signed) = rem(x,unsigned(abs(y)))

fld(x::Signed, y::Unsigned) = div(x,y)-(signbit(x)&(rem(x,y)!=0))
fld(x::Unsigned, y::Signed) = div(x,y)-(signbit(y)&(rem(x,y)!=0))

mod(x::Signed, y::Unsigned) = rem(y+unsigned(rem(x,y)),y)
mod(x::Unsigned, y::Signed) = rem(y+signed(rem(x,y)),y)

cld(x::Signed, y::Unsigned) = div(x,y)+(!signbit(x)&(rem(x,y)!=0))
cld(x::Unsigned, y::Signed) = div(x,y)+(!signbit(y)&(rem(x,y)!=0))

# Don't promote integers for div/rem/mod since there is no danger of overflow,
# while there is a substantial performance penalty to 64-bit promotion.
div{T<:UnionS64Types}(x::T, y::T) = box(T,checked_sdiv(unbox(T,x),unbox(T,y)))
rem{T<:UnionS64Types}(x::T, y::T) = box(T,checked_srem(unbox(T,x),unbox(T,y)))
div{T<:UnionU64Types}(x::T, y::T) = box(T,checked_udiv(unbox(T,x),unbox(T,y)))
rem{T<:UnionU64Types}(x::T, y::T) = box(T,checked_urem(unbox(T,x),unbox(T,y)))

# x == fld(x,y)*y + mod(x,y)
mod{T<:Unsigned}(x::T, y::T) = rem(x,y)
function mod{T<:Integer}(x::T, y::T)
    y == -1 && return T(0)   # avoid potential overflow in fld
    x - fld(x,y)*y
 end

# fld(x,y) == div(x,y) - ((x>=0) != (y>=0) && rem(x,y) != 0 ? 1 : 0)
fld{T<:Unsigned}(x::T, y::T) = div(x,y)
function fld{T<:Integer}(x::T, y::T)
    d = div(x,y)
    d - (signbit(x$y) & (d*y!=x))
end

# cld(x,y) = div(x,y) + ((x>0) == (y>0) && rem(x,y) != 0 ? 1 : 0)
function cld{T<:Unsigned}(x::T, y::T)
    d = div(x,y)
    d + (d*y!=x)
end
function cld{T<:Integer}(x::T, y::T)
    d = div(x,y)
    d + (((x>0) == (y>0)) & (d*y!=x))
end

## integer bitwise operations ##

(~){T<:UnionIntTypes}(x::T)       = box(T,not_int(unbox(T,x)))
(&){T<:UnionIntTypes}(x::T, y::T) = box(T,and_int(unbox(T,x),unbox(T,y)))
(|){T<:UnionIntTypes}(x::T, y::T) = box(T, or_int(unbox(T,x),unbox(T,y)))
($){T<:UnionIntTypes}(x::T, y::T) = box(T,xor_int(unbox(T,x),unbox(T,y)))

>>{T<:SignedIntTypes,S<:Integer64}(x::T, y::S)   = box(T,ashr_int(unbox(T,x),unbox(S,y)))
>>{T<:UnsignedIntTypes,S<:Integer64}(x::T, y::S) = box(T,lshr_int(unbox(T,x),unbox(S,y)))
<<{T<:UnionIntTypes,S<:Integer64}(x::T,  y::S)   = box(T, shl_int(unbox(T,x),unbox(S,y)))
>>>{T<:UnionIntTypes,S<:Integer64}(x::T, y::S)   = box(T,lshr_int(unbox(T,x),unbox(S,y)))

bswap{T<:Union{Int8,UInt8}}(x::T) = x
bswap{T<:Union{Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128}}(x::T) =
    box(T,bswap_int(unbox(T,x)))

count_ones{T<:UnionIntTypes}(x::T) = Int(box(T,ctpop_int(unbox(T,x))))
leading_zeros{T<:UnionIntTypes}(x::T) = Int(box(T,ctlz_int(unbox(T,x))))
trailing_zeros{T<:UnionIntTypes}(x::T) = Int(box(T,cttz_int(unbox(T,x))))

count_zeros(  x::Integer) = count_ones(~x)
leading_ones( x::Integer) = leading_zeros(~x)
trailing_ones(x::Integer) = trailing_zeros(~x)

## integer comparisons ##

<{T<:UnsignedIntTypes}(x::T, y::T)  = ult_int(unbox(T,x),unbox(T,y))
<={T<:SignedIntTypes}(x::T, y::T)   = sle_int(unbox(T,x),unbox(T,y))
<={T<:UnsignedIntTypes}(x::T, y::T) = ule_int(unbox(T,x),unbox(T,y))

==(x::Signed,   y::Unsigned) = (x >= 0) & (unsigned(x) == y)
==(x::Unsigned, y::Signed  ) = (y >= 0) & (x == unsigned(y))
<( x::Signed,   y::Unsigned) = (x <  0) | (unsigned(x) <  y)
<( x::Unsigned, y::Signed  ) = (y >  0) & (x <  unsigned(y))
<=(x::Signed,   y::Unsigned) = (x <= 0) | (unsigned(x) <= y)
<=(x::Unsigned, y::Signed  ) = (y >= 0) & (x <= unsigned(y))

## integer conversions ##

for to in IntTypes, from in tuple(IntTypes...,Bool)
    if !(to === from)
        if to.size < from.size
            if issubtype(to, Signed)
                if issubtype(from, Unsigned)
                    @eval convert(::Type{$to}, x::($from)) =
                        box($to,checked_trunc_sint($to,check_top_bit(unbox($from,x))))
                else
                    @eval convert(::Type{$to}, x::($from)) =
                        box($to,checked_trunc_sint($to,unbox($from,x)))
                end
            else
                @eval convert(::Type{$to}, x::($from)) =
                    box($to,checked_trunc_uint($to,unbox($from,x)))
            end
            @eval rem(x::($from), ::Type{$to}) = box($to,trunc_int($to,unbox($from,x)))
        elseif from.size < to.size || from === Bool
            if issubtype(from, Signed)
                if issubtype(to, Unsigned)
                    @eval convert(::Type{$to}, x::($from)) =
                        box($to,sext_int($to,check_top_bit(unbox($from,x))))
                else
                    @eval convert(::Type{$to}, x::($from)) =
                        box($to,sext_int($to,unbox($from,x)))
                end
                @eval rem(x::($from), ::Type{$to}) = box($to,sext_int($to,unbox($from,x)))
            else
                @eval convert(::Type{$to}, x::($from)) = box($to,zext_int($to,unbox($from,x)))
                @eval rem(x::($from), ::Type{$to}) = convert($to,x)
            end
        else
            if !(issubtype(from,Signed) === issubtype(to,Signed))
                # raise InexactError if x's top bit is set
                @eval convert(::Type{$to}, x::($from)) = box($to,check_top_bit(unbox($from,x)))
            else
                @eval convert(::Type{$to}, x::($from)) = box($to,unbox($from,x))
            end
            @eval rem(x::($from), ::Type{$to}) = box($to,unbox($from,x))
        end
    end
end

rem{T<:Integer}(x::T, ::Type{T}) = x
rem(x::Integer, ::Type{Bool}) = ((x&1)!=0)
mod{T<:Integer}(x::Integer, ::Type{T}) = rem(x, T)

convert{T<:UnionS64Types,Tf<:Union{Float32,Float64}}(::Type{T}, x::Tf) =
    box(T,checked_fptosi(T,unbox(Tf,x)))
convert{T<:UnionU64Types,Tf<:Union{Float32,Float64}}(::Type{T}, x::Tf) =
    box(T,checked_fptoui(T,unbox(Tf,x)))

convert{T<:Union{Int128,UInt128},Tf<:Union{Float32,Float64}}(::Type{T},x::Tf) =
    (isinteger(x) || throw(InexactError()) ; trunc(T,x))

for (Ts, Tu) in ((Int8, UInt8), (Int16, UInt16), (Int32, UInt32), (Int64, UInt64), (Int128, UInt128))
    @eval convert(::Type{Signed}, x::$Tu) = convert($Ts, x)
    @eval convert(::Type{Unsigned}, x::$Ts) = convert($Tu, x)
end

convert{T<:Union{Float32, Float64, Bool}}(::Type{Signed}, x::T) = convert(Int,x)
convert{T<:Union{Float32, Float64, Bool}}(::Type{Unsigned}, x::T) = convert(UInt,x)

convert(::Type{Integer}, x::Integer) = x
convert(::Type{Integer}, x::Real) = convert(Signed,x)

round(x::Integer) = x
trunc(x::Integer) = x
floor(x::Integer) = x
 ceil(x::Integer) = x

round{T<:Integer}(::Type{T},x::Integer) = convert(T,x)
trunc{T<:Integer}(::Type{T},x::Integer) = convert(T,x)
floor{T<:Integer}(::Type{T},x::Integer) = convert(T,x)
 ceil{T<:Integer}(::Type{T},x::Integer) = convert(T,x)

## integer construction ##

macro int128_str(s)
    parse(Int128,s)
end

macro uint128_str(s)
    parse(UInt128,s)
end

macro big_str(s)
    n = tryparse(BigInt,s)
    !isnull(n) && return get(n)
    n = tryparse(BigFloat,s)
    !isnull(n) && return get(n)
    message = "invalid number format $s for BigInt or BigFloat"
    :(throw(ArgumentError($message)))
end

## system word size ##

const WORD_SIZE = Int(Int.size)*8

## integer promotions ##

promote_rule(::Type{Int8}, ::Type{Int16})   = Int16
promote_rule(::Type{UInt8}, ::Type{UInt16}) = UInt16
promote_rule{T<:Union{Int8,Int16}}(::Type{Int32}, ::Type{T})    = Int32
promote_rule{T<:Union{UInt8,UInt16}}(::Type{UInt32}, ::Type{T}) = UInt32
promote_rule{T<:Union{Int8,Int16,Int32}}(::Type{Int64}, ::Type{T})     = Int64
promote_rule{T<:Union{UInt8,UInt16,UInt32}}(::Type{UInt64}, ::Type{T}) = UInt64
promote_rule{T<:UnionS64Types}(::Type{Int128}, ::Type{T})    = Int128
promote_rule{T<:UnionU64Types}(::Type{UInt128}, ::Type{T}) = UInt128
for T in tuple(Signed64Types...,Int128)
    @eval promote_rule{S<:Union{UInt8,UInt16}}(::Type{S}, ::Type{$T}) =
        $(sizeof(T) < sizeof(Int) ? Int : T)
end
@eval promote_rule{T<:Union{Int8,Int16,Int32}}(::Type{UInt32}, ::Type{T}) =
    $(WORD_SIZE == 64 ? Int : UInt)
promote_rule(::Type{UInt32}, ::Type{Int64}) = Int64
promote_rule{T<:UnionS64Types}(::Type{UInt64}, ::Type{T}) = UInt64
promote_rule{T<:Union{UInt32, UInt64}}(::Type{T}, ::Type{Int128}) = Int128
promote_rule{T<:SignedIntTypes}(::Type{UInt128}, ::Type{T}) = UInt128

promote_op{R<:Integer,S<:Integer}(op, ::Type{R}, ::Type{S}) = typeof(op(one(R), one(S)))

## traits ##

typemin(::Type{Int8  }) = Int8(-128)
typemax(::Type{Int8  }) = Int8(127)
typemin(::Type{UInt8 }) = UInt8(0)
typemax(::Type{UInt8 }) = UInt8(255)
typemin(::Type{Int16 }) = Int16(-32768)
typemax(::Type{Int16 }) = Int16(32767)
typemin(::Type{UInt16}) = UInt16(0)
typemax(::Type{UInt16}) = UInt16(65535)
typemin(::Type{Int32 }) = Int32(-2147483648)
typemax(::Type{Int32 }) = Int32(2147483647)
typemin(::Type{UInt32}) = UInt32(0)
typemax(::Type{UInt32}) = UInt32(4294967295)
typemin(::Type{Int64 }) = -9223372036854775808
typemax(::Type{Int64 }) = 9223372036854775807
typemin(::Type{UInt64}) = UInt64(0)
typemax(::Type{UInt64}) = 0xffffffffffffffff
@eval typemin(::Type{UInt128}) = $(UInt128(0))
@eval typemax(::Type{UInt128}) = $(box(UInt128,unbox(Int128,convert(Int128,-1))))
@eval typemin(::Type{Int128} ) = $(convert(Int128,1)<<127)
@eval typemax(::Type{Int128} ) = $(box(Int128,unbox(UInt128,typemax(UInt128)>>1)))

widen{T<:Union{Int8, Int16}}(::Type{T}) = Int
widen(::Type{Int32}) = Int64
widen(::Type{Int64}) = Int128
widen{T<:Union{UInt8, UInt16}}(::Type{T}) = UInt
widen(::Type{UInt32}) = UInt64
widen(::Type{UInt64}) = UInt128

# a few special cases,
# Int64*UInt64 => Int128
# |x|<=2^(k-1), |y|<=2^k-1   =>   |x*y|<=2^(2k-1)-1
widemul(x::Signed,y::Unsigned) = widen(x)*signed(widen(y))
widemul(x::Unsigned,y::Signed) = signed(widen(x))*widen(y)
# multplication by Bool doesn't require widening
widemul(x::Bool,y::Bool) = x*y
widemul(x::Bool,y::Number) = x*y
widemul(x::Number,y::Bool) = x*y


## wide multiplication, Int128 multiply and divide ##

if WORD_SIZE == 32
    function widemul(u::Int64, v::Int64)
        local u0::UInt64, v0::UInt64, w0::UInt64
        local u1::Int64, v1::Int64, w1::UInt64, w2::Int64, t::UInt64

        u0 = u&0xffffffff; u1 = u>>32
        v0 = v&0xffffffff; v1 = v>>32
        w0 = u0*v0
        t = reinterpret(UInt64,u1)*v0 + (w0>>>32)
        w2 = reinterpret(Int64,t) >> 32
        w1 = u0*reinterpret(UInt64,v1) + (t&0xffffffff)
        hi = u1*v1 + w2 + (reinterpret(Int64,w1) >> 32)
        lo = w0&0xffffffff + (w1 << 32)
        Int128(hi)<<64 + Int128(lo)
    end

    function widemul(u::UInt64, v::UInt64)
        local u0::UInt64, v0::UInt64, w0::UInt64
        local u1::UInt64, v1::UInt64, w1::UInt64, w2::UInt64, t::UInt64

        u0 = u&0xffffffff; u1 = u>>>32
        v0 = v&0xffffffff; v1 = v>>>32
        w0 = u0*v0
        t = u1*v0 + (w0>>>32)
        w2 = t>>>32
        w1 = u0*v1 + (t&0xffffffff)
        hi = u1*v1 + w2 + (w1 >>> 32)
        lo = w0&0xffffffff + (w1 << 32)
        UInt128(hi)<<64 + UInt128(lo)
    end

    function *(u::Int128, v::Int128)
        u0 = u % UInt64; u1 = Int64(u>>64)
        v0 = v % UInt64; v1 = Int64(v>>64)
        lolo = widemul(u0, v0)
        lohi = widemul(reinterpret(Int64,u0), v1)
        hilo = widemul(u1, reinterpret(Int64,v0))
        t = reinterpret(UInt128,hilo) + (lolo>>>64)
        w1 = reinterpret(UInt128,lohi) + (t&0xffffffffffffffff)
        Int128(lolo&0xffffffffffffffff) + reinterpret(Int128,w1)<<64
    end

    function *(u::UInt128, v::UInt128)
        u0 = u % UInt64; u1 = UInt64(u>>>64)
        v0 = v % UInt64; v1 = UInt64(v>>>64)
        lolo = widemul(u0, v0)
        lohi = widemul(u0, v1)
        hilo = widemul(u1, v0)
        t = hilo + (lolo>>>64)
        w1 = lohi + (t&0xffffffffffffffff)
        (lolo&0xffffffffffffffff) + UInt128(w1)<<64
    end

    div(x::Int128, y::Int128) = Int128(div(BigInt(x),BigInt(y)))
    div(x::UInt128, y::UInt128) = UInt128(div(BigInt(x),BigInt(y)))

    rem(x::Int128, y::Int128) = Int128(rem(BigInt(x),BigInt(y)))
    rem(x::UInt128, y::UInt128) = UInt128(rem(BigInt(x),BigInt(y)))

    mod(x::Int128, y::Int128) = Int128(mod(BigInt(x),BigInt(y)))

    <<( x::Int128,  y::Int) = y == 0 ? x : box(Int128,shl_int(unbox(Int128,x),unbox(Int,y)))
    <<( x::UInt128, y::Int) = y == 0 ? x : box(UInt128,shl_int(unbox(UInt128,x),unbox(Int,y)))
    >>( x::Int128,  y::Int) = y == 0 ? x : box(Int128,ashr_int(unbox(Int128,x),unbox(Int,y)))
    >>( x::UInt128, y::Int) = y == 0 ? x : box(UInt128,lshr_int(unbox(UInt128,x),unbox(Int,y)))
    >>>(x::Int128,  y::Int) = y == 0 ? x : box(Int128,lshr_int(unbox(Int128,x),unbox(Int,y)))
    >>>(x::UInt128, y::Int) = y == 0 ? x : box(UInt128,lshr_int(unbox(UInt128,x),unbox(Int,y)))
else
    *{T<:Union{Int128,UInt128}}(x::T, y::T)  = box(T,mul_int(unbox(T,x),unbox(T,y)))

    div(x::Int128,  y::Int128)  = box(Int128,checked_sdiv(unbox(Int128,x),unbox(Int128,y)))
    div(x::UInt128, y::UInt128) = box(UInt128,checked_udiv(unbox(UInt128,x),unbox(UInt128,y)))

    rem(x::Int128,  y::Int128)  = box(Int128,checked_srem(unbox(Int128,x),unbox(Int128,y)))
    rem(x::UInt128, y::UInt128) = box(UInt128,checked_urem(unbox(UInt128,x),unbox(UInt128,y)))
end

## checked +, -, *, div, rem, fld, mod

"""
    Base.checked_add(x, y)

Calculates `x+y`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_add end

"""
    Base.checked_sub(x, y)

Calculates `x-y`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_sub end

"""
    Base.checked_mul(x, y)

Calculates `x*y`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_mul end

"""
    Base.checked_div(x, y)

Calculates `div(x,y)`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_div end

"""
    Base.checked_rem(x, y)

Calculates `x%y`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_rem end

"""
    Base.checked_fld(x, y)

Calculates `fld(x,y)`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_fld end

"""
    Base.checked_mod(x, y)

Calculates `mod(x,y)`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_mod end

"""
    Base.checked_cld(x, y)

Calculates `cld(x,y)`, checking for overflow errors where applicable.

The overflow protection may impose a perceptible performance penalty.
"""
function checked_cld end

# requires int arithmetic defined, for the loops to work

# Int128 ## FIXME: #4905
checked_add{T<:UnionS64Types}(x::T, y::T) = box(T,checked_sadd(unbox(T,x),unbox(T,y)))
checked_sub{T<:UnionS64Types}(x::T, y::T) = box(T,checked_ssub(unbox(T,x),unbox(T,y)))
checked_mul{T<:Union{Int16,Int32}}(x::T, y::T) = box(T,checked_smul(unbox(T,x),unbox(T,y)))

# UInt128 ## FIXME: #4905
checked_add{T<:UnionU64Types}(x::T, y::T) = box(T,checked_uadd(unbox(T,x),unbox(T,y)))
checked_sub{T<:UnionU64Types}(x::T, y::T) = box(T,checked_usub(unbox(T,x),unbox(T,y)))
checked_mul{T<:Union{UInt16,UInt32}}(x::T, y::T) = box(T,checked_umul(unbox(T,x),unbox(T,y)))

# checked mul is broken for 8-bit types (LLVM bug?) ## FIXME: #4905

for T in (Int8,UInt8)
    @eval function checked_mul(x::$T, y::$T)
        xy = widemul(x,y)
        (typemin($T) <= xy <= typemax($T)) || throw(OverflowError())
        return xy % $T
    end
end

if WORD_SIZE == 32
    for T in (Int64,UInt64)
        @eval function checked_mul(x::$T, y::$T)
            xy = Int128(x)*Int128(y)
            (typemin($T) <= xy <= typemax($T)) || throw(OverflowError())
            return xy % $T
        end
    end
else
    checked_mul(x::Int64,  y::Int64)  = box(Int64, checked_smul(unbox(Int64,x), unbox(Int64,y)))
    checked_mul(x::UInt64, y::UInt64) = box(UInt64,checked_umul(unbox(UInt64,x),unbox(UInt64,y)))
end

# checked ops are broken for 128-bit types (LLVM bug) ## FIXME: #4905

function checked_add(x::Int128, y::Int128)
    # # x + y > typemax(Int128)
    # y >= 0 && x > typemax(Int128) - y && throw(OverflowError())
    # # x + y < typemin(Int128)
    # y < 0 && x < typemin(Int128) - y && throw(OverflowError())
    # x + y
    r = x + y
    # x and y have the same sign, and the result has a different sign
    (x$y >= 0) & (x$r < 0) && throw(OverflowError())
    r
end

function checked_sub(x::Int128, y::Int128)
    # # x - y > typemax(Int128)
    # y < 0 && x > typemax(Int128) + y && throw(OverflowError())
    # # x - y < typemin(Int128)
    # y >= 0 && x < typemin(Int128) + y && throw(OverflowError())
    # x - y
    r = x - y
    # x and y have different signs, and the result has a different sign than x
    (x$y < 0) & (x$r < 0) && throw(OverflowError())
    r
end

function checked_mul(x::Int128, y::Int128)
    if y > 0
        # x * y > typemax(Int128)
        # x * y < typemin(Int128)
        x > fld(typemax(Int128), y) && throw(OverflowError())
        x < cld(typemin(Int128), y) && throw(OverflowError())
    elseif y < 0
        # x * y > typemax(Int128)
        # x * y < typemin(Int128)
        x < cld(typemax(Int128), y) && throw(OverflowError())
        # y == -1 can overflow fld
        y != -1 && x > fld(typemin(Int128), y) && throw(OverflowError())
    end
    x * y
end

function checked_add(x::UInt128, y::UInt128)
    # x + y > typemax(UInt128)
    # x > typemax(UInt128) - y && throw(OverflowError())
    # Note: ~x = -x-1
    x > ~y && throw(OverflowError())
    x + y
end

function checked_sub(x::UInt128, y::UInt128)
    # x - y < 0
    x < y && throw(OverflowError())
    x - y
end

function checked_mul(x::UInt128, y::UInt128)
    # x * y > typemax(UInt128)
    y > 0 && x > fld(typemax(UInt128), y) && throw(OverflowError())
    x * y
end

# These implementations check by default
checked_div{T<:UnionIntTypes}(x::T, y::T) = div(x,y)
checked_rem{T<:UnionIntTypes}(x::T, y::T) = rem(x,y)
checked_fld{T<:UnionIntTypes}(x::T, y::T) = fld(x,y)
checked_mod{T<:UnionIntTypes}(x::T, y::T) = mod(x,y)
checked_cld{T<:UnionIntTypes}(x::T, y::T) = cld(x,y)

# Handle multiple arguments
checked_add(x) = x
checked_mul(x) = x
for f in (:checked_add, :checked_mul)
    @eval begin
        ($f){T}(x1::T, x2::T, x3::T) =
            ($f)(($f)(x1, x2), x3)
        ($f){T}(x1::T, x2::T, x3::T, x4::T) =
            ($f)(($f)(x1, x2), x3, x4)
        ($f){T}(x1::T, x2::T, x3::T, x4::T, x5::T) =
            ($f)(($f)(x1, x2), x3, x4, x5)
        ($f){T}(x1::T, x2::T, x3::T, x4::T, x5::T, x6::T) =
            ($f)(($f)(x1, x2), x3, x4, x5, x6)
        ($f){T}(x1::T, x2::T, x3::T, x4::T, x5::T, x6::T, x7::T) =
            ($f)(($f)(x1, x2), x3, x4, x5, x6, x7)
        ($f){T}(x1::T, x2::T, x3::T, x4::T, x5::T, x6::T, x7::T, x8::T) =
            ($f)(($f)(x1, x2), x3, x4, x5, x6, x7, x8)
    end
end
