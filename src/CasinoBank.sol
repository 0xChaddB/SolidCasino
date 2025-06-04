// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {CasinoChip} from "./CasinoChip.sol";

contract CasinoBank {

    CasinoChip public immutable casinoChip;

    constructor(address _chip) {
        casinoChip = CasinoChip(_chip);
    }




}