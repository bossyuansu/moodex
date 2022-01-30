// scripts/index.js 
async function main() { 

   const tokenabi = [{"inputs":[{"internalType":"address[]","name":"minters","type":"address[]"},{"internalType":"uint256","name":"maxSupply","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"previousOwner","type":"address"},{"indexed":true,"internalType":"address","name":"newOwner","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"constant":true,"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"isOwner","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"renounceOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"target","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"target","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"burn","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"minter","type":"address"}],"name":"addMinter","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"minter","type":"address"}],"name":"removeMinter","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];

   const base = await ethers.getContractAt(tokenabi, "0xF02Efd44B57d143c38A329dD299683bf24Cf8aE0");
   const order = await ethers.getContract("OrderBook");
   const token = await ethers.getContract("GLDToken");
   console.log("orderbook deployed to:", order.address);
   console.log("=====APPROVALS======");
   console.log(await base.approve(order.address, '100000000000000000000000000000000'));
   console.log(await token.approve(order.address, '100000000000000000000000000000000'));
   console.log(await order.enumerateBook(true,5));
   console.log(await order.enumerateBook(false,5));
   console.log("=====ORDER long 10000, 10e15======");
   console.log(await order.order(100000,'1000000000000000000', true));
   console.log("=====ORDER short 10000, 10e15======");
   console.log(await order.order(100000,'1000000000000000000', false));
   console.log(await order.enumerateBook(true,5));
   console.log(await order.enumerateBook(false,5));
   console.log("=====ORDER short 20000, 10e15======");
   console.log(await order.order(200000,'1000000000000000000', false));
   console.log("=====ORDER short 30000, 10e15======");
   console.log(await order.order(300000,'1000000000000000000', false));
   console.log("=====ORDER long 10000, 10e15======");
   console.log(await order.order(100000,'1000000000000000000', true));
   console.log(await order.enumerateBook(true,5));
   console.log(await order.enumerateBook(false,5));
   console.log("=====ORDER long 15000, 10e15======");
   console.log(await order.order(150000,'1000000000000000000', true));
   console.log(await order.enumerateBook(true,5));
   console.log(await order.enumerateBook(false,5));
   console.log("=====ORDER long 27000, 10e16======");
   console.log(await order.order(270000,'100000000000000000000', true));
   console.log(await order.enumerateBook(true,5));
   console.log(await order.enumerateBook(false,5));
   console.log("=====ORDER short 25000, 10e16======");
   console.log(await order.order(250000,'1000000000000000000000000', false));
   console.log(await order.enumerateBook(true,5));
   console.log(await order.enumerateBook(false,5));
} 

main()
   .then(() => process.exit(0))
   .catch(error => { 
      console.error(error);     process.exit(1);  
   });
