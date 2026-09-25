// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {SeatCompute} from "../src/SeatCompute.sol";

contract TokenHandler is Test {
    SeatCompute public immutable token;
    address[4] public actors = [address(0x1001), address(0x1002), address(0x1003), address(0x1004)];
    uint256[4] public balances;
    uint256[4][4] public allowances;

    constructor(SeatCompute token_) {
        token = token_;
        balances[0] = 1_000_000_000_000_000_000_000_000_000;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        uint256 from = fromSeed % 4;
        uint256 to = toSeed % 4;
        amount = bound(amount, 0, balances[from]);
        vm.prank(actors[from]);
        assertTrue(token.transfer(actors[to], amount));
        balances[from] -= amount;
        balances[to] += amount;
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        uint256 owner = ownerSeed % 4;
        uint256 spender = spenderSeed % 4;
        vm.prank(actors[owner]);
        assertTrue(token.approve(actors[spender], amount));
        allowances[owner][spender] = amount;
    }

    function transferFrom(uint256 fromSeed, uint256 toSeed, uint256 spenderSeed, uint256 amount) external {
        uint256 from = fromSeed % 4;
        uint256 to = toSeed % 4;
        uint256 spender = spenderSeed % 4;
        uint256 allowed = allowances[from][spender];
        amount = bound(amount, 0, allowed < balances[from] ? allowed : balances[from]);
        vm.prank(actors[spender]);
        assertTrue(token.transferFrom(actors[from], actors[to], amount));
        if (allowed != type(uint256).max) allowances[from][spender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;
    }

    function overspendAllowance(uint256 ownerSeed, uint256 spenderSeed) external {
        uint256 owner = ownerSeed % 4;
        uint256 spender = spenderSeed % 4;
        uint256 allowed = allowances[owner][spender];
        if (allowed == type(uint256).max) return;
        vm.prank(actors[spender]);
        (bool succeeded,) =
            address(token).call(abi.encodeCall(token.transferFrom, (actors[owner], actors[spender], allowed + 1)));
        assertFalse(succeeded);
    }

    function overspendBalance(uint256 ownerSeed) external {
        uint256 owner = ownerSeed % 4;
        vm.prank(actors[owner]);
        (bool succeeded,) =
            address(token).call(abi.encodeCall(token.transfer, (actors[(owner + 1) % 4], balances[owner] + 1)));
        assertFalse(succeeded);
    }
}

contract SeatComputeInvariantTest is StdInvariant, Test {
    SeatCompute internal token;
    TokenHandler internal handler;

    function setUp() public {
        token = new SeatCompute();
        handler = new TokenHandler(token);
        assertTrue(token.transfer(handler.actors(0), token.totalSupply()));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = TokenHandler.transfer.selector;
        selectors[1] = TokenHandler.approve.selector;
        selectors[2] = TokenHandler.transferFrom.selector;
        selectors[3] = TokenHandler.overspendAllowance.selector;
        selectors[4] = TokenHandler.overspendBalance.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_exactSupplyAndConservation() public view {
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(sum, 1_000_000_000_000_000_000_000_000_000);
        assertEq(token.totalSupply(), sum);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
    }

    function invariant_balancesAndAllowancesMatchActionModel() public view {
        for (uint256 i; i < 4; ++i) {
            assertEq(token.balanceOf(handler.actors(i)), handler.balances(i));
            for (uint256 j; j < 4; ++j) {
                assertEq(token.allowance(handler.actors(i), handler.actors(j)), handler.allowances(i, j));
            }
        }
    }
}
