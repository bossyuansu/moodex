//
// Just a standard hardhat-deploy deployment definition file!
const func = async (hre) => {
  const { ethers, deployments, getNamedAccounts } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const erc20 = await ethers.getContract('GLDToken', deployer);

  const result = await deploy('OrderBook', { // Replace `ERC20` with your contract's file name
    from: deployer,
    args: ["0xF02Efd44B57d143c38A329dD299683bf24Cf8aE0", 6, erc20.address, 18] ,
    log: true
  })

}

func.tags = ['OrderBook'] // Replace `ERC20` with your contract's file name
module.exports = func
