# @version 0.4.0

"""
@title TriCryptoCoinsConverter
@notice This module's main function is to convert input tokens into single target token using specified pools.
It finds the best pool for each token and supports 1-hopping (i.e. skipping with one intermediate token).
Additionally, user may specify number of iterations to swap in steps, potentially yielding better conversion rate (but consuming more gas).
User must first call commit_slippage_protection with same set of coins and pools to set maximal allowed slippage and set min_amount_out.
"""

from ethereum.ercs import IERC20

import _TriCryptoHelpers as utils



# mappings used locally
path_map: transient(HashMap[address, DynArray[address, utils.MAX_COINS]]) # for market convert, to be zeroed after each call (because pools dependent)
pool_map: transient(HashMap[address, DynArray[utils.CurveTriCryptoPool, utils.MAX_POOLS]]) # for market convert, to be zeroed after each call (because pools dependent)


@deploy
def __init__():
    pass

@internal
# large and scary function, but not too complex
# basically it finds the best direct swap and the best indirect swap via bruteforce scanning of all pools
# then it performs one that yields the most target coin
def best_convert(
    coin_address: address,
    coin_amount: uint256,
    target_coin: address,
    pools_list: DynArray[address, utils.MAX_POOLS],
    pools_coins: DynArray[address[utils.THREE], utils.MAX_POOLS] = [],
): 
    # 1. analyze direct swap opportunities
    best_direct_amount_out: uint256 = 0 
    best_direct_pool: utils.CurveTriCryptoPool = empty(utils.CurveTriCryptoPool)   
    pool_contracts: DynArray[utils.CurveTriCryptoPool, utils.MAX_POOLS] = []
    # direct_pools: DynArray[address, utils.MAX_POOLS] = []
    # first find best direct swap
    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        pool_contracts.append(utils.CurveTriCryptoPool(pools_list[i]))
        if coin_address in pools_coins[i] and target_coin in pools_coins[i]:
            # direct_pools.append(pools_list[i])
            direct_amount_out: uint256 = utils._get_amount_out(pool_contracts[i], coin_address, target_coin, coin_amount)
            if direct_amount_out > best_direct_amount_out:
                best_direct_amount_out = direct_amount_out
                best_direct_pool = pool_contracts[i]

    # 2. analyze indirect swap opportunities
    best_intermediate: address = empty(address)
    best_indirect_pool_1: utils.CurveTriCryptoPool = empty(utils.CurveTriCryptoPool)
    best_intermediate_amount_out: uint256 = 0
    best_indirect_pool_2: utils.CurveTriCryptoPool = empty(utils.CurveTriCryptoPool)
    best_indirect_amount_out: uint256 = 0
    targets_indirect: DynArray[address, utils.MAX_COINS] = self.path_map[target_coin]

    for i: uint256 in range(len(targets_indirect), bound=utils.MAX_COINS):
        #we check each possible intermediary coin (target_indirect)
        target_indirect: address = targets_indirect[i]
        if target_indirect in self.path_map[coin_address]: # we only care if current coin can be changed to target_indirect
            for j: uint256 in range(len(pools_list), bound=utils.MAX_POOLS): # now find a pool for coin -> target_indirect (could be multiple, need to find best)
                if target_indirect in pools_coins[j] and coin_address in pools_coins[j]: # ok, this pool is a candidate
                    intermediate_amount_out: uint256 = utils._get_amount_out(pool_contracts[j], coin_address, target_indirect, coin_amount)
                    for k: uint256 in range(len(self.pool_map[target_indirect]), bound=utils.MAX_POOLS): # now check swaps for target_indirect -> target_coin
                        # since we are in pool_map of target_indirect, we know that target_indirect and target_coin are both in the pool (by construction line:170)
                        candidate_amount_out: uint256 = utils._get_amount_out(self.pool_map[target_indirect][k], target_indirect, target_coin, intermediate_amount_out)
                        if candidate_amount_out > best_indirect_amount_out:
                            best_indirect_amount_out = candidate_amount_out
                            best_intermediate = target_indirect
                            best_intermediate_amount_out = intermediate_amount_out
                            best_indirect_pool_1 = pool_contracts[j]
                            best_indirect_pool_2 = self.pool_map[target_indirect][k]                                

    coin_contract: IERC20 = IERC20(coin_address)
    if best_direct_amount_out > best_indirect_amount_out:
        # do direct swap coin->target
        # issue approval
        utils.smart_approve(coin_address, best_direct_pool.address, coin_amount)
        # do swap
        utils._call_exchange(best_direct_pool, coin_address, target_coin, coin_amount, best_direct_amount_out)
    else:
        # do indirect swap coin->intermediate
        intermediate_coin_contract: IERC20 = IERC20(best_intermediate)
        # issue approvals 
        utils.smart_approve(coin_address, best_indirect_pool_1.address, coin_amount)
        # do swap coin->intermediate
        intermediate_coin_balance_before: uint256 = staticcall intermediate_coin_contract.balanceOf(self)
        utils._call_exchange(best_indirect_pool_1, coin_address, best_intermediate, coin_amount, best_intermediate_amount_out)
        intermediate_coin_balance_after: uint256 = staticcall intermediate_coin_contract.balanceOf(self)
        intermediate_diff: uint256 = intermediate_coin_balance_after - intermediate_coin_balance_before
        # now swap intermediate->target
        utils.smart_approve(best_intermediate, best_indirect_pool_2.address, intermediate_diff)
        utils._call_exchange(best_indirect_pool_2, best_intermediate, target_coin, intermediate_diff, best_indirect_amount_out)



@internal
def market_convert(
    coins_list: DynArray[address, utils.MAX_COINS],
    amount_to_use: DynArray[uint256, utils.MAX_COINS],
    pools_list: DynArray[address, utils.MAX_POOLS],
    target_coin: address,
    n_iterations: uint256,
    min_amount_out: uint256
) -> uint256:

    pools_coins: DynArray[address[utils.THREE], utils.MAX_POOLS] = []
    pool_contracts: DynArray[utils.CurveTriCryptoPool, utils.MAX_POOLS] = []

    # first get pool coins
    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        pool_contracts.append(utils.CurveTriCryptoPool(pools_list[i]))
        pools_coins.append(utils._get_pool_coins(pool_contracts[i]))

    # now get a flattened list of all coins   
    all_coins: DynArray[address, utils.THREE * utils.MAX_POOLS] = []
    for i: uint256 in range(len(pools_coins), bound=utils.MAX_POOLS):
        for j: uint256 in range(utils.THREE):
            if pools_coins[i][j] not in all_coins:
                all_coins.append(pools_coins[i][j])


    assert target_coin not in coins_list, "Target coin cannot be in input list!"
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        assert coins_list[i] in all_coins, "Coin not in any pool!"


    # transfer tokens in
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        coin_contract: IERC20 = IERC20(coins_list[i])
        transfer_success: bool = extcall coin_contract.transferFrom(msg.sender, self, amount_to_use[i], default_return_value = True)
        assert transfer_success, "Transfer failed!"


    # now let's populate path_map (TODO: see if can be done in a more efficient way)
    # for each coin

    for i: uint256 in range(len(all_coins), bound=utils.MAX_COINS):
        self.path_map[all_coins[i]] = []
        # we check each pool
        for j: uint256 in range(len(pools_coins), bound=utils.MAX_POOLS):
            # and if it's there
            if all_coins[i] in pools_coins[j]:
                # we add other two other coins to path_map (subject to duplicates exclusion check)
                for k: uint256 in range(utils.THREE):
                    # wild nested for loop, may be 1inch is better
                    if pools_coins[j][k] != all_coins[i] and pools_coins[j][k] not in self.path_map[all_coins[i]]:
                        self.path_map[all_coins[i]].append(pools_coins[j][k])
    
    # indirect targets (because we consider 1-hopping we now want not only target coin but also intermediate coins)
    targets_indirect: DynArray[address, utils.MAX_COINS] = self.path_map[target_coin]
    assert len(targets_indirect) > 0, "No path to target coin!"

    # for indirect targets we also must know the pools to use to transform to target_coin
    for i: uint256 in range(len(targets_indirect), bound=utils.MAX_COINS):
        self.pool_map[targets_indirect[i]] = []
        for j: uint256 in range(len(pools_coins), bound=utils.MAX_POOLS):
            if targets_indirect[i] in pools_coins[j] and target_coin in pools_coins[j]:
                self.pool_map[targets_indirect[i]].append(pool_contracts[j])

    # we now cycle through coins performing swaps - direct or indirect
    # n_coins = 2*n_swaps at worst (if all swaps are indirect), there's no swap optimization (logic too complex)
    target_coin_contract: IERC20 = IERC20(target_coin)
    target_coin_balance_before: uint256 = staticcall target_coin_contract.balanceOf(self)
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        for j: uint256 in range(n_iterations, bound=utils.MAX_POOLS):
            amt_current_iteration: uint256 = amount_to_use[i] // n_iterations
            self.best_convert(coins_list[i], amt_current_iteration, target_coin, pools_list, pools_coins)

    target_coin_balance_after: uint256 = staticcall target_coin_contract.balanceOf(self)    
    target_coin_result: uint256 = target_coin_balance_after - target_coin_balance_before
    assert target_coin_result > min_amount_out, "Slippage exceeded!" #very expensive revert
    assert extcall target_coin_contract.transfer(msg.sender, target_coin_result, default_return_value = True)            
    return target_coin_result


