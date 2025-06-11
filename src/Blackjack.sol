// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {CasinoChip} from "./CasinoChip.sol";

contract Blackjack is VRFConsumerBaseV2Plus, ReentrancyGuard {

    uint8 constant FLAG_ACTIVE        = 0;
    uint8 constant FLAG_PLAYER_STOOD = 1;
    uint8 constant FLAG_DEALER_DONE  = 2;

    struct Game {
        address player;
        uint88 bet;
        uint8 statusFlags;
        uint8[] playerCards;
        uint8[] dealerCards;
        mapping(uint8 => uint8) cardMap;
        uint8 remainingCards;
        uint256 requestId;
    }

    mapping(address => Game) public games;
    mapping(uint256 => address) public requestIdToPlayer;

    uint88 public constant MINIMUM_BET = 0.01 ether;    
    uint88 public constant MAXIMUM_BET = 10 ether;

    address public immutable vrfCoordinator;
    bytes32 public immutable KEY_HASH; // Replace with actual keyhash
    uint256 public immutable SUBSCRIPTION_ID;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant CALLBACK_GAS_LIMIT = 200000;

    CasinoChip public immutable chip;

    constructor(address _vrfCoordinator,  address _chip, uint256 _subId) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        vrfCoordinator = _vrfCoordinator;
        chip = CasinoChip(_chip);
        SUBSCRIPTION_ID = _subId;

    }

    function startGame() external payable nonReentrant {
        require(msg.value >= MINIMUM_BET && msg.value <= MAXIMUM_BET, "Invalid bet");
        Game storage game = games[msg.sender]; 
        require(!isFlagSet(game.statusFlags, FLAG_ACTIVE), "Already in game");

        // Transfer Chip form player to this contract 
        bool success = chip.transferFrom(msg.sender, address(this), betAmount);
        require(success, "Token transfer failed");

        game.player = msg.sender;
        game.bet = uint88(msg.value);
        game.statusFlags = setFlag(game.statusFlags, FLAG_ACTIVE);
        game.remainingCards = 52;

        requestCards(msg.sender, 3);
    }

    function hit() external nonReentrant {
        Game storage game = games[msg.sender]; 
        require(isFlagSet(game.statusFlags, FLAG_ACTIVE), "Not in game");
        require(!isFlagSet(game.statusFlags, FLAG_PLAYER_STOOD), "Already stood");
        requestCards(msg.sender, 1);
    }

    function stand() external {
        Game storage game = games[msg.sender]; 
        require(isFlagSet(game.statusFlags, FLAG_ACTIVE), "Not in game");
        require(!isFlagSet(game.statusFlags, FLAG_PLAYER_STOOD), "Already stood");

        game.statusFlags = setFlag(game.statusFlags, FLAG_PLAYER_STOOD);

        // Trigger dealer logic (first card now, others depending on fulfillment)
        requestCards(msg.sender, 1);
    }

    // === VRF FUNCTIONS ===
    function requestCards(address player, uint8 numCards) internal returns(uint256) {
        require(numCards > 0, "Zero cards");

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: numCards,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        requestIdToPlayer[requestId] = player;
        games[player].requestId = requestId;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address player = requestIdToPlayer[requestId];
        Game storage game = games[player];

        for (uint256 i = 0; i < randomWords.length; i++) {
            uint8 card = drawCard(game, randomWords[i]);
            if (!isFlagSet(game.statusFlags, FLAG_PLAYER_STOOD)) {
                game.playerCards.push(card);
            } else {
                game.dealerCards.push(card);

                if (dealerShouldDrawCard(game.dealerCards) && game.remainingCards > 0) {
                    requestCards(player, 1);
                } else {
                    game.statusFlags = setFlag(game.statusFlags, FLAG_DEALER_DONE);
                }
            }
        }
        game.requestId = 0;
        delete requestIdToPlayer[requestId];
    }

    /**
     * @dev Decode a unique card from the deck using a virtual "swap-on-pick" shuffle.
     * @param game The game context (storage).
     * @param randomWord The VRF-generated number used to select a card.
     * @return The card index in range [0, 51].
    */
    function drawCard(Game storage game, uint256 randomWord) internal returns (uint8) {
        if (game.remainingCards == 0) return 255; // invalid card (no require, VRF should not REVERT)

        // Pick a random index in the remaining deck
        uint8 index = uint8(randomWord % game.remainingCards);
        uint8 lastIndex = game.remainingCards - 1;

        // Resolve the actual card at that index (mapped or default)
        uint8 drawnCard = game.cardMap[index] != 0 ? game.cardMap[index] : index;
        uint8 lastCard = game.cardMap[lastIndex] != 0 ? game.cardMap[lastIndex] : lastIndex;

        // Simulate "removing" the drawn card by swapping it with the last remaining
        game.cardMap[index] = lastCard;

        // Don't leave a mapping at the last index if it was written
        if (index != lastIndex && game.cardMap[lastIndex] != 0) {
            delete game.cardMap[lastIndex];
        }

        game.remainingCards--;

        return drawnCard;
    }

    function resolveGame() external nonReentrant {
        Game storage game = games[msg.sender];
        require(isFlagSet(game.statusFlags, FLAG_ACTIVE), "No active game");
        require(isFlagSet(game.statusFlags, FLAG_PLAYER_STOOD), "Player has not stood");
        require(isFlagSet(game.statusFlags, FLAG_DEALER_DONE), "Dealer has not finished");

        uint8 playerValue = getHandValue(game.playerCards);
        uint8 dealerValue = getHandValue(game.dealerCards);

        uint88 payout;

        if (playerValue > 21) {
            // Player busts — no payout
            payout = 0;
        } else if (dealerValue > 21 || playerValue > dealerValue) {
            // Dealer busts or player wins
            payout = game.bet * 2;
            bool success = chip.transfer(msg.sender, payout);
            require(success, "Payout failed");
        } else if (dealerValue == playerValue) {
            // Draw — refund
            payout = game.bet;
            bool success = chip.transfer(msg.sender, payout);
            require(success, "Refund failed");
        }
        // else: Dealer wins — player loses bet (no refund)

        delete games[msg.sender];
    }


    // === HELPER FUNCTIONS ===

    function getHandValue(uint8[] memory cards) public pure returns (uint8) {
        uint8 total;
        uint8 aces;
        uint256 length = cards.length; // could cast to uint8 ?
        for (uint256 i = 0; i < length ; ) {
            uint8 cardRank = cards[i] % 13;
            
            if (cardRank == 0) { // Ace (0 % 13 = 0)
                aces++;
                total += 11;
            } else if (cardRank >= 10) { // Valet, Queen, King
                total += 10;
            } else {
                total += cardRank + 1;
            }
            
            unchecked { ++i; }
        }
        
        while (total > 21 && aces > 0) {
            total -= 10;
            unchecked { --aces; }
        }
        
        return total;
    }

    function dealerShouldDrawCard(uint8[] memory dealerCards) internal pure returns (bool) {
        return getHandValue(dealerCards) < 17;
    }


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
        return uint8(flags | (1 << bit));
    }

    /*
     * @dev Clears (unsets) a specific status flag in the provided bitfield.
     * @param flags The current uint8 flag field representing game status.
     * @param bit The index (0-based) of the bit to clear.
     * @return The updated flag field with the specified bit cleared.
    */
    function clearFlag(uint8 flags, uint8 bit) internal pure returns (uint8) {
        return uint8(flags & ~(1 << bit));
    }


    function getBet(address player) external view returns (uint88) {
        return games[player].bet;
    }

    function getStatusFlags(address player) external view returns (uint8) {
        return games[player].statusFlags;
    }

    function getPlayerCards(address player) external view returns (uint8[] memory) {
        return games[player].playerCards;
    }

    function getDealerCards(address player) external view returns (uint8[] memory) {
        return games[player].dealerCards;
    }

    function isInGame(address player) external view returns (bool) {
        return isFlagSet(games[player].statusFlags, FLAG_ACTIVE);
    }

    function getGameData(address _player) external view returns (
        uint88 bet,
        uint8 statusFlags,
        uint8 remainingCards
    ) {
        Game storage g = games[_player];
        return (g.bet, g.statusFlags, g.remainingCards);
    }

}


