// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import {ERC4626, IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CasinoChip} from "./CasinoChip.sol";

contract CasinoBank is ERC4626 {

    CasinoToken public immutable casinoToken;

    constructor(address _token) {
        casinoToken = CasinoToken(_token);
    }

    
}