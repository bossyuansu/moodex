//
// Just a standard hardhat-deploy deployment definition file!
const func = async (hre) => {
  const { ethers, deployments, getNamedAccounts } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const result = await deploy('GLDToken', { // Replace `ERC20` with your contract's file name
    from: deployer,
    args: ["1000000000000000000000000000000000000"],
    log: true
  })

}

func.tags = ['GLDToken'] // Replace `ERC20` with your contract's file name
module.exports = func
