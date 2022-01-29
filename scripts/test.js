// scripts/index.js 
async function main() { 
   const accounts = await ethers.provider.listAccounts(); 
   console.log(accounts);

     const [deployer] = await ethers.getSigners();

     console.log(
            "Deploying contracts with the account:",
            deployer.address
          );
     
     console.log("Account balance:", (await deployer.getBalance()).toString());

   const Faucet = await ethers.getContractFactory("Faucet");
   const faucet = await Faucet.attach("0x2036dDA8534c1C71fdeBFB60Ae2F1b203A3aeA85");
   console.log("Faucet deployed to:", faucet.address);

   const Token = await ethers.getContractFactory("TestERC20");
   const token = await Token.attach("0x4200000000000000000000000000000000000006");
   console.log("Token deployed to:", token.address);

   await token.transfer(deployer.address, 10000000 , {gasPrice:100000001});
   await faucet.setOperator(deployer.address , {gasPrice:100000001});
   await faucet.distribute(deployer.address, 10000000, {gasPrice:100000001} );

   //console.log(await factory.getPool(token1.address, token2.address,500));
} 

main()
   .then(() => process.exit(0))
   .catch(error => { 
      console.error(error);     process.exit(1);  
   });
