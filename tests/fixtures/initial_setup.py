import boa
import os
import pytest
from tests.utils.util_tokens import mint_for_testing

AMT_USD = 10 ** 4
AMT_ETH = 10 ** 1
AMT_BTC = 10 ** 0
AMT_OTHER = 10 ** 6


@pytest.fixture
def initial_setup_forked(curve_assistant_contract, deployer, token_contracts, forked_chain):
    print('Using deployer account:', deployer)
    print('Using cll_contract:', curve_assistant_contract)
    print('Using contracts:', token_contracts)
    print(os.getcwd())
    # first set native token balance
    boa.env.set_balance(deployer, int(AMT_ETH))
    # then add other token balances
    for key in token_contracts:
        AMT_TO_MINT = 0
        if 'usd' in key.lower():
            AMT_TO_MINT = AMT_USD * 10 ** token_contracts[key].decimals()
        elif 'eth' in key.lower():
            AMT_TO_MINT = AMT_ETH * 10 ** token_contracts[key].decimals()
        elif 'btc' in key.lower():
            AMT_TO_MINT = AMT_BTC * 10 ** token_contracts[key].decimals()
        else:
            AMT_TO_MINT = AMT_OTHER * 10 ** token_contracts[key].decimals()
        mint_for_testing(token_contracts[key], deployer, AMT_TO_MINT)
        print('Minted %4.1f %s to %s' % (AMT_TO_MINT / 10 ** token_contracts[key].decimals(), key, deployer))
        # multiple asserts in one test is bad practice, but we want all balances be correctly set at once
        assert token_contracts[key].balanceOf(deployer) == AMT_TO_MINT



