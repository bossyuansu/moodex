// contracts/Puppy.sol 
// SPDX-License-Identifier: MIT 
pragma solidity ^0.7.0; 
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";  
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPuppyV1.sol";
import "./MathHelper.sol";
import "./IERC20Minimal.sol";

contract PuppyV1 is IPuppyV1, ERC721, AccessControl, Ownable { 
   bytes32 public constant BREEDER_ROLE = keccak256("BREEDER_ROLE");
   string public constant URI = "https://nftmeta.metis.io/?a=";

   uint256 public constant SKILL_BOOST_SPEED = 1;
   uint256 public constant SKILL_BOOST_ACCL = 2;
   uint256 public constant SKILL_BOOST_AGILITY = 2**2;
   uint256 public constant SKILL_PERSEVERE = 2**3;
   uint256 public constant SKILL_BOOST_SPEED_PLUS = 2**4;
   uint256 public constant SKILL_BOOST_ACCL_PLUS = 2**5;
   uint256 public constant SKILL_BOOST_AGILITY_PLUS = 2**6;
   uint256 public constant SKILL_PERSEVERE_PLUS = 2**7;
   uint256 public constant SKILL_UNTOUCHABLE = 2**8;
   uint256 public constant SKILL_UNTOUCHABLE_PLUS = 2**9;
   uint256 public constant SKILL_INTERFERE_SPEED = 2**10;
   uint256 public constant SKILL_INTERFERE_ACCL = 2**11;
   uint256 public constant SKILL_INTERFERE_AGILITY = 2**12;
   uint256 public constant SKILL_EXHAUST = 2**13;
   uint256 public constant SKILL_INTERFERE_SPEED_PLUS = 2**14;
   uint256 public constant SKILL_INTERFERE_ACCL_PLUS = 2**15;
   uint256 public constant SKILL_INTERFERE_AGILITY_PLUS = 2**16;
   uint256 public constant SKILL_EXHAUST_PLUS = 2**17;
   uint256 public constant SKILL_TIME_STOP = 2**18;
   uint256 public constant SKILL_IGNORE_TRACK_PENALTY = 2**19;
   
   IERC20Minimal private constant CoinBase = IERC20Minimal(0x4200000000000000000000000000000000000006);

   using Counters for Counters.Counter;

   Counters.Counter private _tokenIds;

   constructor() ERC721("Puppy", "PUP") public {
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
   }

   function calculatePositionDelta(PuppyAttributes memory attr, uint256 curSpeed, uint8 arc) pure public override returns (uint256 distance, uint256 newSpeed, uint16 newStamina) {
      require (arc < 120);

      uint256 arcPenaltyRatio = arc * 100 / 120;
      arcPenaltyRatio = MathHelper.mulDiv(100 - attr.agility * 100 / 65535, arcPenaltyRatio, 100);

      uint256 staminaThreshold = 1000;
      uint256 staminaPenaltyRatio = 0;
      if (staminaThreshold > attr.stamina) {
         staminaPenaltyRatio = 100 - attr.stamina / 10;
      }

      if (curSpeed < attr.speed) {
         newSpeed = curSpeed + attr.acceleration / 10 + 10;
      }

      if (newSpeed > attr.speed) {
         newSpeed = attr.speed;
      }

      newSpeed = MathHelper.mulDiv(newSpeed, 100 - staminaPenaltyRatio, 100);
      newSpeed = MathHelper.mulDiv(newSpeed, 100 - arcPenaltyRatio, 100);
      distance = (newSpeed + curSpeed) / 2;
      if (attr.stamina <= 20) {
         newStamina = 20;
      } else {
         newStamina = attr.stamina - 10;
         if (newSpeed > curSpeed) {
            newStamina = newStamina - 10;
         }
      }
   }

   function applyRaceEffects(uint256 id, uint256 curStamina, uint16[] calldata effects) view public override returns (PuppyAttributes memory attr, uint16 newStamina){
      attr = extractAttributes(id, true);

      // do the weight first because weight affects the debuff
      attr.weight = uint16(MathHelper.mulDiv(attr.weight, effects[4] + 100, 100)); 
      
      // minimum protection
      if (attr.weight < 800) {
         attr.weight = 800;
      }
      attr.speed = uint16(MathHelper.mulDiv(attr.speed, effects[0] + 100 - effects[5] * 1000 /attr.weight, 100)); 
      attr.acceleration = uint16(MathHelper.mulDiv(attr.acceleration, effects[1] + 100 - effects[6] * 1000 / attr.weight, 100)); 
      attr.agility = uint16(MathHelper.mulDiv(attr.agility, effects[2] + 100 - effects[7] * 1000 / attr.weight, 100)); 
      newStamina = uint16(MathHelper.mulDiv(curStamina, effects[3] + 100 - effects[8] * 1000 / attr.weight, 100)); 
   }

   function getRaceSkillEffects(uint256 skillbits, uint256 seed) pure public override returns(uint16[] memory effects) {
      effects = new uint16[](10);

      if (skillbits | SKILL_BOOST_SPEED > 0) {
         if (addmod(seed, 34110923166592, 997) > 900) {
            effects[0] += 10;
         }
      }

      if (skillbits | SKILL_BOOST_ACCL > 0) {
         if (addmod(seed, 199190457528911, 997) > 900) {
            effects[1] += 10;
         }
      }

      if (skillbits | SKILL_BOOST_AGILITY > 0) {
         if (addmod(seed, 8712937192371075, 997) > 900) {
            effects[2] += 10;
         }
      }
      if (skillbits | SKILL_PERSEVERE > 0) {
         if (addmod(seed, 2889058917, 997) > 900) {
            effects[3] = 50;
         }
      }

      if (skillbits | SKILL_BOOST_SPEED_PLUS > 0) {
         if (addmod(seed, 34110923166592, 997) > 900) {
            effects[0] += 20;
         }
      }

      if (skillbits | SKILL_BOOST_ACCL_PLUS > 0) {
         if (addmod(seed, 199190457528911, 997) > 900) {
            effects[1] += 20;
         }
      }

      if (skillbits | SKILL_BOOST_AGILITY_PLUS > 0) {
         if (addmod(seed, 8712937192371075, 997) > 900) {
            effects[2] += 20;
         }
      }
      if (skillbits | SKILL_PERSEVERE_PLUS > 0) {
         if (addmod(seed, 2889058917, 997) > 800) {
            effects[3] = 50;
         }
      }

      if (skillbits | SKILL_UNTOUCHABLE > 0) {
         if (addmod(seed, 7774551414587, 997) > 900) {
            effects[4] = 50;
         }
      }

      if (skillbits | SKILL_UNTOUCHABLE_PLUS > 0) {
         if (addmod(seed, 321411232588, 997) > 800) {
            effects[4] = 50;
         }
      }

      if (skillbits | SKILL_INTERFERE_SPEED > 0) {
         if (addmod(seed, 5828171928, 997) > 900) {
            effects[5] += 10;
         }
      }

      if (skillbits | SKILL_INTERFERE_ACCL > 0) {
         if (addmod(seed, 8010811002487876, 997) > 900) {
            effects[6] += 10;
         }
      }

      if (skillbits | SKILL_INTERFERE_AGILITY > 0) {
         if (addmod(seed, 19297400748167, 997) > 900) {
            effects[7] += 10;
         }
      }
      if (skillbits | SKILL_EXHAUST > 0) {
         if (addmod(seed, 65874698244546, 997) > 900) {
            effects[8] = 20;
         }
      }

      if (skillbits | SKILL_INTERFERE_SPEED_PLUS > 0) {
         if (addmod(seed, 7985242133269745, 997) > 900) {
            effects[5] += 20;
         }
      }

      if (skillbits | SKILL_INTERFERE_ACCL_PLUS > 0) {
         if (addmod(seed, 6547545552264111, 997) > 900) {
            effects[6] += 20;
         }
      }

      if (skillbits | SKILL_INTERFERE_AGILITY_PLUS > 0) {
         if (addmod(seed, 54697733311477, 997) > 900) {
            effects[7] += 20;
         }
      }
      if (skillbits | SKILL_EXHAUST_PLUS > 0) {
         if (addmod(seed, 5566664442321217, 997) > 800) {
            effects[8] = 20;
         }
      }
      if (skillbits >= SKILL_TIME_STOP ) {
         if (skillbits | SKILL_TIME_STOP > 0 && addmod(seed, 12088429300013871, 997) > 995) {
            effects[9] = 1;
         } else if (skillbits | SKILL_TIME_STOP > 0 && addmod(seed, 46666897741366626, 997) > 900) {
            effects[9] = 2;
         }
      }
   }
   function addBreeder(address breeder) onlyOwner public override {
      grantRole(BREEDER_ROLE, breeder);
   }

   function removeBreeder(address breeder) onlyOwner public override {
      revokeRole(BREEDER_ROLE, breeder);
   }

   function awardPuppy(address player, string memory tokenURI, uint256 price) public override returns (uint256)
   {
      require(hasRole(BREEDER_ROLE, msg.sender), "not a breeder");

      if (price > 0) {
         require(CoinBase.transferFrom(player, msg.sender, price), "transfer failed");
      }
      _tokenIds.increment();
      uint256 newItemId = _tokenIds.current();
      _mint(player, newItemId);
      _setTokenURI(newItemId, string(abi.encodePacked(URI, tokenURI)));

      emit NewPuppy(msg.sender, player, price, newItemId, tokenURI);

      return newItemId;
   }

   function updatePuppy(uint256 id, PuppyAttributes calldata attr) public override {
      require(hasRole(BREEDER_ROLE, msg.sender));
      string memory attrStr = encodeAttributes(attr);
      _setTokenURI(id, string(abi.encodePacked(URI, attrStr)));
      emit UpdatePuppy(msg.sender, id, attrStr);
   }

   function encodeAttributes(PuppyAttributes calldata attr) pure public override returns (string memory){
      return string(abi.encodePacked(uint2str(attr.speed), ";", uint2str(attr.acceleration), ";", uint2str(attr.agility), ";", uint2str(attr.stamina), ";", uint2str(attr.weight), ";", uint2str(attr.color), ";", uint2str(attr.age), ";", uint2str(attr.lifespan), ";", uint2str(attr.breed), ";", uint2str(attr.skillbits)));
   }

   function extractAttributes(uint256 id, bool applyAge) view public override returns (PuppyAttributes memory attr) {
      bytes memory uri = bytes(tokenURI(id));
      uint i;
      for (i = uri.length - 1; i >= 0; --i) {
        if (uri[i] == '?') {
           i = i + 3; //skip ?, a, and =
           break;
        }
      }

      bytes memory result = new bytes(uri.length - i);

      for (uint start = i; i < uri.length; ++i) {
         result[i - start] = uri[i];
      }
      attr = decodeAttributes(string(result)); 

      if (applyAge) {
         // apply age factor in
         uint ageFactor = 100;
         if (attr.age < 5) {
            ageFactor = attr.age * 20;
         } 
         uint liferatio = MathHelper.mulDiv(attr.age, 100, attr.lifespan);
         if (liferatio > 90) {
            ageFactor = 100 - MathHelper.mulDiv( 100 - (100 - liferatio) * 10, 50, 100); 
         }

         attr.weight = uint16(MathHelper.mulDiv(attr.weight, ageFactor, 100));
         attr.speed = uint16(MathHelper.mulDiv(attr.speed, ageFactor, 100));
         attr.acceleration = uint16(MathHelper.mulDiv(attr.acceleration, ageFactor, 100));
         attr.agility = uint16(MathHelper.mulDiv(attr.agility, ageFactor, 100));
         attr.stamina = uint16(MathHelper.mulDiv(attr.stamina, ageFactor, 100));
      }
   }

   function decodeAttributes(string memory input) pure public returns (PuppyAttributes memory attr) {
      bytes memory attrbytes = bytes(input);
      uint i;
      uint start = 0;
      for (i = start; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.speed = uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start, "nothing more?");
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.acceleration = uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start, "nothing more?");
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.agility = uint16(str2uint(string(b)));
            break;
         } 
      }

      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.stamina = uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.weight= uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.color= uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.age= uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.lifespan= uint16(str2uint(string(b)));
            break;
         } 
      }
      start = i + 1;

      for (i = start ; i < attrbytes.length; ++i) {
         if (attrbytes[i] == ';') { 
            require(i > start);
            bytes memory b = new bytes(i - start);
            for (uint j = 0; j < i - start; ++j) {
               b[j] = attrbytes[start + j];
            }
            attr.breed = str2uint(string(b));
            break;
         } 
      }
      start = i + 1;

      i = attrbytes.length;
      require(i > start, "how come there is nothing left?");
      bytes memory b2 = new bytes(i - start);
      for (uint j = 0; j < i - start; ++j) {
         b2[j] = attrbytes[start + j];
      }
      attr.skillbits= str2uint(string(b2));

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
         uint k = len - 1;
         while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
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
