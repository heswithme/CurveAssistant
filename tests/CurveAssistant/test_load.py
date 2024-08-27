# import boa
# import pytest
# import os

# from utils.util_contracts import load_contract
# from utils.util_tokens import get_token_balance
# pytestmark = pytest.mark.usefixtures("initial_setup_forked")

# ########################
# # This test is separate only for gas profiling
# # it partially duplicates functionality of test_main.py
# ########################

# @pytest.mark.gas_profile
# def test_load_liq(deployer, curve_assistant_contract, token_contracts, forked_chain):
#     pools_list = ['0x7f86bf177dd4f3494b841a37e810a34dd56c829b', # tricrypto-ng USDC/WBTC/WETH
#                   '0xd51a44d3fae010294c616388b506acda1bfaae46', # Curve.fi: USDT/WBTC/WETH Pool (old)
#                   '0xf5f5b97624542d72a9e06f04804bf81baa15e2b4', # tricrypto-ng USDT/WBTC/WETH
#                 #   '0x4ebdf703948ddcea3b11f675b4d1fba9d2414a14', # tricrv (crvUSD/WETH/CRV)
#                   ] 
#     coins_list = []
#     coins_amounts = []
#     # prepare approvals, populate input arrays (we use all balance and all tokens deployed)
#     N_REP = 100
#     for token_contract in token_contracts.values():
#         print(f'Balance of {token_contract.name()} ({token_contract.address}): deployer: {token_contract.balanceOf(deployer)}, contract: {token_contract.balanceOf(curve_assistant_contract)}', )
#         with boa.env.prank(deployer):
#             token_contract.approve(curve_assistant_contract.address, 0, sender = deployer)
#             token_contract.approve(curve_assistant_contract.address, token_contract.balanceOf(deployer), sender = deployer)
#             # print('current allowance:', contract.allowance(deployer, curve_assistant_contract.address))
#             coins_list.append(token_contract.address)
#             coins_amounts.append(token_contract.balanceOf(deployer)//N_REP)
#     for i in range(N_REP):
#         with boa.env.prank(deployer):
#             try:
#                 res_load = curve_assistant_contract.load_coins_to_pools(coins_list, coins_amounts, pools_list, sender = deployer)
#             except Exception as e:
#                 print(e)
#                 res_load = None
#             print(res_load)
#         assert res_load is not None  # we check that function did not revert
    
#     # print token balances
#     for token_contract in token_contracts.values():
#         print(f'Balance of {token_contract.name()} ({token_contract.address}): deployer: {token_contract.balanceOf(deployer)}, contract: {token_contract.balanceOf(curve_assistant_contract)}', )
