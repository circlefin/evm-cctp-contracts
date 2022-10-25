from dotenv import load_dotenv
from web3 import Web3

import os
import rlp

rpc_urls = {
    '0': "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", # Ethereum
    '1': "https://api.avax-test.network/ext/bc/C/rpc" # Avalanche
}

def compute_address(sender, nonce):
    """
    Computes the address for a deployed contract given the address
    of the sender and the current nonce.
    """
    sender_as_bytes = Web3.toBytes(hexstr=sender)
    contract_address = Web3.toHex(Web3.keccak(rlp.encode([sender_as_bytes, nonce])))[-40:]
    return contract_address

def precompute_remote_token_messenger_address():
    """
    Computes expected address for remote token messenger contract and writes to 
    the .env file. Requires REMOTE_DOMAIN and REMOTE_TOKEN_MESSENGER_DEPLOYER 
    to be defined in the .env file.
    """
    remote_domain = os.getenv("REMOTE_DOMAIN")
    remote_token_messenger_deployer = os.getenv(f"REMOTE_TOKEN_MESSENGER_DEPLOYER")
    remote_domain_node = Web3(Web3.HTTPProvider(rpc_urls[remote_domain]))

    remote_token_messenger_deployer_nonce =  remote_domain_node.eth.get_transaction_count(remote_token_messenger_deployer)
    remote_token_messenger_address = compute_address(remote_token_messenger_deployer, remote_token_messenger_deployer_nonce)

    with open(".env", "a") as env_file:
        env_file.write(f"REMOTE_TOKEN_MESSENGER_ADDRESS=0x{remote_token_messenger_address}\n")

load_dotenv()
precompute_remote_token_messenger_address()