// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 
pragma abicoder v2;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MathHelper.sol";
import "./IERC20Minimal.sol";
import "./OrderedSet.sol";

contract OrderBook{ 

   using OrderedSet for OrderedSet.Set;
   using OrderedUint256Set for OrderedUint256Set.Set;
   event NewEntry(address user, bool isBuy, uint256 price, uint256 amount);
   event Transaction(address buyer, address seller, uint256 price, uint256 amount);
   uint16 public constant SIG_DIGITS=5;  //# of significant digits
   uint16 public constant MAX_DEPTH=100;

   uint public maxPrecision;

   OrderedUint256Set.Set private buyBook;
   OrderedUint256Set.Set private sellBook;

   mapping(uint256=>OrderedSet.Set) private theBook;
   mapping(address=>mapping(uint256=>uint256)) public amounts;

   // latest transaction price
   uint256 curPrice;

   IERC20Minimal public Base;
   IERC20Minimal public Token;

   using Counters for Counters.Counter;

   Counters.Counter private _tokenIds;

   constructor(IERC20Minimal base, IERC20Minimal token) public {
      Base = base;
      Token = token;
      maxPrecision = 0;
   }

   function order(uint256 price, uint256 amount, bool isBuy) public {
      if (isBuy) {
         buy(price, amount);
      } else {
         sell(price, amount);
      }
   }
   function buy(uint256 price, uint256 amount) internal 
   {
      Base.transferFrom(msg.sender, address(this), amount);
      uint256 transferAmount = 0;
      address user = msg.sender;
      // case 1, if the order is below the current market
      uint256 tmpPrice = OrderedUint256Set.head(sellBook);
      if (price < tmpPrice || tmpPrice == 0) {
         addOrderEntry(price, amount, true);
      }

      address tmpOwner = OrderedSet.head(theBook[tmpPrice]);
      for (uint256 i=0; i < MAX_DEPTH && amount > 0 && price >= tmpPrice; ++i) 
      {
         uint256 orderAmount = amounts[tmpOwner][tmpPrice];
         uint256 txAmount;
         if (orderAmount >= amount) { //meaning the current order can fill
            txAmount = amount;
         } else {
            txAmount = orderAmount;
         }
         amounts[tmpOwner][tmpPrice] -= txAmount;
         transferAmount += txAmount;
         emit Transaction(tmpOwner, user, tmpPrice, txAmount);
         amount -= txAmount;
         curPrice = tmpPrice;

         if (amounts[tmpOwner][tmpPrice] == 0) {
            OrderedSet.remove(theBook[tmpPrice], tmpOwner);
            tmpOwner = OrderedSet.head(theBook[tmpPrice]);
            if (tmpOwner == address(0)) {
                OrderedUint256Set.remove(sellBook, tmpPrice);
                delete theBook[tmpPrice];
                tmpPrice = OrderedUint256Set.head(sellBook);
                if (tmpPrice == 0) {
                   break;
                }
                tmpOwner = OrderedSet.head(theBook[tmpPrice]);
            }
         }
      }

      if (amount > 0 && (price < tmpPrice || tmpPrice == 0) ) {
         addOrderEntry(price, amount, true);
      }

      Token.transferFrom(address(this), msg.sender, transferAmount);
   }

   function sell(uint256 price, uint256 amount) internal 
   {
      Token.transferFrom(msg.sender, address(this), amount);
      address user = msg.sender;
      // case 1, if the order is below the current market
      uint256 tmpPrice = OrderedUint256Set.head(buyBook);
      uint256 transferAmount = 0;
      if (price > tmpPrice || tmpPrice == 0) {
         addOrderEntry(price, amount, true);
      }

      address tmpOwner = OrderedSet.head(theBook[tmpPrice]);
      for (uint256 i=0; i < MAX_DEPTH && amount > 0 && price <= tmpPrice; ++i) 
      {
         uint256 orderAmount = amounts[tmpOwner][tmpPrice];
         uint256 txAmount;
         if (orderAmount >= amount) { //meaning the current order can fill
            txAmount = amount;
         } else {
            txAmount = orderAmount;
         }
         amounts[tmpOwner][tmpPrice] -= txAmount;
         emit Transaction(user, tmpOwner, tmpPrice, txAmount);
         amount -= txAmount;
         transferAmount += txAmount * tmpPrice / 10^18;
         curPrice = tmpPrice;

         if (amounts[tmpOwner][tmpPrice] == 0) {
            OrderedSet.remove(theBook[tmpPrice], tmpOwner);
            tmpOwner = OrderedSet.head(theBook[tmpPrice]);
            if (tmpOwner == address(0)) {
                OrderedUint256Set.remove(buyBook, tmpPrice);
                delete theBook[tmpPrice];
                tmpPrice = OrderedUint256Set.head(buyBook);
                if (tmpPrice == 0) {
                   break;
                }
                tmpOwner = OrderedSet.head(theBook[tmpPrice]);
            }
         }
      }

      if (amount > 0 && (price > tmpPrice || tmpPrice == 0) ) {
         addOrderEntry(price, amount, false);
      }
      Base.transferFrom(address(this), msg.sender, transferAmount);
   }

   function removeOrderEntry(uint256 price) public {
      require(amounts[msg.sender][price] > 0, "invalid order amount");
      OrderedSet.remove(theBook[price], msg.sender);
      if (OrderedSet.head(theBook[price]) == address(0)) {
         if (price <= OrderedUint256Set.head(buyBook)) {
            OrderedUint256Set.remove(buyBook, price);
         } else {
            OrderedUint256Set.remove(sellBook, price);
         }

         delete theBook[price];
      }
   }
   function addOrderEntry(uint256 price, uint256 amount, bool isBuy) public {
      uint256 prevPrice = 0;
      if (maxPrecision != 0) {
         uint length = bytes(uint2str(price)).length;
         require(length > maxPrecision, "the price is too granular");
         price -= price % MathHelper.pow(10, maxPrecision);
      }

      require(price > 0, "price cannot be zero");
      if (isBuy) {
         uint256 tmpPrice = OrderedUint256Set.head(buyBook);
         for (uint i = 0; price > tmpPrice && tmpPrice != 0; ++i) {
            require (i < MAX_DEPTH, "The order is too deep");
            prevPrice = tmpPrice;
            tmpPrice = buyBook.next[tmpPrice];
         }
         if (price != tmpPrice) {
            OrderedUint256Set._insert(buyBook, prevPrice, price, tmpPrice);
         }

         OrderedSet.append(theBook[price], msg.sender);
         amounts[msg.sender][price] += amount;

         uint tmpLength = bytes(uint2str(OrderedUint256Set.head(buyBook))).length;
         if (tmpLength > SIG_DIGITS) {
            maxPrecision = tmpLength - SIG_DIGITS; 
         }
      } else {
         uint256 tmpPrice = OrderedUint256Set.head(sellBook);
         for (uint i = 0; price < tmpPrice && tmpPrice != 0; ++i) {
            require (i < MAX_DEPTH, "The order is too deep");
            prevPrice = tmpPrice;
            tmpPrice = sellBook.next[tmpPrice];
         }
         if (price != tmpPrice) {
            OrderedUint256Set._insert(sellBook, prevPrice, price, tmpPrice);
         }

         OrderedSet.append(theBook[price], msg.sender);
         amounts[msg.sender][price] += amount;
         uint tmpLength = bytes(uint2str(OrderedUint256Set.head(sellBook))).length;
         if (tmpLength > SIG_DIGITS) {
            maxPrecision = tmpLength - SIG_DIGITS; 
         }
      }
   }

   function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

   function str2uint(string memory s) internal pure returns (uint) {
      bytes memory b = bytes(s);
      uint result = 0;
      for (uint i = 0; i < b.length; i++) { 
         if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
            result = result * 10 + (uint8(b[i]) - 48); 
         }
      }
      return result;
   }
}
