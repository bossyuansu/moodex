// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 
pragma abicoder v2;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IERC20Minimal.sol";
import "./MathHelper.sol";
import "./OrderedSet.sol";

contract OrderBook{ 

   using OrderedSet for OrderedSet.Set;
   using OrderedUint256Set for OrderedUint256Set.Set;
   event NewEntry(address user, bool isBuy, uint256 price, uint256 amount);
   event Transaction(address buyer, address seller, uint256 price, uint256 amount);
   uint16 public constant SIG_DIGITS=5;  //# of significant digits
   uint16 public constant MAX_DEPTH=100;
   uint16 public constant PRICE_DECIMAL=18;

   uint public maxPrecision;
   uint public leftoverBase;
   uint public leftoverToken;

   OrderedUint256Set.Set private buyBook;
   OrderedUint256Set.Set private sellBook;

   mapping(uint256=>OrderedSet.Set) private theBook;
   mapping(address=>mapping(uint256=>uint256)) public theAmounts;

   // latest transaction price
   uint256 curPrice;

   IERC20Minimal public Base;
   IERC20Minimal public Token;

   uint baseDecimals;
   uint tokenDecimals;

   constructor(IERC20Minimal base, uint bDecimals, IERC20Minimal token, uint tDecimals) public {
      Base = base;
      Token = token;
      maxPrecision = 0;
      leftoverBase = 0;
      leftoverToken = 0;

      baseDecimals = bDecimals;
      tokenDecimals = tDecimals;
   }

   function enumerateBook(bool isBuy, uint depth) view public returns (uint[] memory, uint[] memory) {

      require (depth <= MAX_DEPTH, "depth is too deep");

      uint[] memory prices = new uint[](depth);
      uint[] memory amounts = new uint[](depth);

      OrderedUint256Set.Set storage book;
      if (isBuy) {
         book = buyBook;
      } else {
         book = sellBook;
      }

      uint256 tmpPrice = OrderedUint256Set.head(book);
      for (uint i = 0; i < depth && tmpPrice != 0; ++i) {
         prices[i] = tmpPrice;
         address tmpOwner = OrderedSet.head(theBook[tmpPrice]);
         uint amount = theAmounts[tmpOwner][tmpPrice];
         while ((tmpOwner = theBook[tmpPrice].next[tmpOwner]) != address(0)) {
            amount += theAmounts[tmpOwner][tmpPrice];
         }
         amounts[i] = amount; 
         tmpPrice = book.next[tmpPrice];
      }

      return (prices, amounts);
   }

   // order is important
   function batchOrder(uint256[] calldata prices, uint256[] calldata amounts, bool[] calldata isBuys) public {
      for (uint i; i< prices.length; ++i) {
         order(prices[i], amounts[i], isBuys[i]);
      }
   }
   function order(uint256 price, uint256 amount, bool isBuy) public {
      price = normalizePrice(price);
      if (isBuy) {
         buy(price, amount);
      } else {
         sell(price, amount);
      }
      updatePrecision(curPrice);
   }
   function normalizePrice(uint256 price) public view returns (uint256) {
      if (maxPrecision != 0) {
         uint length = bytes(uint2str(price)).length;
         require(length > maxPrecision, "the price is too granular");
         price -= price % MathHelper.pow(10, maxPrecision);
      }
      return price;
   }

   function baseAmountByPrice(uint256 price, uint256 tokenAmount) public view returns (uint256 baseAmount) {
      return MathHelper.mulDiv(tokenAmount, price, MathHelper.pow(10,tokenDecimals));
   }

   function buy(uint256 price, uint256 amount) internal 
   {
      //calculate the amount of base tokens to be transfered
      uint256 baseAmount = baseAmountByPrice(price, amount);
      require (baseAmount > 0, "price x amount is too low");

      Base.transferFrom(msg.sender, address(this), baseAmount);
      uint256 transferAmount = 0;
      // case 1, if the order is below the current market
      uint256 tmpPrice = OrderedUint256Set.head(sellBook);
      if (price < tmpPrice || tmpPrice == 0) {
         addOrderEntry(price, amount, true);
         return;
      } 
      address tmpOwner = OrderedSet.head(theBook[tmpPrice]);
      for (uint256 i=0; i < MAX_DEPTH && amount > 0 && price >= tmpPrice; ++i) 
      {
         uint256 orderAmount = theAmounts[tmpOwner][tmpPrice];
         uint256 txAmount;
         if (orderAmount >= amount) { //meaning the current order can fill
            txAmount = amount;
         } else {
            txAmount = orderAmount;
         }
         theAmounts[tmpOwner][tmpPrice] -= txAmount;
         transferAmount += txAmount;
         emit Transaction(tmpOwner, msg.sender, tmpPrice, txAmount);
         Base.transfer(tmpOwner, baseAmountByPrice(tmpPrice, txAmount));
         baseAmount -= baseAmountByPrice(tmpPrice, txAmount);

         amount -= txAmount;
         curPrice = tmpPrice;

         if (theAmounts[tmpOwner][tmpPrice] == 0) {
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
         if (addOrderEntry(price, amount, true) == true) {
            baseAmount -= baseAmountByPrice(price, amount);
         }
      }

      // refund any left overs
      if (baseAmount > 0) {
         Base.transfer(msg.sender, baseAmount);
      }

      // transfer the tokens acquired.
      Token.transfer(msg.sender, transferAmount);
   }

   function sell(uint256 price, uint256 amount) internal 
   {
      Token.transferFrom(msg.sender, address(this), amount);
      // case 1, if the order is below the current market
      uint256 tmpPrice = OrderedUint256Set.head(buyBook);
      uint256 transferAmount = 0;
      if (price > tmpPrice || tmpPrice == 0) {
         addOrderEntry(price, amount, false);
         return;
      }

      address tmpOwner = OrderedSet.head(theBook[tmpPrice]);
      for (uint256 i=0; i < MAX_DEPTH && amount > 0 && price <= tmpPrice; ++i) 
      {
         uint256 orderAmount = theAmounts[tmpOwner][tmpPrice];
         uint256 txAmount;
         if (orderAmount >= amount) { //meaning the current order can fill
            txAmount = amount;
         } else {
            txAmount = orderAmount;
         }
         theAmounts[tmpOwner][tmpPrice] -= txAmount;
         emit Transaction(msg.sender, tmpOwner, tmpPrice, txAmount);
         Token.transfer(tmpOwner, txAmount);
         amount -= txAmount;
         transferAmount += baseAmountByPrice(tmpPrice, txAmount);
         curPrice = tmpPrice;

         if (theAmounts[tmpOwner][tmpPrice] == 0) {
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
         if (addOrderEntry(price, amount, false) == true) {
            amount = 0;
         }
      }
      //refund any remaining amount
      if (amount >0) {
         Token.transfer(msg.sender, amount);
      }

      // transfer the proceedings
      Base.transfer(msg.sender, transferAmount);
   }

   function removeOrderEntry(uint256 price) public {
      require(theAmounts[msg.sender][price] > 0, "invalid order amount");
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
   function addOrderEntry(uint256 price, uint256 amount, bool isBuy) internal returns(bool) {

      uint256 baseAmount = baseAmountByPrice(price, amount);
      if (baseAmount == 0) {
         return false; // do not add an entry if the amount x price is too low
      }

      require(price > 0, "price cannot be zero");

      uint256 prevPrice = 0;
      if (isBuy) {
         uint256 tmpPrice = OrderedUint256Set.head(buyBook);
         for (uint i = 0; price < tmpPrice && tmpPrice != 0; ++i) {
            require (i < MAX_DEPTH, "The order is too deep");
            prevPrice = tmpPrice;
            tmpPrice = buyBook.next[tmpPrice];
         }
         if (price != tmpPrice) {
            OrderedUint256Set._insert(buyBook, prevPrice, price, tmpPrice);
         }

         // modifying an existing order will move the order to the back of the queue
         if (OrderedSet.contains(theBook[price], msg.sender)) {
            OrderedSet.remove(theBook[price], msg.sender);
         }
         OrderedSet.append(theBook[price], msg.sender);
         theAmounts[msg.sender][price] += amount;

         updatePrecision(OrderedUint256Set.head(buyBook));

      } else {
         uint256 tmpPrice = OrderedUint256Set.head(sellBook);
         for (uint i = 0; price > tmpPrice && tmpPrice != 0; ++i) {
            require (i < MAX_DEPTH, "The order is too deep");
            prevPrice = tmpPrice;
            tmpPrice = sellBook.next[tmpPrice];
         }
         if (price != tmpPrice) {
            OrderedUint256Set._insert(sellBook, prevPrice, price, tmpPrice);
         }

         // modifying an existing order will move the order to the back of the queue
         if (OrderedSet.contains(theBook[price], msg.sender)) {
            OrderedSet.remove(theBook[price], msg.sender);
         }

         OrderedSet.append(theBook[price], msg.sender);
         theAmounts[msg.sender][price] += amount;

         updatePrecision(OrderedUint256Set.head(sellBook));
      }
      return true;
   }

   function updatePrecision(uint256 price) internal {
      uint tmpLength = bytes(uint2str(price)).length;
      if (tmpLength > SIG_DIGITS) {
         maxPrecision = tmpLength - SIG_DIGITS; 
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
