// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ICurateFactory {
    struct TemplateRegistryParams {
        address templateRegistry;
        string[2] registrationTemplateParameters;
        string[2] removalTemplateParameters;
    }

    function deploy(
        address _governor,
        address _arbitrator,
        bytes calldata _arbitratorExtraData,
        address _connectedList,
        TemplateRegistryParams calldata _templateRegistryParams,
        uint256[4] calldata _baseDeposits,
        uint256 _challengePeriodDuration,
        address _relayerContract,
        string calldata _listMetadata
    ) external;

    event NewCurate(address indexed _address);
}

/// @notice Deploys a Curate v2 instance on arbitrumSepoliaDevnet (chainId 421614)
///         as a testnet prototype for ARGENTUM attestations. Non-production.
contract DeployCurateSepoliaPrototype is Script {
    // arbitrumSepoliaDevnet addresses (verified 2026-04-15)
    address constant CURATE_FACTORY = 0x24597B8918acA259337AdD2D2C2F07eafeaAf68e;
    address constant KLEROS_CORE    = 0x1Bd44c4a4511DbFa7DC1d5BC201635596E7200f9;
    address constant TEMPLATE_REG   = 0xc852F94f90E3B06Da6eCfB61d76561ECfb94613f;

    // Public URIs (github raw — testnet only; for mainnet we'd use IPFS)
    string constant BASE = "https://raw.githubusercontent.com/giskard09/argentum-core/main/docs/curate-sepolia/";

    function run() external {
        uint256 pk = vm.envUint("OWNER_PRIVATE_KEY");
        address governor = vm.addr(pk);

        // courtId=1 (general), minJurors=3
        bytes memory extraData = abi.encode(uint96(1), uint96(3));

        // Bonds: 0.001 ETH across all 4 (testnet — arbitrationCost is 3e-7 ETH)
        uint256[4] memory baseDeposits = [
            uint256(0.001 ether), // submissionBaseDeposit
            uint256(0.001 ether), // removalBaseDeposit
            uint256(0.001 ether), // submissionChallengeBaseDeposit
            uint256(0.001 ether)  // removalChallengeBaseDeposit
        ];

        ICurateFactory.TemplateRegistryParams memory tpl = ICurateFactory.TemplateRegistryParams({
            templateRegistry: TEMPLATE_REG,
            registrationTemplateParameters: [
                string(abi.encodePacked(BASE, "registrationTemplate.json")),
                "" // dataMappings — empty for prototype
            ],
            removalTemplateParameters: [
                string(abi.encodePacked(BASE, "removalTemplate.json")),
                ""
            ]
        });

        string memory listMetadata = string(abi.encodePacked(BASE, "listMetadata.json"));

        console2.log("Deployer:", governor);
        console2.log("CurateFactory:", CURATE_FACTORY);
        console2.log("KlerosCore:", KLEROS_CORE);
        console2.log("Challenge period (s):", uint256(3600));

        vm.startBroadcast(pk);
        ICurateFactory(CURATE_FACTORY).deploy(
            governor,
            KLEROS_CORE,
            extraData,
            address(0),
            tpl,
            baseDeposits,
            3600, // 1 hour challenge period (testnet)
            address(0),
            listMetadata
        );
        vm.stopBroadcast();

        console2.log("Deploy tx broadcast. Parse logs for NewCurate event to get instance address.");
    }
}
