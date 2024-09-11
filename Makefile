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

simulate-deployv2:
	forge script scripts/v2/1_deploy.s.sol:DeployV2Script --rpc-url ${RPC_URL} --sender ${SENDER}

deployv2:
	forge script scripts/v2/1_deploy.s.sol:DeployV2Script --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-setup-second-attester:
	forge script scripts/v2/2_setupSecondAttester.s.sol:SetupSecondAttesterScript --rpc-url ${RPC_URL} --sender ${SENDER}

setup-second-attester:
	forge script scripts/v2/2_setupSecondAttester.s.sol:SetupSecondAttesterScript --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-setup-remote-resources:
	forge script scripts/v2/3_setupRemoteResources.s.sol:SetupRemoteResourcesScript --rpc-url ${RPC_URL} --sender ${SENDER}

setup-remote-resources:
	forge script scripts/v2/3_setupRemoteResources.s.sol:SetupRemoteResourcesScript --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

simulate-rotate-keys:
	forge script scripts/v2/4_rotateKeys.s.sol:RotateKeysScript --rpc-url ${RPC_URL} --sender ${SENDER}

rotate-keys:
	forge script scripts/v2/4_rotateKeys.s.sol:RotateKeysScript --rpc-url ${RPC_URL} --sender ${SENDER} --broadcast

anvil:
	docker rm -f anvil || true
	@${ANVIL} "anvil --host 0.0.0.0 -a 13 --code-size-limit 250000"	

anvil-test: anvil
	pip3 install -r requirements.txt
	python3 anvil/crosschainTransferIT.py

deploy-local:
	@docker exec anvil forge script anvil/scripts/${contract}.s.sol:${contract}Script --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

cast-call:
	@docker exec anvil cast call ${contract_address} "${function}" --rpc-url http://localhost:8545

cast-send:
	@docker exec anvil cast send ${contract_address} "${function}" --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
	
clean:
	@${FOUNDRY} "forge clean"

analyze:
	pip3 install -r requirements.txt
	slither .
