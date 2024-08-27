# @version 0.4.0

"""
@title TriCryptoLiqLoader
@notice This module's main function is to spread input tokens across multiple pools.
If token is used in multiple pools, it is dispersed evenly across them. As a result, liquidity values in pools can be imbalanced.
"""

from ethereum.ercs import IERC20

import _TriCryptoHelpers as utils

# mappings used locally
coin_amounts: transient(HashMap[address, uint256]) # token address -> amount to use per pool

@deploy
def __init__():
    pass



@internal
def _load_liq_multiple_pools(
    coins_list: DynArray[address, utils.MAX_COINS],
    amounts_to_use: DynArray[uint256, utils.MAX_COINS],
    pool_contracts: DynArray[utils.CurveTriCryptoPool, utils.MAX_POOLS]
) -> bool:
    # populate hashmap (to avoid triple-nested loop)
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        self.coin_amounts[coins_list[i]] = amounts_to_use[i]

    # cycle through all pools
    for i: uint256 in range(len(pool_contracts), bound=utils.MAX_POOLS):
        pool_coins: address[utils.THREE] = utils._get_pool_coins(pool_contracts[i])
        # use hashmap instead of looping through all coins
        pool_amounts: uint256[utils.THREE] = [self.coin_amounts[pool_coins[0]], self.coin_amounts[pool_coins[1]], self.coin_amounts[pool_coins[2]]] # input amounts for add_liquidity
        add_something: bool = False

        # issue approvals
        for j: uint256 in range(utils.THREE):
            if pool_amounts[j] > 0:
                add_something = True
                assert utils.smart_approve(pool_coins[j], pool_contracts[i].address, pool_amounts[j]), "Approve failed!"

        # add liquidity if possible
        if add_something:
            min_lp_out: uint256 = staticcall pool_contracts[i].calc_token_amount(pool_amounts, True, default_return_value = 0)
            if min_lp_out > 0:
                extcall pool_contracts[i].add_liquidity(pool_amounts, 0)  #@PLANTED min_lp_out or 0 - doesn't matter as it's in same block, i.e. add liquidity at any rates, i.e. sanwich all my money
    
    # clear hashmap
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        self.coin_amounts[coins_list[i]] = 0

    return True


@internal
def load_liq(
    coins_list: DynArray[address, utils.MAX_COINS],
    amounts_to_use: DynArray[uint256, utils.MAX_COINS],
    pools_list: DynArray[address, utils.MAX_POOLS]
) -> DynArray[uint256, utils.MAX_POOLS]:
    """
    @notice Adds coins into pools as liquidity in imbalanced way.
    @param coins_list Addresses of coins to add.
    @param coin_amounts Amounts of coins to add.
    @param pools_list Addresses of pools to add to.
    @return DynArray[uint256, utils.MAX_POOLS] Amount of LP tokens received for each pool.
    """
    lp_tokens: DynArray[IERC20, utils.MAX_POOLS] = []
    lp_token_amounts_pre: DynArray[uint256, utils.MAX_POOLS] = []
    lp_token_amounts_post: DynArray[uint256, utils.MAX_POOLS] = []
    user_coin_use_in_pools: DynArray[uint256, utils.MAX_COINS] = []
    pool_contracts: DynArray[utils.CurveTriCryptoPool, utils.MAX_POOLS] = []    
    result: DynArray[uint256, utils.MAX_POOLS] = []

    # initialize dynamic arrays for pool contracts, and parse LP tokens
    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        pool_contracts.append(utils.CurveTriCryptoPool(pools_list[i]))
        # parse LP tokens (old pool uses separately deployed contract)
        lp_tokens.append(IERC20(utils._get_lp_token_for_pool(pool_contracts[i])))

    # initialize dynamic array
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        user_coin_use_in_pools.append(0)

    # calculate token appearances in pools
    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        pool_coins: address[utils.THREE] = utils._get_pool_coins(pool_contracts[i])
        for j: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
            if coins_list[j] in pool_coins:
                user_coin_use_in_pools[j] += 1

    # transfer tokens to this contract, adjust amount to use to consider multiple pools
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        if user_coin_use_in_pools[i] > 0:
            coin_contract: IERC20 = IERC20(coins_list[i])
            amounts_to_use[i] = amounts_to_use[i] // user_coin_use_in_pools[i]
            amount_to_transfer: uint256 = amounts_to_use[i] * user_coin_use_in_pools[i] # we recalcuate to fix flooring leftovers
            transfer_success: bool = extcall coin_contract.transferFrom(msg.sender, self, amount_to_transfer, default_return_value = True)
            assert transfer_success, "Transfer failed!"
        else:
            amounts_to_use[i] = 0


    # determine LP token balances before adding liquidity
    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        lp_token_amounts_pre.append(staticcall lp_tokens[i].balanceOf(self))
    
    assert len(lp_token_amounts_pre) == len(lp_tokens), "LP token balance check failed!"

    # # load liquidity
    assert self._load_liq_multiple_pools(coins_list, amounts_to_use, pool_contracts), "Failed to add_liquidity"

    # determine LP token balances after adding liquidity
    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        lp_token_amounts_post.append(staticcall lp_tokens[i].balanceOf(self))

    result = []
    for i: uint256 in range(len(lp_tokens), bound=utils.MAX_POOLS):
        lp_diff: uint256 = lp_token_amounts_post[i] - lp_token_amounts_pre[i]
        if lp_diff > 0:
            # transfer LP tokens to user
            extcall lp_tokens[i].transfer(msg.sender, lp_diff, default_return_value = True)
        result.append(lp_token_amounts_post[i] - lp_token_amounts_pre[i])

    return result

