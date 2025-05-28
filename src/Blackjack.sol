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
        setFlag(game.statusFlags, FLAG_ACTIVE);
        game.bet = uint88(msg.value);
        game.statusFlags = 0;
        game.remainingCards = 52;

        requestId = s_vrfCoordinator.requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEY_HASH,
            subId: s_subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        })

    );

    }

    function drawCard(Game storage game, uint256 randomWord) internal returns (uint8) {
        require(game.remainingCards > 0, "Deck is empty");

        uint8 index = uint8(randomWord % game.remainingCards);

        uint8 card = game.cardMap[index];
        if (card == 0 && index != 0) {
            card = index;
        }

        uint8 lastCard = game.cardMap[game.remainingCards - 1];
        if (lastCard == 0 && game.remainingCards - 1 != 0) {
            lastCard = game.remainingCards - 1;
        }

        game.cardMap[index] = lastCard;
        game.remainingCards--;

        return card;
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
        return (flags & (1 << bit)) != 0;
    }

    /*
     * @dev Sets a specific status flag in the provided bitfield.
     * @param flags The current uint8 flag field representing game status.
     * @param bit The index (0-based) of the bit to set.
     * @return The updated flag field with the specified bit set.
    */
    function setFlag(uint8 flags, uint8 bit) internal pure returns (uint8) {
        return flags | (1 << bit);
    }

    /*
     * @dev Clears (unsets) a specific status flag in the provided bitfield.
     * @param flags The current uint8 flag field representing game status.
     * @param bit The index (0-based) of the bit to clear.
     * @return The updated flag field with the specified bit cleared.
    */

    function clearFlag(uint8 flags, uint8 bit) internal pure returns (uint8) {
        return flags & ~(1 << bit);
    }



}   