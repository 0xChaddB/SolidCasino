// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.3.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts@1.3.0/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Blackjack is VRFConsumerBaseV2Plus, Ownable {

    // === BINARY FLAGS CONSTANTS ===
    uint8 constant FLAG_ACTIVE        = 0; // Game active
    uint8 constant FLAG_PLAYER_STOOD = 1; // Player "stand"
    uint8 constant FLAG_DEALER_DONE  = 2; // The dealer has finished his turn

    // === STRUCTURE PRINCIPALE D'UNE PARTIE ===
    struct Game {
        address player;         // Player
        uint88 bet;             // (max ≈ 309M ETH)
        uint8 statusFlags;      // Binary flags for game state

        uint8[] playerCards;    // Encoded player cards [0–51]
        uint8[] dealerCards;    // Encoded dealer cards [0–51]
        uint8[] AvailableCards; // Encoded available deck cards [0–51]

        uint256 requestId;      // VRF Chainlink  ID for random card picking
    }

    // === MAPPINGS ===

    mapping(address => Game) public games;               // Partie active par joueur
    mapping(uint256 => address) public requestIdToPlayer; // Lien entre VRF et joueur

    // === GLOBAL STATE VARIABLE ===

    // address public vrfCoordinator;
    // bytes32 public keyHash;
    // uint64 public subscriptionId;

    // === EXTERNAL FUNCTIONS ===

    function startGame() external payable  returns(uint8) {

        Game storage game = games[msg.sender];
        require(
            !isFlagSet(game.statusFlags, FLAG_ACTIVE),
            "Player is already in an active game"
        );

    }

    // === HELPER FUNCTIONS ===

    /*
        Game status is tracked using a single uint8 `statusFlags` variable,
        where each bit represents a boolean flag. This allows for efficient
        gas usage compared to using multiple separate boolean variables.

        The meaning of each flag bit is as follows:
        - FLAG_ACTIVE (bit 0):      The game is currently active.
        - FLAG_PLAYER_STOOD (bit 1):The player has chosen to stand.
        - FLAG_DEALER_DONE (bit 2): The dealer has completed their turn.

        To interact with flags, helper functions like `isFlagSet`, `setFlag`, and `clearFlag`
        are used to read or update individual bits safely and consistently.
    */

    function isFlagSet(uint8 flags, uint8 bit) internal pure returns (bool) {
        return (flags & (1 << bit)) != 0;
    }


}   