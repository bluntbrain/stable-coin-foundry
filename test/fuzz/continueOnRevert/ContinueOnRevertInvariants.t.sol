// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/// @title ContinueOnRevert Invariant Tests for DSCEngine
/// @author Ishan Lakhwani
/// @notice This contract tests invariants that should hold true even when functions revert
/// @dev Tests run with fail-on-revert=false to continue execution after reverts
/// @custom:invariants
/// 1. Protocol must never be insolvent/undercollateralized
/// 2. Users can't create stablecoins with a bad health factor
/// 3. Users can only be liquidated with a bad health factor

import { Test, StdInvariant } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { DSCEngine } from "../../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../../src/DecentralizedStableCoin.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { DeployDSC } from "../../../script/DeployDSC.s.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { ContinueOnRevertHandler } from "./ContinueOnRevertHandler.t.sol";

/// @notice Main invariant test contract for testing with continued execution after reverts
contract ContinueOnRevertInvariants is StdInvariant, Test {
    // State Variables with descriptive comments
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    // Price feed addresses
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;

    // Collateral token addresses
    address public weth;
    address public wbtc;

    // Test configuration constants
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Test amounts
    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    // Liquidation test variables
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    ContinueOnRevertHandler public handler;

    /// @notice Sets up the test environment with deployed contracts
    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        handler = new ContinueOnRevertHandler(dsce, dsc);
        targetContract(address(handler));
    }

    /// @notice Verifies protocol's total collateral value exceeds total DSC supply
    /// @dev This is the primary solvency check for the protocol
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(dsce));
        uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, wethDeposted);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);

        console.log("wethValue: %s", wethValue);
        console.log("wbtcValue: %s", wbtcValue);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    /// @notice Outputs a summary of all handler calls made during testing
    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
