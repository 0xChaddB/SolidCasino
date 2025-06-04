// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {CasinoChip} from "./CasinoChip.sol";

contract CasinoBank {

    CasinoChip public immutable casinoChip;

    //////////////////////////
    //        EVENTS        //
    //////////////////////////

    event CasinoBank__Deposit(address indexed from, address indexed token, uint256 indexed amount);

    // user => token => balance
    mapping(address => mapping(address => uint256)) public userBalances;
    
    mapping(address => bool) public whitelistedTokens;
    address[] public allTokens;

    //////////////////////////
    //      CONSTRUCTOR     //
    //////////////////////////

    constructor(address _chip) {
        casinoChip = CasinoChip(_chip);
    }

    // I may need to check the depositor address.... someone maybe could inflate their balance 
    function depositTokens(uint256 amount, address token) external payable returns (bool) {
        if (token == address(0)) {
            // ETH deposit
            require(msg.value > 0, "No ETH sent");
            require(amount == msg.value, "Amount mismatch");
            userBalances[msg.sender][address(0)] += msg.value;
            return true; // event instead of return ? 
        } else {
            // ERC20 deposit
            require(msg.value == 0, "Don't send ETH with token");
            require(whitelistedTokens[token], "Token not whitelisted");
            require(amount > 0, "Invalid amount");

            bool success = ERC20(token).transferFrom(msg.sender, address(this), amount);
            require(success, "Transfer failed");
            userBalances[msg.sender][token] += amount;
            return true; // event instead of return ? 
        }
    }

}