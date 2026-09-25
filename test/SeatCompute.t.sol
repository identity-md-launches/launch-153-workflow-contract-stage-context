// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {SeatCompute} from "../src/SeatCompute.sol";

contract RejectingRecipient {
    fallback() external payable {
        revert("no callbacks");
    }
}

contract SeatComputeTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    SeatCompute internal token;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new SeatCompute();
    }

    function test_metadataAndExactSupply() public view {
        assertEq(token.name(), "Seat Compute");
        assertEq(token.symbol(), "COMPUTE");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_constructorEmitsMintToItsCaller() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), ALICE, SUPPLY);
        vm.prank(ALICE);
        SeatCompute deployed = new SeatCompute();
        assertEq(deployed.balanceOf(ALICE), SUPPLY);
        assertEq(deployed.balanceOf(address(this)), 0);
    }

    function test_transferEmitsExactValue() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), ALICE, 7 ether);
        assertTrue(token.transfer(ALICE, 7 ether));
        assertEq(token.balanceOf(ALICE), 7 ether);
        assertEq(token.balanceOf(address(this)), SUPPLY - 7 ether);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferFullSupplyAndReturn() public {
        assertTrue(token.transfer(ALICE, SUPPLY));
        assertEq(token.balanceOf(address(this)), 0);
        vm.prank(ALICE);
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_zeroTransferEmitsEvenWithNoBalance() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(ALICE, BOB, 0);
        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, 0));
        assertEq(token.balanceOf(BOB), 0);
    }

    function test_selfTransferDoesNotChangeBalance() public {
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferRejectsZeroRecipientEvenForZeroValue() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_insufficientBalanceRevertsWithoutMovingTokens() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 0, 1));
        vm.prank(ALICE);
        token.transfer(BOB, 1);
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), 0);
    }

    function test_approveEmitsAndReplacesAllowanceThenRevokes() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), ALICE, 123);
        assertTrue(token.approve(ALICE, 123));
        assertTrue(token.approve(ALICE, 17));
        assertEq(token.allowance(address(this), ALICE), 17);
        assertTrue(token.approve(ALICE, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 0, 1));
        vm.prank(ALICE);
        token.transferFrom(address(this), BOB, 1);
    }

    function test_approveRejectsZeroSpender() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 1);
    }

    function test_transferFromConsumesAllowanceExactlyOnce() public {
        token.approve(ALICE, 100);
        vm.prank(ALICE);
        assertTrue(token.transferFrom(address(this), BOB, 100));
        assertEq(token.allowance(address(this), ALICE), 0);
        assertEq(token.balanceOf(BOB), 100);
        assertEq(token.balanceOf(address(this)), SUPPLY - 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 0, 1));
        vm.prank(ALICE);
        token.transferFrom(address(this), BOB, 1);
        assertEq(token.balanceOf(BOB), 100);
    }

    function test_transferFromInfiniteAllowanceIsNotDecreased() public {
        token.approve(ALICE, type(uint256).max);
        vm.prank(ALICE);
        assertTrue(token.transferFrom(address(this), BOB, SUPPLY));
        assertEq(token.allowance(address(this), ALICE), type(uint256).max);
        assertEq(token.balanceOf(BOB), SUPPLY);
    }

    function test_transferFromInsufficientBalanceRestoresAllowance() public {
        vm.prank(ALICE);
        token.approve(address(this), 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 0, 100));
        token.transferFrom(ALICE, BOB, 100);
        assertEq(token.allowance(ALICE, address(this)), 100);
        assertEq(token.balanceOf(BOB), 0);
    }

    function test_transferFromInvalidRecipientRestoresAllowance() public {
        token.approve(ALICE, 100);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(ALICE);
        token.transferFrom(address(this), address(0), 100);
        assertEq(token.allowance(address(this), ALICE), 100);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_transferFromSelfStillNeedsAllowance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1));
        token.transferFrom(address(this), ALICE, 1);
    }

    function test_zeroTransferFromNeedsNoAllowanceButRejectsZeroSender() public {
        assertTrue(token.transferFrom(ALICE, BOB, 0));
        // OpenZeppelin checks the zero allowance owner before reaching its sender validation.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        token.transferFrom(address(0), BOB, 0);
    }

    function test_transferDoesNotInvokeRecipient() public {
        RejectingRecipient recipient = new RejectingRecipient();
        assertTrue(token.transfer(address(recipient), 5));
        assertEq(token.balanceOf(address(recipient)), 5);
    }

    function test_noMintBurnOrAdminSelectorsForAnyCaller() public {
        bytes[] memory calls = new bytes[](9);
        calls[0] = abi.encodeWithSignature("mint(address,uint256)", ALICE, SUPPLY);
        calls[1] = abi.encodeWithSignature("burn(uint256)", 1);
        calls[2] = abi.encodeWithSignature("transferOwnership(address)", ALICE);
        calls[3] = abi.encodeWithSignature("setMinter(address)", ALICE);
        calls[4] = abi.encodeWithSignature("upgradeTo(address)", ALICE);
        calls[5] = abi.encodeWithSignature("initialize(address)", ALICE);
        calls[6] = abi.encodeWithSignature("pause()");
        calls[7] = abi.encodeWithSignature("setFee(uint256)", 100);
        calls[8] = abi.encodeWithSignature("burnFrom(address,uint256)", address(this), 1);
        for (uint256 i; i < calls.length; ++i) {
            (bool deployerSucceeded,) = address(token).call(calls[i]);
            assertFalse(deployerSucceeded);
            vm.prank(ALICE);
            (bool outsiderSucceeded,) = address(token).call(calls[i]);
            assertFalse(outsiderSucceeded);
        }
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_rejectsETHAndUnknownCalls() public {
        vm.deal(address(this), 1 ether);
        (bool acceptedETH,) = address(token).call{value: 1 ether}("");
        assertFalse(acceptedETH);
        (bool unknownSucceeded,) = address(token).call(hex"12345678");
        assertFalse(unknownSucceeded);
        assertEq(address(token).balance, 0);
    }

    function testFuzz_transferConservesSupply(address recipient, uint256 amount) public {
        vm.assume(recipient != address(0) && recipient != address(this));
        amount = bound(amount, 0, SUPPLY);
        assertTrue(token.transfer(recipient, amount));
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_oversizedTransferRevertsAtomically(uint256 amount) public {
        amount = bound(amount, SUPPLY + 1, type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, amount)
        );
        token.transfer(ALICE, amount);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function testFuzz_partialTransferFromTracksAllowance(uint256 allowance, uint256 amount) public {
        amount = bound(amount, 0, allowance < SUPPLY ? allowance : SUPPLY);
        token.approve(ALICE, allowance);
        vm.prank(ALICE);
        assertTrue(token.transferFrom(address(this), BOB, amount));
        assertEq(token.balanceOf(BOB), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.allowance(address(this), ALICE), allowance == type(uint256).max ? allowance : allowance - amount);
    }
}
