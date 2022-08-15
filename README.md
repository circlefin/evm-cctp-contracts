# evm-bridge-contracts

## Prerequisites
### Install Foundry
**Option A**:

Install Foundry CLI from official [website](https://book.getfoundry.sh/getting-started/installation.html#on-linux-and-macos. ).

**Option B**: 

Use Docker to run Foundry commands. Run `make build` to build Foundry docker image. Then run `docker run --rm foundry "<COMMAND>"` to run any [forge](https://book.getfoundry.sh/reference/forge/), [anvil](https://book.getfoundry.sh/reference/anvil/) or [cast](https://book.getfoundry.sh/reference/cast/) commands. There are some pre defined commands avaialble in `Makefile` for testing and deploying contract on `anvil`. More info on Docker and Foundry [here](https://book.getfoundry.sh/tutorials/foundry-docker).

### Install dependencies
- Run `git submodule update --init --recursive` to update/download all libraries.
- Run `yarn install` to install any additional dependencies.

## Testing
### Unit tests
Run `forge test` to run test using installed forge cli or `make test` to run tests in docker container.

### Run unit tests with debug logs
Log level is controlled by the -v flag. For example, `forge test -vv` displays console.log() statements from within contracts. Highest verbosity is -vvvvv. More info: https://book.getfoundry.sh/forge/tests.html#logs-and-traces. Contracts that use console.log() must import lib/forge-std/src/console.sol.

### Integration tests
Run `make anvil-test` to setup `anvil` test node in docker container and run integration tests. There is an example in `anvil/` folder

### Linting
Run `yarn lint` to lint all `.sol` files in the `src` and `test` directories.
