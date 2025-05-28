// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
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
        mapping(uint8 => uint8) cardMap; // Sparse mapping to simulate the shuffled deck
        uint8 remainingCards;            // Decremented with each card draw

        uint256 requestId;      // VRF Chainlink  ID for random card picking
    }

    // === MAPPINGS ===

    mapping(address => Game) public games;               // Active player game
    mapping(uint256 => address) public requestIdToPlayer; // Player to VRF request

    // === GLOBAL STATE VARIABLE ===

    uint88 public constant MINIMUM_BET = 0.01 ether;
    uint88 public constant MAXIMUM_BET = 10 ether;

    // address public vrfCoordinator;
    // bytes32 public keyHash;
    // uint64 public subscriptionId;

    // === EXTERNAL FUNCTIONS ===

    function startGame() external payable  returns(uint8) {
        
        require(msg.value >= MINIMUM_BET, "Bet is below the minimum");
        require(msg.value <= MAXIMUM_BET, "Bet is above the maximum");  

        Game storage game = games[msg.sender]; 

        require(
            !isFlagSet(game.statusFlags, FLAG_ACTIVE),
            "Player is already in an active game"
        );

        game.player = msg.sender;
        game.statusFlags = setFlag(game.statusFlags, FLAG_ACTIVE); // game is now active
        game.bet = uint88(msg.value);
        game.remainingCards = 52;

        // VRF call to get the 2 player cards and the 1 shown dealer card
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 3, // The 3 cards asked when game starts
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        requestIdToPlayer[requestId] = msg.sender;
        game.requestId = requestId;

    } 

    // === VRF FUNCTIONS ===

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        Game storage game = games[requestIdToPlayer[requestId]];

        game.playerCards.push(drawCard(game, randomWords[0]));
        game.playerCards.push(drawCard(game, randomWords[1]));
        game.dealerCards.push(drawCard(game, randomWords[2]));

        delete requestIdToPlayer[requestId];
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

    /*
     * @dev Checks whether a specific status flag is set in the provided bitfield.
     * @param flags The current uint8 flag field representing game status.
     * @param bit The index (0-based) of the bit to check.
     * @return True if the specified bit is set, false otherwise.
    */

    function isFlagSet(uint8 flags, uint8 bit) internal pure returns (bool) {
        unchecked {
            return (flags & (1 << bit)) != 0;
        }
    }

    /*
     * @dev Sets a specific status flag in the provided bitfield.
     * @param flags The current uint8 flag field representing game status.
     * @param bit The index (0-based) of the bit to set.
     * @return The updated flag field with the specified bit set.
    */
    function setFlag(uint8 flags, uint8 bit) internal pure returns (uint8) {
        unchecked {
            return flags | (1 << bit);
        }
    }

    /*
     * @dev Clears (unsets) a specific status flag in the provided bitfield.
     * @param flags The current uint8 flag field representing game status.
     * @param bit The index (0-based) of the bit to clear.
     * @return The updated flag field with the specified bit cleared.
    */

    function clearFlag(uint8 flags, uint8 bit) internal pure returns (uint8) {
        unchecked {
            return flags | (1 << bit);
        }
    }



}   