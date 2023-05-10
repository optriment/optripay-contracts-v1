// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/Marketplace.sol";

contract MarketplaceScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MyToken myToken = new MyToken(10000000 * (10 ** 6));

        new Marketplace(address(myToken), 3);
    }
}
