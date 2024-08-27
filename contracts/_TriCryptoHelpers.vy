# @version 0.4.0


from ethereum.ercs import IERC20

interface CurveTriCryptoPool:
    def add_liquidity(amounts: uint256[THREE], min_mint_amount: uint256): nonpayable
    def remove_liquidity(_amount: uint256, min_amounts: uint256[THREE]): nonpayable
    def coins(i: uint256) -> address: view
    def token() -> address: view # for old pools
    def get_dy(i: uint256, j: uint256, dx: uint256) -> uint256: view
    def exchange(i: uint256, j: uint256, dx: uint256, min_dy: uint256, use_eth: bool): nonpayable
    def price_oracle(k: uint256) -> uint256: view
    def calc_token_amount(amounts: uint256[THREE], deposit: bool) -> uint256: view

interface IERC20d:
    def decimals() -> uint256: view

MAX_POOLS: constant(uint256) = 10
THREE: constant(uint256) = 3 # equal to N_COINS constant in pools contracts
MAX_COINS: constant(uint256) = MAX_POOLS * THREE
MAX_ITERATIONS: constant(uint256) = 10


@deploy
def __init__():
    pass


@internal
@view
def _get_lp_token_for_pool(
    pool_contract: CurveTriCryptoPool
    ) -> address:
    # old tricrypto have separate LP token contracts
    call_result: address = staticcall pool_contract.token(default_return_value = empty(address))
    if call_result != empty(address):
        # if there exists .token field, it's the LP token for old pools
        return call_result
    else:
        # otherwise, it's the pool contract itself (for ng)
        return pool_contract.address

@internal
@view
def _find_address_index(
    pool_coins: address[THREE],
    token_address: address
    )-> uint256:
    for i: uint256 in range(THREE):
        if pool_coins[i] == token_address:
            return i
    raise "Token not found in pool coins list"
    
    

@internal
@view
def _get_pool_coins(
    pool_contract: CurveTriCryptoPool
    ) -> address[THREE]:
    result: address[THREE] = [empty(address), empty(address), empty(address)]
    for i: uint256 in range(THREE):
        result[i] = staticcall pool_contract.coins(i)

    return result


@internal
def _get_amount_out(
    pool_contract: CurveTriCryptoPool, 
    token_in: address, 
    token_out: address, 
    amount_in: uint256
    ) -> uint256:

    index_i: uint256 = 0
    index_j: uint256 = 0
    for index: uint256 in range(THREE):
        if staticcall pool_contract.coins(index) == token_in:
            index_i = index
        if staticcall pool_contract.coins(index) == token_out:
            index_j = index

    return staticcall pool_contract.get_dy(index_i, index_j, amount_in, default_return_value = 0)
    

@internal
def _call_exchange(
    pool_contract: CurveTriCryptoPool,
    token_in: address, 
    token_out: address, 
    amount_in: uint256, 
    min_amount_out: uint256
    ) -> bool:

    index_i: uint256 = 0
    index_j: uint256 = 0
    for index: uint256 in range(THREE):
        if staticcall pool_contract.coins(index) == token_in:
            index_i = index
        if staticcall pool_contract.coins(index) == token_out:
            index_j = index
    extcall pool_contract.exchange(index_i, index_j, amount_in, min_amount_out, False)
    
    return True
    

@internal 
@view
def _estimate_usd_value_of_coins(
    coins_list: DynArray[address, MAX_COINS],
    amounts: DynArray[uint256, MAX_COINS],
    pools_list: DynArray[address, MAX_POOLS]
    ) -> uint256:
    coins_appearances: DynArray[uint256, MAX_COINS] = []
    pools_coins: DynArray[address[THREE], MAX_POOLS] = []
    coins_prices: DynArray[uint256, MAX_COINS] = []
    total_value: uint256 = 0

    for i: uint256 in range(len(pools_list), bound=MAX_POOLS):
        pool_contract: CurveTriCryptoPool = CurveTriCryptoPool(pools_list[i])
        pools_coins.append(self._get_pool_coins(pool_contract))

    for i: uint256 in range(len(coins_list), bound=MAX_COINS):
        coins_appearances.append(0)
        coins_prices.append(0)
        for j: uint256 in range(len(pools_list), bound=MAX_POOLS):
            if coins_list[i] in pools_coins[j]:
                coins_appearances[i] += 1
                index: uint256 = self._find_address_index(pools_coins[j], coins_list[i])
                if index == 0: #@PLANTED assumes that stablecoin always had index 0, which is not true for all pools. Thus calue estimation can be wrong, and slippage protection set wrong, and vulnerable to sandwich.
                    # first in the pool is always stablecoin
                    coins_prices[i] += 10 ** 18
                else:
                    # or use oracle price
                    price: uint256 = staticcall CurveTriCryptoPool(pools_list[j]).price_oracle(index - 1)
                    coins_prices[i] += price
    for i: uint256 in range(len(coins_list), bound=MAX_COINS):
        if coins_appearances[i] > 0:
            coins_prices[i] = coins_prices[i] // coins_appearances[i]
            coin_decimals: uint256 = staticcall IERC20d(coins_list[i]).decimals()
            total_value += coins_prices[i] * amounts[i] // 10**coin_decimals

    return total_value


@internal
def smart_approve(
    token_address: address,
    spender_address: address, 
    amount_to_spend: uint256
    ) -> bool:

    token_contract: IERC20 = IERC20(token_address)
    current_allowance: uint256 = staticcall token_contract.allowance(msg.sender, spender_address) # @PLANTED - wrong check, must be self instead of msg.sender
    if current_allowance >= amount_to_spend:
        return True
    elif current_allowance > 0:
        extcall token_contract.approve(spender_address, 0, default_return_value = True)
        return extcall token_contract.approve(spender_address, amount_to_spend, default_return_value = True)
    else:
        return extcall token_contract.approve(spender_address, amount_to_spend, default_return_value = True)
    

@external
@view
def get_lp_token_for_pool(
    pool_address: address
    ) -> address:
    pool_contract: CurveTriCryptoPool = CurveTriCryptoPool(pool_address)
    return self._get_lp_token_for_pool(pool_contract)


@external
@view
def get_lp_balance(
    pool_address: address,
    user: address = msg.sender
    ) -> uint256:
    pool_contract: CurveTriCryptoPool = CurveTriCryptoPool(pool_address)
    return staticcall IERC20(self._get_lp_token_for_pool(pool_contract)).balanceOf(user)


@external
@view
def get_pool_coins(
    pool_address: address
    ) -> address[THREE]:
    pool_contract: CurveTriCryptoPool = CurveTriCryptoPool(pool_address)
    return self._get_pool_coins(pool_contract)


@external
@view
def estimate_usd_value_of_coins(
    coins_list: DynArray[address, MAX_COINS],
    amounts: DynArray[uint256, MAX_COINS],
    pools_list: DynArray[address, MAX_POOLS]
    ) -> uint256:

    return self._estimate_usd_value_of_coins(coins_list, amounts, pools_list)














































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































# down bad