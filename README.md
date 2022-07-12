# evm-bridge-contracts
## Install Foundry and dependencies
- Follow instructions at https://book.getfoundry.sh/getting-started/installation.html#on-linux-and-macos to install Foundry, Rust, and other dependencies. (Docker installation will be added in a follow up.)
- update git submodules: `git submodule update --init --recursive`

## Testing with Forge
### Run tests
`forge test`

### Run tests with debug logs
Log level is controlled by the -v flag. For example, `forge test -vv` displays console.log() statements from within contracts. Highest verbosity is -vvvvv. More info: https://book.getfoundry.sh/forge/tests.html#logs-and-traces. Contracts that use console.log() must import lib/forge-std/src/console.sol.