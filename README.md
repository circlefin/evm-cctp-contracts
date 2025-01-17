# evm-cctp-contracts

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

Install Foundry CLI (forge 0.2.0) from official [website](https://book.getfoundry.sh/getting-started/installation.html#on-linux-and-macos.).

- To install a specific version, see [here](https://github.com/foundry-rs/foundry/blob/3f13a986e69c18ea19ce634fea00f4df6b3666b0/foundryup/README.md#usage).

## Testing

### Unit tests

Run `forge test` to run test using installed forge cli or `make test` to run tests in docker container.

### Run unit tests with debug logs

Log level is controlled by the -v flag. For example, `forge test -vv` displays console.log() statements from within contracts. Highest verbosity is -vvvvv. More info: https://book.getfoundry.sh/forge/tests.html#logs-and-traces. Contracts that use console.log() must import lib/forge-std/src/console.sol.

### Integration tests

Run `make anvil-test` to setup `anvil` test node in docker container and run integration tests. There is an example in `anvil/` folder

### Linting

Run `yarn lint` to lint all `.sol` files in the `src` and `test` directories.

### Static analysis

Run `make analyze-{message-transmitter | message-transmitter-v2 | token-messenger-minter}` to set up Mythril dependency and run Mythril on all source files. If Mythril dependency has been installed, alternatively run `myth -v4 analyze $FILE_PATH --solc-json mythril.config.json --solv 0.7.6` to run static analysis on a `.sol` file at the given `$FILE_PATH`. Please note that this can take several minutes.

### Continuous Integration using Github Actions

We use Github actions to run linter and all the tests. The workflow configuration can be found in [.github/workflows/ci.yml](.github/workflows/ci.yml)

### Manual Triggering of the Olympix CI Workflow for Security Alerts
You can manually trigger the Olympix.ai Code Scanning workflow using the `workflow_dispatch` feature of GitHub Actions.
1. Click on the `Actions` tab.
2. In the left sidebar, select `Olympix Scan`.
3. Select the branch & click on the `Run workflow` button.

### Alternative Installations

#### Docker + Foundry

Use Docker to run Foundry commands. Run `make build` to build Foundry docker image. Then run `docker run --rm foundry "<COMMAND>"` to run any [forge](https://book.getfoundry.sh/reference/forge/), [anvil](https://book.getfoundry.sh/reference/anvil/) or [cast](https://book.getfoundry.sh/reference/cast/) commands. There are some pre defined commands available in `Makefile` for testing and deploying contract on `anvil`. More info on Docker and Foundry [here](https://book.getfoundry.sh/tutorials/foundry-docker).

ℹ️ Note

- Some machines (including those with M1 chips) may be unable to build the docker image locally. This is a known issue.

## Deployment

### V1

The contracts are deployed using [Forge Scripts](https://book.getfoundry.sh/tutorials/solidity-scripting). The script is located in [scripts/v1/deploy.s.sol](/scripts/v1/deploy.s.sol). Follow the below steps to deploy the contracts:

1. Add the below environment variables to your [env](.env) file
    - `MESSAGE_TRANSMITTER_DEPLOYER_KEY`
    - `TOKEN_MESSENGER_DEPLOYER_KEY`
    - `TOKEN_MINTER_DEPLOYER_KEY`
    - `TOKEN_CONTROLLER_DEPLOYER_KEY`
    - `ATTESTER_ADDRESS`
    - `USDC_CONTRACT_ADDRESS`
    - `REMOTE_USDC_CONTRACT_ADDRESS`
    - `MESSAGE_TRANSMITTER_PAUSER_ADDRESS`
    - `TOKEN_MINTER_PAUSER_ADDRESS`
    - `MESSAGE_TRANSMITTER_RESCUER_ADDRESS`
    - `TOKEN_MESSENGER_RESCUER_ADDRESS`
    - `TOKEN_MINTER_RESCUER_ADDRESS`
    - `TOKEN_CONTROLLER_ADDRESS`
    - `DOMAIN`
    - `REMOTE_DOMAIN`
    - `BURN_LIMIT_PER_MESSAGE`

    In addition, to link the remote bridge, one of two steps needs to be followed:
    - Add the `REMOTE_TOKEN_MESSENGER_DEPLOYER` address to your [env](.env) file and run [scripts/precomputeRemoteMessengerAddress.py](/scripts/precomputeRemoteMessengerAddress.py) with argument `--REMOTE_RPC_URL` for the remote chain, which will automatically add the `REMOTE_TOKEN_MESSENGER_ADDRESS` to the .env file
    - Manually add the `REMOTE_TOKEN_MESSENGER_ADDRESS` to your .env file.

2. Run `make simulate-deploy RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run. *Note: Use address from one of the private keys (used for deploying) above as `sender`. It is used to deploy the shared libraries that contracts use*
3. Run `make deploy RPC_URL=<RPC_URL> SENDER=<SENDER>` to deploy the contracts

### V2

#### Create2Factory

Deploy Create2Factory first if not yet deployed.

1. Add the environment variable `CREATE2_FACTORY_DEPLOYER_KEY` to your [env](.env) file.
2. Run `make simulate-deploy-create2-factory RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run.
3. Run
    ```make deploy-create2-factory RPC_URL=<RPC_URL> SENDER=<SENDER>```
  to deploy the Create2Factory.

#### V2 Implementation Contracts

Deploy the implementation contracts.

1. Add the following [env](.env) variables

    - `CREATE2_FACTORY_CONTRACT_ADDRESS`
    - `CREATE2_FACTORY_OWNER_KEY`
    - `TOKEN_MINTER_V2_OWNER_ADDRESS`
    - `TOKEN_MINTER_V2_OWNER_KEY`
    - `TOKEN_CONTROLLER_ADDRESS`
    - `DOMAIN`
    - `MESSAGE_BODY_VERSION`
    - `VERSION`

2. Run `make simulate-deploy-implementations-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run.

3. Run
    ```make deploy-implementations-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>```
  to deploy MessageTransmitterV2, TokenMinterV2, and TokenMessengerV2.

#### V2 Proxies

The proxies are deployed via `CREATE2` through Create2Factory. The scripts assumes the remote chains are EVM compatible and predicts that remote contracts will be deployed at the same addresses. Follow the below steps to deploy the contracts:

1. Replace the environment variables in your [env](.env) file with the following:

    Note: `REMOTE_DOMAINS`, `REMOTE_USDC_CONTRACT_ADDRESSES`, and `REMOTE_TOKEN_MESSENGER_V2_ADDRESSES` must all correspond 1:1:1 in order.

    - `USDC_CONTRACT_ADDRESS`
    - `TOKEN_CONTROLLER_ADDRESS`
    - `REMOTE_DOMAINS`
    - `REMOTE_USDC_CONTRACT_ADDRESSES`
    - `REMOTE_TOKEN_MESSENGER_V2_ADDRESSES`
    - `CREATE2_FACTORY_CONTRACT_ADDRESS`

    - `MESSAGE_TRANSMITTER_V2_IMPLEMENTATION_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_OWNER_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_PAUSER_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_RESCUER_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_ATTESTER_MANAGER_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_ATTESTER_1_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_ATTESTER_2_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_PROXY_ADMIN_ADDRESS`

    - `TOKEN_MINTER_V2_CONTRACT_ADDRESS`
    - `TOKEN_MINTER_V2_PAUSER_ADDRESS`
    - `TOKEN_MINTER_V2_RESCUER_ADDRESS`

    - `TOKEN_MESSENGER_V2_IMPLEMENTATION_ADDRESS`
    - `TOKEN_MESSENGER_V2_OWNER_ADDRESS`
    - `TOKEN_MESSENGER_V2_RESCUER_ADDRESS`
    - `TOKEN_MESSENGER_V2_FEE_RECIPIENT_ADDRESS`
    - `TOKEN_MESSENGER_V2_DENYLISTER_ADDRESS`
    - `TOKEN_MESSENGER_V2_PROXY_ADMIN_ADDRESS`

    - `DOMAIN`
    - `BURN_LIMIT_PER_MESSAGE`

    - `CREATE2_FACTORY_OWNER_KEY`
    - `TOKEN_CONTROLLER_KEY`
    - `TOKEN_MINTER_V2_OWNER_KEY`

2. Run `make simulate-deploy-proxies-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run.

3. Run `make deploy-proxies-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to deploy the contracts

4. ONLY perform steps 5-7 for additional remote resources NOT already configured above.

5. Replace the environment variables in your [env](.env) file with the following. We'll just add one remote resource (e.g. adding remote token messenger and remote usdc contract addresses) at a time, so just pick any and then repeat these steps. This will need to be repeated for each remote chain:

   - `TOKEN_MESSENGER_V2_OWNER_KEY`
   - `TOKEN_CONTROLLER_KEY`
   - `TOKEN_MESSENGER_V2_CONTRACT_ADDRESS`
   - `TOKEN_MINTER_V2_CONTRACT_ADDRESS`
   - `USDC_CONTRACT_ADDRESS`
   - `REMOTE_USDC_CONTRACT_ADDRESS`
   - `REMOTE_DOMAIN`

6. Run `make simulate-setup-remote-resources-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run of adding remote resources.

7. Run `make setup-remote-resources-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to setup the remote resources.

**[Remaining steps are only for mainnet]**

8. Replace the environment variables in your [env](.env) file with:

    - `MESSAGE_TRANSMITTER_V2_CONTRACT_ADDRESS`
    - `TOKEN_MESSENGER_V2_CONTRACT_ADDRESS`
    - `TOKEN_MINTER_V2_CONTRACT_ADDRESS`
    - `MESSAGE_TRANSMITTER_V2_OWNER_KEY`
    - `TOKEN_MESSENGER_V2_OWNER_KEY`
    - `TOKEN_MINTER_V2_OWNER_KEY`
    - `MESSAGE_TRANSMITTER_V2_NEW_OWNER_ADDRESS`
    - `TOKEN_MESSENGER_V2_NEW_OWNER_ADDRESS`
    - `TOKEN_MINTER_V2_NEW_OWNER_ADDRESS`
    - `NEW_TOKEN_CONTROLLER_ADDRESS`

9. Run `make simulate-rotate-keys-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run of rotating the keys.

10. Run `make rotate-keys-v2 RPC_URL=<RPC_URL> SENDER=<SENDER>` to rotate keys.

#### AddressUtilsExternal

Use Create2Factory to deploy the helper library to a deterministic address for easy integration.

1. Set the following [env](.env) variables:

    - `CREATE2_FACTORY_CONTRACT_ADDRESS`
    - `CREATE2_FACTORY_OWNER_KEY`

2. Run `make simulate-deploy-address-utils-external RPC_URL=<RPC_URL> SENDER=<SENDER>` to perform a dry run.

3. Run `make deploy-address-utils-external RPC_URL=<RPC_URL> SENDER=<SENDER>` to deploy.

## License

For license information, see LICENSE and additional notices stored in NOTICES.
