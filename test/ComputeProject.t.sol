// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SeatCompute} from "../src/SeatCompute.sol";
import {ComputeProject} from "../src/ComputeProject.sol";

/// @dev Test-only CREATE2 factory with no initialization call.
contract LaunchProbe {
    error DeploymentFailed();

    function deploy(bytes memory creationCode, bytes32 salt) external payable returns (address deployed) {
        assembly ("memory-safe") {
            deployed := create2(callvalue(), add(creationCode, 32), mload(creationCode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();
    }
}

contract ComputeProjectTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    SeatCompute internal token;
    ComputeProject internal project;

    function setUp() public {
        vm.chainId(11155111);
        token = new SeatCompute();
        project = new ComputeProject(address(token));
    }

    function test_constructorFullyConfiguresImmutableProject() public view {
        assertEq(project.token(), address(token));
        assertEq(project.version(), 1);
        assertEq(project.siteLabel(), "imd-compute");
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(project)), 0);
        assertEq(token.allowance(address(this), address(project)), 0);
    }

    function test_rejectsMissingToken() public {
        vm.expectRevert(abi.encodeWithSelector(ComputeProject.InvalidToken.selector, address(0)));
        new ComputeProject(address(0));
    }

    function testFuzz_rejectsAddressWithoutCode(address missingToken) public {
        vm.assume(missingToken.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ComputeProject.InvalidToken.selector, missingToken));
        new ComputeProject(missingToken);
    }

    function test_factoryDeploymentKeepsWholeSupplyAndResolvesToken() public {
        LaunchProbe factory = new LaunchProbe();
        address launchedToken = factory.deploy(type(SeatCompute).creationCode, bytes32(uint256(1)));
        assertEq(SeatCompute(launchedToken).balanceOf(address(factory)), SUPPLY);
        address launchedProject = factory.deploy(
            abi.encodePacked(type(ComputeProject).creationCode, abi.encode(launchedToken)), bytes32(uint256(2))
        );
        assertEq(ComputeProject(launchedProject).token(), launchedToken);
        assertEq(ComputeProject(launchedProject).version(), 1);
        assertEq(SeatCompute(launchedToken).totalSupply(), SUPPLY);
        assertEq(SeatCompute(launchedToken).balanceOf(address(factory)), SUPPLY);
        assertEq(SeatCompute(launchedToken).balanceOf(address(this)), 0);
        assertEq(SeatCompute(launchedToken).balanceOf(launchedProject), 0);
    }

    function test_factoryRejectsWrongDependencyOrder() public {
        LaunchProbe factory = new LaunchProbe();
        vm.expectRevert(LaunchProbe.DeploymentFailed.selector);
        factory.deploy(
            abi.encodePacked(type(ComputeProject).creationCode, abi.encode(address(0x1234))), bytes32(uint256(2))
        );
    }

    function test_factoryRejectsDuplicateDeployment() public {
        LaunchProbe factory = new LaunchProbe();
        factory.deploy(type(SeatCompute).creationCode, bytes32(uint256(1)));
        vm.expectRevert(LaunchProbe.DeploymentFailed.selector);
        factory.deploy(type(SeatCompute).creationCode, bytes32(uint256(1)));
    }

    function test_bothConstructorsRejectETH() public {
        LaunchProbe factory = new LaunchProbe();
        vm.deal(address(this), 2);
        vm.expectRevert(LaunchProbe.DeploymentFailed.selector);
        factory.deploy{value: 1}(type(SeatCompute).creationCode, bytes32(uint256(1)));
        vm.expectRevert(LaunchProbe.DeploymentFailed.selector);
        factory.deploy{value: 1}(
            abi.encodePacked(type(ComputeProject).creationCode, abi.encode(address(token))), bytes32(uint256(2))
        );
    }

    function test_hasNoInitializationOrAdminPowers() public {
        bytes[] memory calls = new bytes[](5);
        calls[0] = abi.encodeWithSignature("initialize(address)", address(0xBEEF));
        calls[1] = abi.encodeWithSignature("setToken(address)", address(0xBEEF));
        calls[2] = abi.encodeWithSignature("transferOwnership(address)", address(0xBEEF));
        calls[3] = abi.encodeWithSignature("upgradeTo(address)", address(0xBEEF));
        calls[4] = abi.encodeWithSignature("setSiteLabel(string)", "other-site");
        for (uint256 i; i < calls.length; ++i) {
            (bool deployerSucceeded,) = address(project).call(calls[i]);
            assertFalse(deployerSucceeded);
            vm.prank(address(0xBEEF));
            (bool outsiderSucceeded,) = address(project).call(calls[i]);
            assertFalse(outsiderSucceeded);
        }
        assertEq(project.token(), address(token));
        assertEq(project.siteLabel(), "imd-compute");
    }

    function test_rejectsETHAndUnknownCalls() public {
        vm.deal(address(this), 1 ether);
        (bool acceptedETH,) = address(project).call{value: 1 ether}("");
        assertFalse(acceptedETH);
        (bool unknownSucceeded,) = address(project).call(hex"12345678");
        assertFalse(unknownSucceeded);
        assertEq(address(project).balance, 0);
    }

    function test_deployedRuntimeIsBoundedAndHasNoEscapeOpcodes() public view {
        _checkRuntime(address(token));
        _checkRuntime(address(project));
    }

    function _checkRuntime(address deployed) private view {
        bytes memory code = deployed.code;
        assertGt(code.length, 0);
        assertLe(code.length, 24_576);
        for (uint256 i; i < code.length; ++i) {
            uint8 op = uint8(code[i]);
            if (op >= 0x60 && op <= 0x7f) {
                i += op - 0x5f;
            } else {
                assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
            }
        }
    }
}
