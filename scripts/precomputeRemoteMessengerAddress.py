from dotenv import load_dotenv
from web3 import Web3

import argparse
import os
import rlp

def compute_address(sender, nonce):
    """
    Computes the address for a deployed contract given the address
    of the sender and the current nonce.
    """
    sender_as_bytes = Web3.toBytes(hexstr=sender)
    contract_address = Web3.toHex(Web3.keccak(rlp.encode([sender_as_bytes, nonce])))[-40:]
    return contract_address

def precompute_remote_token_messenger_address(remote_rpc_url):
    """
    Computes expected address for remote token messenger contract on the
    input remote_rpc_url and writes to the .env file. Requires 
    REMOTE_TOKEN_MESSENGER_DEPLOYER to be defined in the .env file.
    """
    remote_token_messenger_deployer = os.getenv(f"REMOTE_TOKEN_MESSENGER_DEPLOYER")
    remote_domain_node = Web3(Web3.HTTPProvider(remote_rpc_url))

    remote_token_messenger_deployer_nonce =  remote_domain_node.eth.get_transaction_count(remote_token_messenger_deployer)
    remote_token_messenger_address = compute_address(remote_token_messenger_deployer, remote_token_messenger_deployer_nonce)

    with open(".env", "a") as env_file:
        env_file.write(f"REMOTE_TOKEN_MESSENGER_ADDRESS=0x{remote_token_messenger_address}\n")

load_dotenv()
parser = argparse.ArgumentParser()
parser.add_argument("--REMOTE_RPC_URL", required=True, help="RPC URL for the remote chain")
args = parser.parse_args()
remote_rpc_url = args.REMOTE_RPC_URL
precompute_remote_token_messenger_address(remote_rpc_url)
