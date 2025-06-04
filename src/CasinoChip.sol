// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract CasinoChip is ERC20, AccessControl {

    bytes32 public constant CASINO_ROLE = keccak256("CASINO_ROLE");

    address public immutable casinoBank;

    constructor() ERC20("Casino Chip", "CHIP") {
        _grantRole(CASINO_ROLE, casinoBank);
        _grantRole(CASINO_ROLE, msg.sender); // governance 
    }

    function mint(address to, uint256 amount) external onlyRole(CASINO_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(CASINO_ROLE) {
        _burn(from, amount);
    }
}
