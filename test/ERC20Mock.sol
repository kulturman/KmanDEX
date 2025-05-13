// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "../lib/forge-std/src/console.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100_000_000);
    }
}
