// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {CasinoChip} from "./CasinoChip.sol";
import {MockDAI} from "./MockDAI.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// NOTE
/// If this contract accept multiple tokens, i need a way to convert tokens value to chip token 
// if a user deposit 1 eth, worth 2k$, and he gets 2000 chip, a user depositing 1 DAI, should get 1 chip
// So, does my chip is worth is always set to 1$, or i use price feeds to convert the value of the tokens deposited ? 

contract CasinoBank {

    CasinoChip public immutable casinoChip;

    //////////////////////////
    //        EVENTS        //
    //////////////////////////

    event CasinoBank__Deposit(address indexed from, address indexed token, uint256 indexed amount);
    event CasinoBank__Withdrawal(address indexed to, address indexed token, uint256 indexed amount);

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
    function deposit(uint256 amount, address token) external payable returns (bool) {
        if (token == address(0)) {
            // ETH deposit
            require(msg.value > 0, "No ETH sent");
            require(amount == msg.value, "Amount mismatch");
            userBalances[msg.sender][address(0)] += msg.value;
            casinoChip.mint(msg.sender, amount);
            return true; // event instead of return ? 
        } else {
            // ERC20 deposit
            require(msg.value == 0, "Don't send ETH with token");
            require(whitelistedTokens[token], "Token not whitelisted");
            require(amount > 0, "Invalid amount");

            bool success = ERC20(token).transferFrom(msg.sender, address(this), amount);
            require(success, "Transfer failed");
            userBalances[msg.sender][token] += amount;
            casinoChip.mint(msg.sender, amount);
            return true; // event instead of return ? 
        }
    }

    function cashout(address token, uint256 amount) external returns (bool) {
        require(amount > 0, "Invalid amount");
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");

        // Update internal balance
        userBalances[msg.sender][token] -= amount;

        // Burn CasinoChip tokens (1:1 with value)
        casinoChip.burn(msg.sender, amount);

        if (token == address(0)) {
            // ETH
            (bool sent, ) = msg.sender.call{value: amount}("");
            require(sent, "ETH transfer failed");
        } else {
            // ERC-20
            bool success = ERC20(token).transfer(msg.sender, amount);
            require(success, "ERC20 transfer failed");
        }

        emit CasinoBank__Withdrawal(msg.sender, token, amount);
        return true;
    }
    
    function addTokensToWhitelist(address token) external onlyOwner {
        require(whitelistedTokens[token] == false, "Token already whitelisted");
        require(token != address(0), "No Address(0)");
        whitelistedTokens[token] = true;
        allTokens.push(token);
    }

    function removeTokensToWhitelist(address token) external onlyOwner {
        require(whitelistedTokens[token] == true, "Token not whitelisted");
        require(token != address(0), "No Address(0)");
        whitelistedTokens[token] = false;
        // Remove from array using swap-and-pop
        uint256 len = allTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (allTokens[i] == token) {
                allTokens[i] = allTokens[len - 1];
                allTokens.pop();
            }
        }
    }

}