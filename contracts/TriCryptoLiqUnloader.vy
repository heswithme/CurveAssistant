# @version 0.4.0

"""
@title TriCryptoLiqUnloader
@notice This module's main function is to collect liquidity from specified pools.
If user holds LP tokens of the specified pools, the contract withdraws all liquidity from those pools.
"""

from ethereum.ercs import IERC20

import _TriCryptoHelpers as utils


# mappings used locally
tokens_owed: transient(HashMap[address, uint256]) # for liq removal, to be zeroed after each call


@deploy
def __init__():
    pass


@internal
def unload_liq(
    pools_list: DynArray[address, utils.MAX_POOLS]
    ) -> DynArray[bool, utils.MAX_POOLS]:
    result: DynArray[bool, utils.MAX_POOLS] = []

    tokens_to_return: DynArray[address, utils.THREE * utils.MAX_POOLS] = []

    for i: uint256 in range(len(pools_list), bound=utils.MAX_POOLS):
        pool_contract: utils.CurveTriCryptoPool = utils.CurveTriCryptoPool(pools_list[i])
        lp_token: IERC20 = IERC20(utils._get_lp_token_for_pool(pool_contract))
        user_lp_balance: uint256 = staticcall lp_token.balanceOf(msg.sender)
        if user_lp_balance > 0:
            # validate lp token aproval
            assert staticcall lp_token.allowance(msg.sender, self) >= user_lp_balance, "Approve LP tokens first!"

            # transfer LP tokens to this contract
            extcall lp_token.transferFrom(msg.sender, self, user_lp_balance, default_return_value = True)
            
            # issue approvals
            assert utils.smart_approve(lp_token.address, pool_contract.address, user_lp_balance), "Approve failed!"
            # get pool coins
            pool_coins: address[utils.THREE] = utils._get_pool_coins(pool_contract)

            # determine pool token balances before removing liquidity
            token_balances_pre: uint256[utils.THREE] = [0, 0, 0]
            for j: uint256 in range(utils.THREE):
                token_balances_pre[j] = staticcall IERC20(pool_coins[j]).balanceOf(self)

            # remove liquidity
            extcall pool_contract.remove_liquidity(user_lp_balance, [0, 0, 0]) #@PLANTED 0 is for min_amounts, i.e. remove liquidity at any rates, sandwich trigger (fake bait)
            # determine pool token balances after removing liquidity and transfer tokens
            token_balances_post: uint256[utils.THREE] = [0, 0, 0]
            for j: uint256 in range(utils.THREE):
                token_balances_post[j] = staticcall IERC20(pool_coins[j]).balanceOf(self)
                diff: uint256 = token_balances_post[j] - token_balances_pre[j]
                if diff > 0:
                    self.tokens_owed[pool_coins[j]] += diff
                    tokens_to_return.append(pool_coins[j])
            result.append(True)
        else:
            result.append(False)

        # return tokens to user, clean up the hashmap
        for j: uint256 in range(len(tokens_to_return), bound=utils.MAX_COINS):
            if self.tokens_owed[tokens_to_return[j]] > 0:
                token_contract: IERC20 = IERC20(tokens_to_return[j])
                sending_amount: uint256 = self.tokens_owed[tokens_to_return[j]]
                self.tokens_owed[tokens_to_return[j]] = 0
                transfer_success: bool = extcall token_contract.transfer(msg.sender, sending_amount, default_return_value = True)
                assert transfer_success, "Transfer failed!"
    return result

