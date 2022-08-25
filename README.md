# evm-bridge-contracts

## Prerequisites

### Install dependencies
- Run `git submodule update --init --recursive` to update/download all libraries.
- Run `yarn install` to install any additional dependencies.

### VSCode IDE Setup
- Install solidity extension https://marketplace.visualstudio.com/items?itemName=juanblanco.solidity
- Navigate to a .sol file 
- Right-click, select `Solidity: Change global compiler version (Remote)`

![](./pictures/Solidity-Change-Compiler.png)

- Select 0.7.6

![](./pictures/Solidity-Compiler-Version.png)

- Install solhint extension https://marketplace.visualstudio.com/items?itemName=idrabenia.solidity-solhint

### Install Foundry
Install Foundry CLI (forge 0.2.0) from official [website](https://book.getfoundry.sh/getting-started/installation.html#on-linux-and-macos. ).

- To install a specific verison, see [here](https://github.com/foundry-rs/foundry/blob/3f13a986e69c18ea19ce634fea00f4df6b3666b0/foundryup/README.md#usage).

## Testing
### Unit tests
Run `forge test` to run test using installed forge cli or `make test` to run tests in docker container.

### Run unit tests with debug logs
Log level is controlled by the -v flag. For example, `forge test -vv` displays console.log() statements from within contracts. Highest verbosity is -vvvvv. More info: https://book.getfoundry.sh/forge/tests.html#logs-and-traces. Contracts that use console.log() must import lib/forge-std/src/console.sol.

### Integration tests
Run `make anvil-test` to setup `anvil` test node in docker container and run integration tests. There is an example in `anvil/` folder

### Linting
Run `yarn lint` to lint all `.sol` files in the `src` and `test` directories.

### Continuous Integration using Github Actions
We use Github actions to run linter and all the tests. The workflow configuration can be found in [.github/workflows/ci.yml](.github/workflows/ci.yml)

### Alternative Installations

#### Docker + Foundry
Use Docker to run Foundry commands. Run `make build` to build Foundry docker image. Then run `docker run --rm foundry "<COMMAND>"` to run any [forge](https://book.getfoundry.sh/reference/forge/), [anvil](https://book.getfoundry.sh/reference/anvil/) or [cast](https://book.getfoundry.sh/reference/cast/) commands. There are some pre defined commands available in `Makefile` for testing and deploying contract on `anvil`. More info on Docker and Foundry [here](https://book.getfoundry.sh/tutorials/foundry-docker).

ℹ️ Note
- Some machines (including those with M1 chips) may be unable to build the docker image locally. This is a known issue.
