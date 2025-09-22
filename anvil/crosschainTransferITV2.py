from typing import List, Dict
from web3 import Web3
from eth_account import Account
import solcx
import unittest
import time
import requests
from eth_abi import encode
from crosschainTransferIT import addresses, keys

# Miscellaneous fixed values for contract deployment and configuration
eth_domain = 0
avax_domain = 1
max_message_body_size = 8192
message_version = 1
message_body_version = 1
minter_allowance = 1000
mint_amount = 100
max_burn_message_amount = 1000000
finality_threshold_executed = 1000
fee_executed = 5
min_fee = 1

# Message constants
nonce_index_start = 12
nonce_length = 32
finality_threshold_executed_start = 144
finality_threshold_executed_length = 4
fee_executed_index_start = (
    148 + 164
)  # 148 is the start of the messageBody; 164 is the feeExecuted index in BurnMessageV2
fee_executed_length = 32


def compile_source_file(
    file_path: str, contract_name: str, version: str = "0.7.6"
) -> Dict:
    """
    Takes in file path to a Solidity contract, contract name, and optional version params
    and returns a dictionary representing the compiled contract.
    """
    solcx.install_solc(version)
    solcx.set_solc_version(version)
    return solcx.compile_files(
        [file_path],
        output_values=["abi", "bin"],
        import_remappings={
            "@memview-sol/": "lib/memview-sol/",
            "@openzeppelin/": "lib/openzeppelin-contracts/",
            "ds-test/": "lib/ds-test/src/",
            "forge-std/": "lib/forge-std/src/",
        },
        allow_paths=["."],
    )[f"{file_path}:{contract_name}"]


class TestTokenMessengerWithUSDC(unittest.TestCase):
    def deploy_contract_from_source(
        self,
        file_path: str,
        contract_name: str,
        version: str = "0.7.6",
        libraries: Dict = {},
        constructor_args: List = [],
        caller="",
    ):
        """
        Takes in a Solidity contract file path, contract name and optional Solidity
        compiler version, dictionary of libraries to link, arguments for contract
        constructor, and caller address to compile, deploy, and construct a Solidity
        contract. Returns a web3 contract object representing the deployed contract.
        """
        # Compile
        contract_interface = compile_source_file(file_path, contract_name, version)

        # Deploy
        if caller:
            unsigned_tx = (
                self.w3.eth.contract(
                    abi=contract_interface["abi"],
                    bytecode=solcx.link_code(contract_interface["bin"], libraries),
                )
                .constructor(*constructor_args)
                .build_transaction(
                    {
                        "nonce": self.w3.eth.get_transaction_count(addresses[caller]),
                        "from": addresses[caller],
                    }
                )
            )

            signed_tx = self.w3.eth.account.sign_transaction(unsigned_tx, keys[caller])
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        else:
            tx_hash = (
                self.w3.eth.contract(
                    abi=contract_interface["abi"],
                    bytecode=solcx.link_code(contract_interface["bin"], libraries),
                )
                .constructor(*constructor_args)
                .transact()
            )

        self.confirm_transaction(tx_hash)

        # Retrieve address and deployed contract
        address = self.w3.eth.get_transaction_receipt(tx_hash)["contractAddress"]
        return self.w3.eth.contract(address=address, abi=contract_interface["abi"])

    def send_transaction(self, function_call, caller: str):
        """
        Takes in an initialized function call and a designated caller and builds,
        signs, and sends the transaction. Verifies the transaction was received.
        """
        unsigned_tx = function_call.build_transaction(
            {
                "nonce": self.w3.eth.get_transaction_count(addresses[caller]),
                "from": addresses[caller],
            }
        )
        signed_tx = self.w3.eth.account.sign_transaction(unsigned_tx, keys[caller])
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        self.confirm_transaction(tx_hash)

    def verify_balances(self, expected_eth_usdc_balance, expected_avax_usdc_balance):
        """
        Verifies that the USDC balances at the test eth_token_messenger_user and avax_token_messenger_user
        accounts matche the expected values.
        """
        assert (
            self.eth_usdc.functions.balanceOf(
                addresses["eth_token_messenger_user"]
            ).call()
            == expected_eth_usdc_balance
        )
        assert (
            self.avax_usdc.functions.balanceOf(
                addresses["avax_token_messenger_user"]
            ).call()
            == expected_avax_usdc_balance
        )

    def verify_fees_collected(self, expected_eth_fees, expected_avax_fees):
        """
        Verifies that the USDC balances at the eth_token_messenger_deployer and avax_token_messenger_deployer
        accounts matche the expected values.
        """
        assert (
            self.eth_usdc.functions.balanceOf(
                addresses["eth_token_messenger_deployer"]
            ).call()
            == expected_eth_fees
        )
        assert (
            self.avax_usdc.functions.balanceOf(
                addresses["avax_token_messenger_deployer"]
            ).call()
            == expected_avax_fees
        )

    def update_and_sign_emitted_message(self, message_bytes):
        """
        Inserts into emitted message the nonce, feeExecuted, and finalityThresholdExecuted fields, and then signs
        the message via the attester.
        """
        mutable_message_bytes = bytearray(message_bytes)
        mutable_message_bytes[nonce_index_start : nonce_index_start + nonce_length] = (
            Web3.keccak(text="nonce")
        )
        mutable_message_bytes[
            finality_threshold_executed_start : finality_threshold_executed_start
            + finality_threshold_executed_length
        ] = finality_threshold_executed.to_bytes(4, "big")
        mutable_message_bytes[
            fee_executed_index_start : fee_executed_index_start + fee_executed_length
        ] = fee_executed.to_bytes(32, "big")
        signable_bytes = bytes(mutable_message_bytes)
        attester_account = Account.from_key(keys["attester"])
        signed_bytes = attester_account.signHash(
            Web3.keccak(signable_bytes)
        ).signature
        return signable_bytes, signed_bytes

    def to_32byte_hex(self, address):
        """
        Converts a hex address to its zero-padded 32-byte representation.
        """
        return Web3.to_hex(Web3.to_bytes(hexstr=address).rjust(32, b"\0"))

    def confirm_transaction(self, tx_hash, timeout=30):
        """
        Waits until transaction receipt associated with tx_hash confirms completion.
        """
        counter = 0
        while counter < timeout:
            try:
                if self.w3.eth.get_transaction_receipt(tx_hash).status == 1:
                    return
            except:
                pass
            counter += 1
            time.sleep(1)

        raise RuntimeError(
            f"Transaction with hash {tx_hash} did not complete within {timeout} seconds"
        )

    def setUp(self):
        # Connect to node
        self.w3 = Web3(Web3.HTTPProvider("http://0.0.0.0:8545"))
        assert self.w3.is_connected()

        # Deploy and initialize USDC on ETH
        self.eth_usdc = self.deploy_contract_from_source(
            "lib/centre-tokens.git/contracts/v2/FiatTokenV2_1.sol",
            "FiatTokenV2_1",
            "0.6.12",
        )
        self.send_transaction(
            self.eth_usdc.functions.initialize(
                "USDC",
                "USDC",
                "USDC",
                0,
                addresses["eth_usdc_master_minter"],
                self.w3.eth.account.create().address,
                self.w3.eth.account.create().address,
                addresses["eth_usdc_master_minter"],
            ),
            "eth_usdc_master_minter",
        )
        self.send_transaction(
            self.eth_usdc.functions.initializeV2("USDC"), "eth_usdc_master_minter"
        )
        self.send_transaction(
            self.eth_usdc.functions.initializeV2_1(
                Web3.to_checksum_address("0xb794f5ea0ba39494ce839613fffba74279579268")
            ),
            "eth_usdc_master_minter",
        )

        # Deploy and initialize USDC on AVAX
        self.avax_usdc = self.deploy_contract_from_source(
            "lib/centre-tokens.git/contracts/v2/FiatTokenV2_1.sol",
            "FiatTokenV2_1",
            "0.6.12",
        )
        self.send_transaction(
            self.avax_usdc.functions.initialize(
                "USDC",
                "USDC",
                "USDC",
                0,
                addresses["avax_usdc_master_minter"],
                self.w3.eth.account.create().address,
                self.w3.eth.account.create().address,
                addresses["avax_usdc_master_minter"],
            ),
            "avax_usdc_master_minter",
        )
        self.send_transaction(
            self.avax_usdc.functions.initializeV2("USDC"), "avax_usdc_master_minter"
        )
        self.send_transaction(
            self.avax_usdc.functions.initializeV2_1(
                Web3.to_checksum_address("0xb794f5ea0ba39494ce839613fffba74279579268")
            ),
            "avax_usdc_master_minter",
        )

        # First, deploy TokenMessengerV2, MessageTransmitterV2 on ETH
        # Deploy each behind an AdminUpgradableProxy instance
        # Then, deploy TokenMinterV2
        eth_message_transmitter_impl = self.deploy_contract_from_source(
            "src/v2/MessageTransmitterV2.sol",
            "MessageTransmitterV2",
            constructor_args=[eth_domain, message_version],
            caller="eth_message_transmitter_deployer",
        )
        eth_message_transmitter_proxy = self.deploy_contract_from_source(
            "src/proxy/AdminUpgradableProxy.sol",
            "AdminUpgradableProxy",
            constructor_args=[
                eth_message_transmitter_impl.address,
                addresses["eth_message_transmitter_deployer"],
                b"",
            ],
            caller="eth_message_transmitter_deployer",
        )
        self.eth_message_transmitter = self.w3.eth.contract(
            address=eth_message_transmitter_proxy.address,
            abi=eth_message_transmitter_impl.abi,
        )
        self.send_transaction(
            self.eth_message_transmitter.functions.initialize(
                addresses["eth_message_transmitter_deployer"],
                addresses["eth_message_transmitter_deployer"],
                addresses["eth_message_transmitter_deployer"],
                addresses["eth_message_transmitter_deployer"],
                [addresses["attester"]],
                1,
                max_message_body_size,
            ),
            "eth_message_transmitter_deployer",
        )

        # TokenMinterV2 ETH
        self.eth_token_minter = self.deploy_contract_from_source(
            "src/v2/TokenMinterV2.sol",
            "TokenMinterV2",
            constructor_args=[addresses["eth_token_controller"]],
            caller="eth_token_minter_deployer",
        )

        # TokenMessengerV2 ETH
        eth_token_messenger_impl = self.deploy_contract_from_source(
            "src/v2/TokenMessengerV2.sol",
            "TokenMessengerV2",
            constructor_args=[
                eth_message_transmitter_proxy.address,
                message_body_version,
            ],
            caller="eth_token_messenger_deployer",
        )
        eth_token_messenger_proxy = self.deploy_contract_from_source(
            "src/proxy/AdminUpgradableProxy.sol",
            "AdminUpgradableProxy",
            constructor_args=[
                eth_token_messenger_impl.address,
                addresses["eth_token_messenger_deployer"],
                b"",
            ],
            caller="eth_token_messenger_deployer",
        )
        self.eth_token_messenger = self.w3.eth.contract(
            address=eth_token_messenger_proxy.address, abi=eth_token_messenger_impl.abi
        )
        self.send_transaction(
            self.eth_token_messenger.functions.initialize(
                {
                    "owner": addresses["eth_token_messenger_deployer"],
                    "rescuer": addresses["eth_token_messenger_deployer"],
                    "feeRecipient": addresses["eth_token_messenger_deployer"],
                    "denylister": addresses["eth_token_messenger_deployer"],
                    "tokenMinter": self.eth_token_minter.address,
                    "minFeeController": addresses["eth_token_messenger_deployer"],
                },
                min_fee,
                [],
                [],
            ),
            "eth_token_messenger_deployer",
        )

        # Repeat the above on AVAX
        avax_message_transmitter_impl = self.deploy_contract_from_source(
            "src/v2/MessageTransmitterV2.sol",
            "MessageTransmitterV2",
            constructor_args=[avax_domain, message_version],
            caller="avax_message_transmitter_deployer",
        )
        avax_message_transmitter_proxy = self.deploy_contract_from_source(
            "src/proxy/AdminUpgradableProxy.sol",
            "AdminUpgradableProxy",
            constructor_args=[
                avax_message_transmitter_impl.address,
                addresses["avax_message_transmitter_deployer"],
                b"",
            ],
            caller="avax_message_transmitter_deployer",
        )
        self.avax_message_transmitter = self.w3.eth.contract(
            address=avax_message_transmitter_proxy.address,
            abi=avax_message_transmitter_impl.abi,
        )
        self.send_transaction(
            self.avax_message_transmitter.functions.initialize(
                addresses["avax_message_transmitter_deployer"],
                addresses["avax_message_transmitter_deployer"],
                addresses["avax_message_transmitter_deployer"],
                addresses["avax_message_transmitter_deployer"],
                [addresses["attester"]],
                1,
                max_message_body_size,
            ),
            "avax_message_transmitter_deployer",
        )
        self.avax_token_minter = self.deploy_contract_from_source(
            "src/v2/TokenMinterV2.sol",
            "TokenMinterV2",
            constructor_args=[addresses["avax_token_controller"]],
            caller="avax_token_minter_deployer",
        )
        avax_token_messenger_impl = self.deploy_contract_from_source(
            "src/v2/TokenMessengerV2.sol",
            "TokenMessengerV2",
            constructor_args=[
                avax_message_transmitter_proxy.address,
                message_body_version,
            ],
            caller="avax_token_messenger_deployer",
        )
        avax_token_messenger_proxy = self.deploy_contract_from_source(
            "src/proxy/AdminUpgradableProxy.sol",
            "AdminUpgradableProxy",
            constructor_args=[
                avax_token_messenger_impl.address,
                addresses["avax_token_messenger_deployer"],
                b"",
            ],
            caller="avax_token_messenger_deployer",
        )
        self.avax_token_messenger = self.w3.eth.contract(
            address=avax_token_messenger_proxy.address,
            abi=avax_token_messenger_impl.abi,
        )
        self.send_transaction(
            self.avax_token_messenger.functions.initialize(
                {
                    "owner": addresses["avax_token_messenger_deployer"],
                    "rescuer": addresses["avax_token_messenger_deployer"],
                    "feeRecipient": addresses["avax_token_messenger_deployer"],
                    "denylister": addresses["avax_token_messenger_deployer"],
                    "tokenMinter": self.avax_token_minter.address,
                    "minFeeController": addresses["avax_token_messenger_deployer"],
                },
                min_fee,
                [eth_domain],
                [self.to_32byte_hex(self.eth_token_messenger.address)],
            ),
            "eth_token_messenger_deployer",
        )

        # configureMinter to add minters
        self.send_transaction(
            self.eth_usdc.functions.configureMinter(
                addresses["eth_usdc_master_minter"], minter_allowance
            ),
            "eth_usdc_master_minter",
        )
        self.send_transaction(
            self.avax_usdc.functions.configureMinter(
                addresses["avax_usdc_master_minter"], minter_allowance
            ),
            "avax_usdc_master_minter",
        )
        self.send_transaction(
            self.eth_usdc.functions.configureMinter(
                self.eth_token_minter.address, minter_allowance
            ),
            "eth_usdc_master_minter",
        )
        self.send_transaction(
            self.avax_usdc.functions.configureMinter(
                self.avax_token_minter.address, minter_allowance
            ),
            "avax_usdc_master_minter",
        )

        # addLocalTokenMessenger to minter contracts
        self.send_transaction(
            self.eth_token_minter.functions.addLocalTokenMessenger(
                self.eth_token_messenger.address
            ),
            "eth_token_minter_deployer",
        )
        self.send_transaction(
            self.avax_token_minter.functions.addLocalTokenMessenger(
                self.avax_token_messenger.address
            ),
            "avax_token_minter_deployer",
        )

        # setMaxBurnAmountPerMessage to token messenger contracts
        self.send_transaction(
            self.eth_token_minter.functions.setMaxBurnAmountPerMessage(
                self.eth_usdc.address, max_burn_message_amount
            ),
            "eth_token_controller",
        )
        self.send_transaction(
            self.avax_token_minter.functions.setMaxBurnAmountPerMessage(
                self.avax_usdc.address, max_burn_message_amount
            ),
            "avax_token_controller",
        )

        # linkTokenPair
        self.send_transaction(
            self.eth_token_minter.functions.linkTokenPair(
                self.eth_usdc.address,
                avax_domain,
                self.to_32byte_hex(self.avax_usdc.address),
            ),
            "eth_token_controller",
        )
        self.send_transaction(
            self.avax_token_minter.functions.linkTokenPair(
                self.avax_usdc.address,
                eth_domain,
                self.to_32byte_hex(self.eth_usdc.address),
            ),
            "avax_token_controller",
        )

        # addRemoteTokenMessenger on ETH; AVAX was configured through initialize()
        self.send_transaction(
            self.eth_token_messenger.functions.addRemoteTokenMessenger(
                avax_domain, self.to_32byte_hex(self.avax_token_messenger.address)
            ),
            "eth_token_messenger_deployer",
        )

    def test_crosschain_transfer(self):
        # Allocate 100 USDC each to avax_token_messenger_user and eth_token_messenger_user
        self.send_transaction(
            self.avax_usdc.functions.mint(
                addresses["avax_token_messenger_user"], mint_amount
            ),
            "avax_usdc_master_minter",
        )
        self.send_transaction(
            self.eth_usdc.functions.mint(
                addresses["eth_token_messenger_user"], mint_amount
            ),
            "eth_usdc_master_minter",
        )
        self.verify_balances(100, 100)
        self.verify_fees_collected(0, 0)

        # Approve USDC transfer from avax_token_messenger_user to avax_token_messenger
        self.send_transaction(
            self.avax_usdc.functions.approve(
                self.avax_token_messenger.address, mint_amount
            ),
            "avax_token_messenger_user",
        )

        # depositForBurn from avax_token_messenger_user to avax_token_messenger
        self.send_transaction(
            self.avax_token_messenger.functions.depositForBurn(
                mint_amount,
                eth_domain,
                self.to_32byte_hex(addresses["eth_token_messenger_user"]),
                self.avax_usdc.address,
                self.to_32byte_hex(
                    addresses["eth_token_messenger_user"]
                ),  # destinationCaller
                10,  # maxFee
                1000,  # minFinalityThreshold
            ),
            "avax_token_messenger_user",
        )
        self.verify_balances(100, 0)
        self.verify_fees_collected(0, 0)

        # parse MessageSent event emitted by avax_message_transmitter
        avax_message_sent_filter = (
            self.avax_message_transmitter.events.MessageSent.create_filter(
                fromBlock="0x0"
            )
        )
        avax_message, signed_avax_message = self.update_and_sign_emitted_message(
            avax_message_sent_filter.get_new_entries()[0]["args"]["message"]
        )

        # receiveMessage with eth_message_transmitter to eth_token_messenger_user
        self.send_transaction(
            self.eth_message_transmitter.functions.receiveMessage(
                avax_message, signed_avax_message
            ),
            "eth_token_messenger_user",
        )
        self.verify_balances(195, 0)
        self.verify_fees_collected(5, 0)

        # Approve USDC transfer from eth_token_messenger_user to eth_token_messenger
        self.send_transaction(
            self.eth_usdc.functions.approve(
                self.eth_token_messenger.address, mint_amount
            ),
            "eth_token_messenger_user",
        )

        # depositForBurn from eth_token_messenger_user to eth_token_messenger
        self.send_transaction(
            self.eth_token_messenger.functions.depositForBurn(
                mint_amount,
                avax_domain,
                self.to_32byte_hex(addresses["avax_token_messenger_user"]),
                self.eth_usdc.address,
                self.to_32byte_hex(
                    addresses["avax_token_messenger_user"]
                ),  # destinationCaller
                10,  # maxFee
                1000,  # minFinalityThreshold
            ),
            "eth_token_messenger_user",
        )
        self.verify_balances(95, 0)
        self.verify_fees_collected(5, 0)

        # parse MessageSent event emitted by eth_message_transmitter
        eth_message_sent_filter = (
            self.eth_message_transmitter.events.MessageSent.create_filter(
                fromBlock="0x0"
            )
        )
        eth_message, signed_eth_message = self.update_and_sign_emitted_message(
            eth_message_sent_filter.get_new_entries()[0]["args"]["message"]
        )

        # receiveMessage with avax_message_transmitter to avax_token_messenger_user
        self.send_transaction(
            self.avax_message_transmitter.functions.receiveMessage(
                eth_message, signed_eth_message
            ),
            "avax_token_messenger_user",
        )
        self.verify_balances(95, 95)
        self.verify_fees_collected(5, 5)


if __name__ == "__main__":
    unittest.main()
