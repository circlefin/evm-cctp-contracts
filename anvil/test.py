from typing import Dict
from web3 import Web3
import solcx
import unittest
import time

def compile_source_file(file_path: str) -> Dict:
    solcx.install_solc(version='0.8.9')
    solcx.set_solc_version('0.8.9')
    with open(file_path, 'r') as f:
        source = f.read()
    return solcx.compile_source(source)

class TestContractUsingAnvil(unittest.TestCase):
    def setUp(self):
        # Connect to test node
        w3 = Web3(Web3.HTTPProvider('http://0.0.0.0:8545'))
        assert w3.isConnected()
    
        # Read and compile contract
        contract_source_path = 'anvil/Counter.sol'
        compiled_sol = compile_source_file(contract_source_path)
        _, contract_interface = compiled_sol.popitem()

        # Deploy contract
        tx_hash = w3.eth.contract(
            abi=contract_interface['abi'],
            bytecode=contract_interface['bin']
        ).constructor(10).transact()
        time.sleep(1)
        
        # Retrive address from tx receipt
        address = w3.eth.get_transaction_receipt(tx_hash)['contractAddress']
        
        # Retrived deployed contract using address
        self.counter = w3.eth.contract(
            address=address,
            abi=contract_interface['abi']
        )

    def test_increment(self):
        current = self.counter.functions.getCount().call()
        self.counter.functions.incrementCounter().transact()
        assert self.counter.functions.getCount().call() == current + 1
    
    def test_decrement(self):
        current = self.counter.functions.getCount().call()
        self.counter.functions.decrementCounter().transact()
        assert self.counter.functions.getCount().call() == current - 1

if __name__ == '__main__':
    unittest.main()
