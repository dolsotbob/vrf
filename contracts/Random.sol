// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract Random is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;

    uint256 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    uint256 public randomWord;
    uint256 public requestId;

    address public owner;

    constructor(
        address vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subId
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subId;
        owner = msg.sender;
    }

    function requestRandomWord() external {
        require(msg.sender == owner, "Only owner");
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            uint64(subscriptionId),
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(
        uint256 /* _requestId */,
        uint256[] memory randomWords
    ) internal override {
        randomWord = randomWords[0];
    }
}
