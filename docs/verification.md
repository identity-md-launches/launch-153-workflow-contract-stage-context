# Local verification evidence

Date: 2026-09-25. Toolchain: Forge 1.7.1 (`4072e48705af9d93e3c0f6e29e93b5e9a40caed8`),
Solidity 0.8.26, Cancun EVM, optimizer 200. Both metadata hash and appended CBOR are disabled.
The Foundry configuration enables offline mode and disables FFI and filesystem permissions.

## Delivered suite

The final clean verification is `forge clean` followed by `bash check.sh`. The script runs
`forge fmt --check`, `forge build`, `forge test`, and
`python3 scripts/artifacts.py --check`. All pass without network or RPC access.

- **34 tests passed, 0 failed, 0 skipped** across three suites: 22 token tests,
  10 companion/deployment tests, and two stateful invariants.
- Four fuzz tests each run **1,000 cases**. Each invariant runs **128 sequences of 64
  actions** (8,192 handler calls), with `fail_on_revert = true` and no handler reverts.
  Expected rejected transfers are checked through low-level calls, allowing the invariant
  to verify that balances and allowances remain unchanged.
- The independent action model checks balances and allowances after transfer, approval,
  delegated transfer, allowance overspend, and balance overspend sequences. A separate
  invariant sums all tracked balances and checks the exact fixed supply.
- ABI JSON arrays match rebuilt artifacts. All **36 vendored source/license files** match
  the checksums in `docs/dependencies.json`; the vendor directories contain no extra files.
- Forge's unchecked-transfer lint messages are limited to test statements immediately
  following `vm.expectRevert`; those intentionally assert a failure rather than a return
  value. Successful transfers in the tests check their boolean return value.

| Contract | Creation bytecode bytes (without arguments) | Runtime bytes |
| --- | ---: | ---: |
| SeatCompute | 2,601 | 1,709 |
| ComputeProject | 450 | 269 |

Both runtimes are below EIP-170's 24,576-byte bound. Runtime scans skip PUSH immediate
data and reject DELEGATECALL, CALLCODE, and SELFDESTRUCT.

Source SHA-256 after formatting:

```text
de13bdc1e228caee3319a77309248434a9b6699abb02c9d9ed8e3307bf0b5bba  src/SeatCompute.sol
b3c77805ad136c36ce7f7b39ce5f2e0a40df18d993746a89f993239b4e987991  src/ComputeProject.sol
```

These are local reproduction identifiers, not signed attestations or service policy bindings.

## Supplied protected floor

The two supplied protected tests were copied unchanged into `test/scratch/protected/`
and run against the actual compiled creation code:

```sh
forge test --offline --match-path 'test/scratch/protected/*.t.sol'
```

Result: **8 passed, 0 failed, 0 skipped** (six token checks and two project checks).
Test inputs supplied through the harness's expected environment variables were:

- Chain `11155111`; local mock factory `0x000000000000000000000000000000000000faca`.
- Token creation code from `out/SeatCompute.sol/SeatCompute.json`; CREATE2 salt `bytes32(1)`.
- Expected supply `1000000000000000000000000000` and decimals `18`.
- One project; creation code from `out/ComputeProject.sol/ComputeProject.json` followed by
  the ABI-encoded predicted token address; CREATE2 salt `bytes32(2)`.
- Expected token/project addresses computed from each creation-code hash, salt and factory.

The tests checked whole supply retention during both constructors, exact transfers,
common admin/mint selectors, token decimals, runtime presence/size, and forbidden opcodes.
Scratch copies were removed after the run so ordinary `forge test` needs no environment
variables. The delivered suites retain equivalent deployment/supply/runtime coverage and
additional behavior tests. No protected input was edited.

## Review and limits

A separate fresh-context agent performed a bounded, read-only advisory source/ABI review.
It found no actionable contract, conservation, authorization, or factory compatibility
defect. It noted that this evidence document was pending; that documentation gap is now
resolved. The review did not execute tests, independently authenticate upstream dependency
provenance, or inspect a final manifest or production factory.

The build and tests use local execution only. They establish neither correctness of a
production factory/policy nor a completed deployment. The companion accepts any address
with code; final source/manifest review must bind its `$token` to this accepted token.
There is no custody, payout, lottery, verifiable randomness, or compute accounting subsystem
in these contracts. ERC-20 recipient callbacks do not exist, so token transfers do not
create a reentrancy entry point.

The independent contributor review of accepted source and `launch.json`, service source
publication/attestation/admission/deployment, and the required live dashboard/IPFS hosting
remain separate workflow stages. Local evidence carries no independent approval authority.
