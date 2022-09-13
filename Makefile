.PHONY: build test anvil anvil-test anvil-deploy cast-call cast-send clean

FOUNDRY := docker run --rm foundry
ANVIL 	:= docker run -d -p 8545:8545 --name anvil --rm foundry

build:
	docker build --no-cache -f Dockerfile -t foundry .

test:
	@${FOUNDRY} "forge test -vv"

anvil:
	docker rm -f anvil || true
	@${ANVIL} "anvil --host 0.0.0.0 -a 11"
	

anvil-test: anvil
	pip3 install -r requirements.txt
	python3 anvil/circleBridgeIT.py

deploy:
	@docker exec anvil forge script anvil/scripts/${contract}.s.sol:${contract}Script --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

cast-call:
	@docker exec anvil cast call ${contract_address} "${function}" --rpc-url http://localhost:8545

cast-send:
	@docker exec anvil cast send ${contract_address} "${function}" --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
	
clean:
	@${FOUNDRY} "forge clean"
