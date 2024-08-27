import boa
import os
import json
from eth_utils import to_checksum_address
from boa.contracts.abi.abi_contract import ABIContractFactory


def load_contract(contract_address, name=None, path='tests/utils/abi_cache', path_prefix = '', api_key=os.environ.get("ETHERSCAN_API_KEY")):
    addr = to_checksum_address(contract_address)
    try:
        # check if abi is already cached in folder
        with open(f"{path_prefix+path}/{addr.lower()}.json", 'r') as f:
            abi = json.load(f)
    except FileNotFoundError:
        # fetch abi from etherscan and save it to cache
        abi = boa.explorer.fetch_abi_from_etherscan(addr, api_key=api_key)
        with open(f"{path_prefix+path}/{addr.lower()}.json", 'w') as f:
            json.dump(abi, f, indent=4)
    return ABIContractFactory.from_abi_dict(abi, name=name).at(addr)
