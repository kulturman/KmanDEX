// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/KmanDEXRouter.sol";

contract DeployKmanDEXRouter is Script {
    address public constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant FEE_COLLECTOR = 0x4D4E65554F0b7CEE2bB00155F55b10cEE1580c71;

    function run() external {
        // Load private key from .env or other source
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        KmanDEXRouter router = new KmanDEXRouter(UNISWAP_ROUTER, FEE_COLLECTOR);

        console.log("KmanDEXRouter deployed at:", address(router));
        console.log("Factory deployed at:", address(router.factory()));

        vm.stopBroadcast();
    }
}
