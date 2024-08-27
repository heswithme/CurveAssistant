import boa
import pytest
import os
from eth_utils import to_checksum_address
from tests.utils.util_contracts import load_contract


@pytest.fixture
def curve_assistant_deployer():
    return boa.load_partial("contracts/CurveAssistant.vy")


@pytest.fixture
def curve_assistant_contract(deployer, curve_assistant_deployer):
    with boa.env.prank(deployer):
        return curve_assistant_deployer.deploy()


@pytest.fixture
def token_contracts(forked_chain):
    addresses_dict = {
        "USDT":     '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        "USDC":     '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        # "DAI":      '0x6b175474e89094c44da98b954eedeac495271d0f',
        "WBTC":     '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599',
        "WETH":     '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
        # "CRV":      '0xD533a949740bb3306d119CC777fa900bA034cd52',
        # "crvUSD":   '0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E'
    }
    # Convert addresses to checksum format
    for key in addresses_dict.keys():
        addresses_dict[key] = to_checksum_address(addresses_dict[key])
    # Fetch contract data from Etherscan and create the contracts dictionary
    #contracts = {key: boa.from_etherscan(address, uri="https://api.etherscan.io/api", name=key, api_key=os.environ.get("ETHERSCAN_API_KEY_CS")) for key, address in addresses_dict.items()}
    # replaced with wrapper that caches abis not to hit etherscan on every test run
    contracts = {key: load_contract(address, name=key, api_key=os.environ.get("ETHERSCAN_API_KEY")) for key, address in addresses_dict.items()}
    return contracts




