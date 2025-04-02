// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Random is VRFConsumerBaseV2Plus {
    uint256 s_subscriptionId;
    address vrfCoordinator;
    bytes32 s_keyHash;
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    uint256 private constant ROLL_IN_PROGRESS = 999; // result가 999라면 아직 진행 중

    struct Roll {
        uint256 requestId;
        uint256 result;
        bool fulfilled;
    }
    mapping(address => Roll) public rolls; // 사용자 → Roll 정보
    mapping(uint256 => address) public requestToRoller; // requestId → 사용자 주소

    event DiceRolled(uint256 indexed requestId, address indexed roller);
    event DiceLanded(uint256 indexed requestId, uint256 indexed result);

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subId
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        vrfCoordinator = _vrfCoordinator;
        s_keyHash = _keyHash;
        s_subscriptionId = _subId;
    }

    function rollDice(
        address roller
    ) public onlyOwner returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        rolls[roller] = Roll(requestId, ROLL_IN_PROGRESS, false);
        requestToRoller[requestId] = roller;

        emit DiceRolled(requestId, roller);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        address roller = requestToRoller[requestId];
        require(roller != address(0), "Unknown requestId");

        uint256 result = (randomWords[0] % 100) + 1;

        rolls[roller].result = result;
        rolls[roller].fulfilled = true;

        emit DiceLanded(requestId, result);
    }

    function getResult(
        address roller
    ) external view returns (uint256 result, bool fulfilled) {
        Roll memory r = rolls[roller];
        require(r.requestId != 0, "No roll");
        require(r.result != ROLL_IN_PROGRESS, "Roll in progress");

        return (r.result, r.fulfilled);
    }
}
