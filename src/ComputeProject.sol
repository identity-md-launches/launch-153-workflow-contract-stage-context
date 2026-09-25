// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Immutable identity/version stub for the imd-compute dashboard.
/// @dev No accounting, admin, initialization, or external calls. The site label is not an IPFS CID.
contract ComputeProject {
    error InvalidToken(address token);

    address public immutable token;
    uint256 public constant version = 1;
    string public constant siteLabel = "imd-compute";

    /// @param token_ The already-deployed launch token, resolved from $token by the launch service.
    /// @dev Code presence rejects missing dependencies; source/manifest review verifies token identity.
    constructor(address token_) {
        if (token_.code.length == 0) revert InvalidToken(token_);
        token = token_;
    }
}
