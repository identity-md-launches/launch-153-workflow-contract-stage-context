// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fixed-supply token for the Sepolia Identity MD seat compute project.
/// @dev The factory receives the entire supply. No post-deployment mint or privileged role exists.
contract SeatCompute is ERC20 {
    constructor() ERC20("Seat Compute", "COMPUTE") {
        _mint(msg.sender, 1_000_000_000 * 10 ** 18);
    }
}
