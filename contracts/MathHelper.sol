pragma solidity ^0.8.0;
library MathHelper {

    // full precision multiplication. no overflow
    function fullMul (uint x, uint y)
    internal pure returns (uint l, uint h)
    {
       unchecked {
       uint mm = mulmod (x, y, type(uint).max );
       l = x * y;
       h = mm - l;
       if (mm < l) h -= 1;
       }
    }

    // return x*y/z
    function mulDiv (uint x, uint y, uint z) internal pure returns (uint) {

      unchecked {
      (uint l, uint h) = fullMul (x, y);
       require (h < z);
       uint mm = mulmod (x, y, z);
       if (mm > l) h -= 1;
       l -= mm;
       uint pow2 = z & (type(uint).max-z+1);
       z /= pow2;
       l /= pow2;

       l += h * ((type(uint).max-pow2+1) / pow2 + 1);
       uint r = 1;
       r *= 2 - z * r;
       r *= 2 - z * r;
       r *= 2 - z * r;
       r *= 2 - z * r;
       r *= 2 - z * r;
       r *= 2 - z * r;
       r *= 2 - z * r;
       r *= 2 - z * r;
       return l * r;
      }
    }

    // x^n
    function pow (uint x, uint n)
    internal pure returns (uint r) {
       r = 1.0;
       while (n > 0) {
           if (n % 2 == 1) {
              r *= x;
              n -= 1;
           } else {
              x *= x;
              n /= 2;
           }
       }
    }
}
