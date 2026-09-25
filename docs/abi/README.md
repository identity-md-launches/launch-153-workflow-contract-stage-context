# Contract interfaces

The JSON files are compiler-exported ABI arrays, including constructors, custom errors,
and events. They come from the pinned Solidity 0.8.26 build. Regenerate after source or
compiler-setting changes with `forge build && python3 scripts/artifacts.py`.

## SeatCompute

Nonpayable, zero-argument constructor. Emits `Transfer(address(0), msg.sender, 10^27)`.

| Function | Result / effect |
| --- | --- |
| `name()` / `symbol()` | `"Seat Compute"` / `"COMPUTE"` |
| `decimals()` | `uint8(18)` |
| `totalSupply()` | Always `10^27` minor units |
| `balanceOf(address)` | Balance in minor units |
| `allowance(address,address)` | Owner's remaining allowance for a spender |
| `transfer(address,uint256)` | Moves caller's tokens; returns `true`, emits `Transfer` |
| `approve(address,uint256)` | Sets caller's allowance; returns `true`, emits `Approval` |
| `transferFrom(address,address,uint256)` | Spends caller's allowance and moves tokens; returns `true`, emits `Transfer` |

Amounts use 18 decimal places. Insufficient balance/allowance and invalid zero addresses
revert with OpenZeppelin ERC-6093 errors in the ABI. Zero-value transfers between valid
addresses succeed and emit `Transfer`. Finite allowance is reduced on `transferFrom`;
maximum `uint256` allowance is not. OpenZeppelin v5 does not emit `Approval` when spending
allowance, so query `allowance()` for current values. Mint/burn/admin functions are absent.

## ComputeProject

Nonpayable constructor `(address token_)` takes the previously deployed token. If its
address has no code, reverts `InvalidToken(address)`. Configuration cannot change.

| Function | Result |
| --- | --- |
| `token()` | Immutable launch token address |
| `version()` | `uint256(1)` |
| `siteLabel()` | `"imd-compute"`, a logical label, not a content hash or URL |

There are no mutating methods or events. Unknown selectors and normal ETH transfers to
either contract revert. No initialization transaction is required or supported.
