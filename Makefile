.PHONY: build test anvil anvil-test anvil-deploy cast-call cast-send clean

FOUNDRY := docker run --rm foundry
ANVIL 	:= docker run -d -p 8545:8545 --name anvil --rm foundry

build:
	docker build --no-cache -f Dockerfile -t foundry .

test:
	@${FOUNDRY} "forge test -vv"

simulate-deploy:
	forge script scripts/v1/deploy.s.sol:DeployScript --rpc-url ${RPC_URL} --sender ${SENDER}

deploy:
	forge script scripts/v1/deploy.s.sol:DeployScript --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-deploy-implementations-v2:
	forge script scripts/v2/DeployImplementationsV2.s.sol:DeployImplementationsV2Script --rpc-url ${RPC_URL} --sender ${SENDER}

deploy-implementations-v2:
	forge script scripts/v2/DeployImplementationsV2.s.sol:DeployImplementationsV2Script --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-deploy-create2-factory:
	forge script scripts/DeployCreate2Factory.s.sol:DeployCreate2FactoryScript --rpc-url ${RPC_URL} --sender ${SENDER}

deploy-create2-factory:
	forge script scripts/DeployCreate2Factory.s.sol:DeployCreate2FactoryScript --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-deploy-proxies-v2:
	forge script scripts/v2/DeployProxiesV2.s.sol:DeployProxiesV2Script --rpc-url ${RPC_URL} --sender ${SENDER}

deploy-proxies-v2:
	forge script scripts/v2/DeployProxiesV2.s.sol:DeployProxiesV2Script --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-setup-remote-resources-v2:
	forge script scripts/v2/SetupRemoteResourcesV2.s.sol:SetupRemoteResourcesV2Script --rpc-url ${RPC_URL} --sender ${SENDER}

setup-remote-resources-v2:
	forge script scripts/v2/SetupRemoteResourcesV2.s.sol:SetupRemoteResourcesV2Script --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-rotate-keys-v2:
	forge script scripts/v2/RotateKeysV2.s.sol:RotateKeysV2Script --rpc-url ${RPC_URL} --sender ${SENDER}

rotate-keys-v2:
	forge script scripts/v2/RotateKeysV2.s.sol:RotateKeysV2Script --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-deploy-address-utils-external:
	forge script scripts/v2/DeployAddressUtilsExternal.s.sol:DeployAddressUtilsExternalScript --rpc-url ${RPC_URL} --sender ${SENDER}

deploy-address-utils-external:
	forge script scripts/v2/DeployAddressUtilsExternal.s.sol:DeployAddressUtilsExternalScript --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

anvil:
	docker rm -f anvil || true
	@${ANVIL} "anvil --host 0.0.0.0 -a 13 --code-size-limit 250000"

anvil-test: anvil
	pip3 install -r requirements.txt
	python anvil/crosschainTransferIT.py

anvil-test-v2: anvil
	pip3 install -r requirements.txt
	python anvil/crosschainTransferITV2.py

deploy-local:
	@docker exec anvil forge script anvil/scripts/${contract}.s.sol:${contract}Script --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

cast-call:
	@docker exec anvil cast call ${contract_address} "${function}" --rpc-url http://localhost:8545

cast-send:
	@docker exec anvil cast send ${contract_address} "${function}" --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

clean:
	@${FOUNDRY} "forge clean"

analyze-message-transmitter:
	pip3 install mythril==0.24.8
	myth -v4 analyze src/MessageTransmitter.sol --solc-json mythril.config.json --solv 0.7.6

analyze-message-transmitter-v2:
	pip3 install mythril==0.24.8
	myth -v4 analyze src/v2/MessageTransmitterV2.sol --solc-json mythril.config.json --solv 0.7.6

analyze-token-messenger-minter:
	pip3 install mythril==0.24.8
	myth -v4 analyze src/TokenMessenger.sol --solc-json mythril.config.json --solv 0.7.6
	myth -v4 analyze src/TokenMinter.sol --solc-json mythril.config.json --solv 0.7.6
	myth -v4 analyze src/v2/TokenMessengerV2.sol --solc-json mythril.config.json --solv 0.7.6
	myth -v4 analyze src/v2/TokenMinterV2.sol --solc-json mythril.config.json --solv 0.7.6
