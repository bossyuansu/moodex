pragma solidity ^0.8.0;
library MathHelper {


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
