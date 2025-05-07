// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// VRFConsumerBaseV2Plus: Chainlink VRF 기능을 제공받기 위한 기본 클래스
// VRFV2PlusClient: VRF 요청을 만들기 위한 라이브러리
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Random is VRFConsumerBaseV2Plus {
    uint256 s_subscriptionId; // Chainlink VRF 구독 ID
    address vrfCoordinator; // Chainlink VRF 코디네이터 주소; 여기서는 굳이 필요 없음
    bytes32 s_keyHash; // VRF keyHash: 난수 생성 시 사용되는 키
    uint32 callbackGasLimit = 40000; // 다른 컨트랙트에서도 가져다 쓸 수 있기 때문에..??
    uint16 requestConfirmations = 3; // 확정적인 값을 가지고 오겠다...??? 이 값이 크면 클수록 안정적이지만 응답 속도는 느려짐
    uint32 numWords = 1; // 하나의 값만 가지고 오겠다

    // result가 999라면 아직 난수 응답이 오지 않았음을 의미 (진행중이란 말임)
    uint256 private constant ROLL_IN_PROGRESS = 999;

    // VRF 요청 ID와 결과(난수값), 응답 수신 여부 저장
    struct Roll {
        uint256 requestId;
        uint256 result; // 난수
        bool fulfilled;
    }
    mapping(address => Roll) public rolls; // rolls: 사용자 주소 → 난수 요청 결과(Roll 구조체)
    mapping(uint256 => address) public requestToRoller; // requestId → 요청한 사용자 주소

    // 주사위 요청 시 발생하는 이벤트
    event DiceRolled(uint256 indexed requestId, address indexed roller);
    // 난수 응답이 도착하면 발생하는 이벤트
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

    // VRF에 난수 요청을 요청하고 요청 ID를 반환한다
    // 요청한 사용자의 정보는 rolls와 requestToRoller에 저장됩니다.
    // onlyOwner로 소유자만 호출 가능 (→ 테스트/게임 제어용으로 설계됨)
    // onlyOwner: 소유자만 rollDice() 호출 가능 → 다중 사용자 서비스에는 적합하지 않음 (변경 필요 가능성)
    function rollDice(
        address roller // 주사위를 굴리는 사용자의 주소
    ) public onlyOwner returns (uint256 requestId) {
        // VRF 요청 ID를 반환; 추적이나 테스트용으로 유용함
        // 핵심 로직: VRF에 난수 요청
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash, // VRF에서 사용할 고유 식별자 (난수 생성 알고리즘과 연관된 키)
                subId: s_subscriptionId, // Chainlink VRF를 사용할 수 있는 구독 ID (잔액이 있어야 동작)
                requestConfirmations: requestConfirmations, // 블록 컨펌 수: 보안성을 위해 몇 블록을 기다릴지 설정 (3 = 일반적)
                callbackGasLimit: callbackGasLimit, // Chainlink가 fulfillRandomWords() 호출 시 사용할 가스 한도
                numWords: numWords, // 요청할 난수의 개수 (여기선 1개 주사위)
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        // 해당 사용자의 주소에 대해, 요청 ID와 ROLL_IN_PROGRESS(999) 값을 저장합니다.
        // 이로써 사용자의 요청이 "진행 중"이라는 상태가 기록됩니다.
        rolls[roller] = Roll(requestId, ROLL_IN_PROGRESS, false);
        // Chainlink가 나중에 결과를 보낼 때, 해당 requestId를 사용자 주소로 다시 매핑할 수 있게 합니다.
        requestToRoller[requestId] = roller;

        //외부에서 이 트랜잭션 로그를 모니터링할 수 있도록 이벤트를 발생시킨다.
        // dApp 프론트엔드에서 이 이벤트를 활용하면, 사용자에게 주사위 요청이 전송되었음을 알려줄 수 있다
        emit DiceRolled(requestId, roller);
    }

    // 이 함수는 Chainlink VRF가 난수를 반환할 때 자동으로 실행되는 콜백함수 (우리가 실행시키는게 아님)
    // rollDice() 함수가 요청을 보내면, Chainlink는 나중에 이 함수로 응답을 돌려준다
    // 1~100 사이의 난수를 결과로 저장한다 ?????
    // 해당 사용자(roller)의 Roll을 업데이트하고 이벤트를 발생시킨다
    function fulfillRandomWords(
        // requestId: 어떤 난수 요청에 대한 응답인지 구분한다
        // randomWords: Chainlink가 전달하는 난수 배열 (numWords에 따라 크기 결정, 여기선 1개) <-- ???
        // internal이라 외부에서 호출할 수 없고, VRF 시스템에 의해 내부적으로만 호출됨
        // override: VRFConsumerBaseV2Plus의 추상 메서드를 구현한 것
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        // requestId를 기반으로 해당 난수를 요청한 사용자의 주소를 가져옵니다.
        // requestToRoller 매핑을 통해 누가 주사위를 굴렸는지 찾습니다.
        // 존재하지 않는 요청이면 실행을 중단합니다 (보안 강화).
        address roller = requestToRoller[requestId];
        require(roller != address(0), "Unknown requestId");

        // Chainlink는 256비트 정수형의 난수를 준다. 그걸 1~100 사이의 숫자로 변환한다.<--- ???
        uint256 result = (randomWords[0] % 100) + 1;

        // 사용자 주소를 키로 하는 rolls 매핑에서: (1) 주사위 결과(result) 저장;
        // (2) 요청이 완료되었음을 나타내는 fulfilled 값을 true로 설정
        rolls[roller].result = result;
        rolls[roller].fulfilled = true;

        // 주사위 굴리기 결과가 도착했음을 외부로 알리는 이벤트
        // 프론트엔드(dApp)는 이 이벤트를 통해 사용자에게 결과를 보여줄 수 있다
        emit DiceLanded(requestId, result);
    }

    // 사용자 주소로 결과를 확인할 수 있다
    // 아직 결과가 오지 않은 경우 오류를 반환한다
    function getResult(
        address roller
    ) external view returns (uint256 result, bool fulfilled) {
        Roll memory r = rolls[roller];
        require(r.requestId != 0, "No roll");
        require(r.result != ROLL_IN_PROGRESS, "Roll in progress"); // 난수 요청이 처리 중임을 나타냄 (상태 추적에 활용)

        return (r.result, r.fulfilled);
    }
}
