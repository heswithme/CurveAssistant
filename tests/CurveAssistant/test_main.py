import boa
import pytest
import os

from utils.util_contracts import load_contract
from utils.util_tokens import get_token_balance
pytestmark = pytest.mark.usefixtures("initial_setup_forked")


@pytest.mark.gas_profile
def test_load_unload_liq(deployer, curve_assistant_contract, token_contracts, forked_chain):
    pools_list = ['0x7f86bf177dd4f3494b841a37e810a34dd56c829b', # tricrypto-ng USDC/WBTC/WETH
                  '0xd51a44d3fae010294c616388b506acda1bfaae46', # Curve.fi: USDT/WBTC/WETH Pool (old)
                  '0xf5f5b97624542d72a9e06f04804bf81baa15e2b4', # tricrypto-ng USDT/WBTC/WETH
                #   '0x4ebdf703948ddcea3b11f675b4d1fba9d2414a14', # tricrv (crvUSD/WETH/CRV)
                  ] 
    coins_list = []
    coins_amounts = []
    # prepare approvals, populate input arrays (we use all balance and all tokens deployed)
    for token_contract in token_contracts.values():
        print(f'Balance of {token_contract.name()} ({token_contract.address}): deployer: {token_contract.balanceOf(deployer)}, contract: {token_contract.balanceOf(curve_assistant_contract)}', )
        with boa.env.prank(deployer):
            token_contract.approve(curve_assistant_contract.address, 0, sender = deployer)
            token_contract.approve(curve_assistant_contract.address, token_contract.balanceOf(deployer), sender = deployer)
            # print('current allowance:', contract.allowance(deployer, curve_assistant_contract.address))
            coins_list.append(token_contract.address)
            coins_amounts.append(token_contract.balanceOf(deployer))

    with boa.env.prank(deployer):
        try:
            res_load = curve_assistant_contract.load_coins_to_pools(coins_list, coins_amounts, pools_list, sender = deployer)
        except Exception as e:
            print(e)
            res_load = None
        print(res_load)
    assert res_load is not None  # we check that function did not revert
    
    # print token balances
    for token_contract in token_contracts.values():
        print(f'Balance of {token_contract.name()} ({token_contract.address}): deployer: {token_contract.balanceOf(deployer)}, contract: {token_contract.balanceOf(curve_assistant_contract)}', )

    ### unload_liq is also here, to 1) save time on initialisation, 2) check sequential execution  
    pool_coins = []
    for pool in pools_list:
        pool_contract = load_contract(pool)
        pool_coins.append([pool_contract.coins(i) for i in range(3)])
        lp_address = curve_assistant_contract.get_lp_token_for_pool(pool)
        lp_token_contract = load_contract(lp_address)
        print(f'Balance of {pool} LP token ({lp_token_contract.address}):', lp_token_contract.balanceOf(deployer))
        with boa.env.prank(deployer):
            lp_token_contract.approve(curve_assistant_contract.address, 0, sender = deployer)
            lp_token_contract.approve(curve_assistant_contract.address, lp_token_contract.balanceOf(deployer), sender = deployer)
    with boa.env.prank(deployer):
        try:
            res_unload = curve_assistant_contract.extract_liquidity(pools_list, sender = deployer)
        except Exception as e:
            print(e)
            res_unload = None
        print(res_unload)
        # flatten and exclude duplicates from pool_coins while preserving order
        coins_list = list(dict.fromkeys(item for sublist in pool_coins for item in sublist))
        for coin in coins_list:
            coin_contract = load_contract(coin)
            print(f'Balance of {coin_contract.name()} ({coin_contract.address}):', coin_contract.balanceOf(deployer)/10**coin_contract.decimals())
    assert res_unload is not None  # we check that function did not revert


@pytest.mark.gas_profile
def test_market_convert(deployer, curve_assistant_contract, token_contracts, forked_chain):
    pools_list = ['0x7f86bf177dd4f3494b841a37e810a34dd56c829b', # tricrypto-ng USDC/WBTC/WETH
                  '0xd51a44d3fae010294c616388b506acda1bfaae46', # Curve.fi: USDT/WBTC/WETH Pool (old)
                  '0xf5f5b97624542d72a9e06f04804bf81baa15e2b4', # tricrypto-ng USDT/WBTC/WETH
                  '0x4ebdf703948ddcea3b11f675b4d1fba9d2414a14', # tricrv (crvUSD/WETH/CRV)
                  ] 
    target_token = '0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E' #crvUSD #make sure its not minted in contracts.py fixture

    coins_list = []
    coins_amounts = []
    # prepare approvals, populate input arrays (we use all balance and all tokens deployed)
    for token_contract in token_contracts.values():
        print(f'Balance of {token_contract.name()} ({token_contract.address}): deployer: {token_contract.balanceOf(deployer)}, contract: {token_contract.balanceOf(curve_assistant_contract)}', )
        with boa.env.prank(deployer):
            token_contract.approve(curve_assistant_contract.address, 0, sender = deployer)
            token_contract.approve(curve_assistant_contract.address, token_contract.balanceOf(deployer), sender = deployer)
            # print('current allowance:', contract.allowance(deployer, curve_assistant_contract.address))
            coins_list.append(token_contract.address)
            coins_amounts.append(token_contract.balanceOf(deployer))
    with boa.env.prank(deployer):
        try:
            commit_value = curve_assistant_contract.commit_slippage_protection(coins_list, coins_amounts, pools_list, target_token, 10_0, sender=deployer)
            res_convert = curve_assistant_contract.convert_to_one(coins_list, coins_amounts, pools_list, target_token, 1, sender = deployer)
        except Exception as e:
            print(e)
            res_convert = None
    assert res_convert is not None  # we check that function did not revert
    
    # print token balances
    for token_contract in token_contracts.values():
        print(f'Balance of {token_contract.name()} ({token_contract.address}): deployer: {token_contract.balanceOf(deployer)}, contract: {token_contract.balanceOf(curve_assistant_contract)}', )
    # print target_coin balance
    print(f'Balance of target coin: deployer : {get_token_balance(target_token, deployer)}, contract: {get_token_balance(target_token, curve_assistant_contract)}')
    assert get_token_balance(target_token, deployer) > 0 # we check that target token balance is not zero, i.e. we swapped something