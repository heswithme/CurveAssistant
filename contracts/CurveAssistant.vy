# @version 0.4.0

"""
@title CurveAssistant
@notice This contract acts as an assistant for interacting with Curve tricrypto pools.
It facilitates the addition and removal of liquidity, as well as many-to-one coins convert functionality (i.e. marketsell).
Supported Curve pools are tricrypto (circa 2021) and tricrypto-ng (circa 2023), which are NON-STABLECOIN pools.
@dev This contract contains some logic that's typically handled by a front-end (approval validation, duplicates detection). 
It's done to exercise and demonstrate the capabilities of Vyper language. The contract is not intended for production use.
The contract verifies sender balances and approvals, ensuring the required approvals and sufficient balances are in place. 
If any approval is missing, the transaction is reverted. If a specified token amount exceeds the balance, the entire balance is used.
load_coins_to_pools - Receives a list of ERC20 token addresses, amounts, and Curve pool addresses, then adds liquidity to the pools relying on pools balancing.
extract_liquidity - Checks if the user holds LP tokens of the specified pools and withdraws liquidity in a balanced manner.
convert_to_one - Converts multiple tokens into one target token using specified pools;
                 supports multiple iterations — higher iterations consume proportionally more gas but may yield a better conversion rate.
"""

from ethereum.ercs import IERC20

import _TriCryptoHelpers as utils
exports: (
    utils.get_lp_token_for_pool,
    utils.get_lp_balance,
    utils.get_pool_coins,
    utils.estimate_usd_value_of_coins
)

import TriCryptoLiqLoader as liq_loader
initializes: liq_loader

import TriCryptoLiqUnloader as liq_unloader
initializes: liq_unloader

import TriCryptoCoinsConverter as coins_converter
initializes: coins_converter



# mapping for duplicates check
seen: transient(HashMap[address, bool]) # need this hashmap to detect duplicates, kept clean after each call
slippage_map: transient(HashMap[address, uint256]) # for slippage protection

@internal
def _detect_duplicates(arr: DynArray[address, max(utils.MAX_POOLS,utils.MAX_COINS)]) -> bool:
    has_duplicates: bool = False
    for i: uint256 in range(len(arr), bound=max(utils.MAX_POOLS,utils.MAX_COINS)):
        element: address = arr[i]
        if not self.seen[element]:
            self.seen[element] = True
        else:
            has_duplicates = True
    return has_duplicates
    

@internal
def _unsee(arr: DynArray[address, max(utils.MAX_POOLS,utils.MAX_COINS)]):
    for i: uint256 in range(len(arr), bound=max(utils.MAX_POOLS,utils.MAX_COINS)):
        element: address = arr[i]
        self.seen[element] = False


@deploy
def __init__():
    liq_loader.__init__()
    liq_unloader.__init__()
    coins_converter.__init__()
    pass


@nonreentrant
@external
def load_coins_to_pools(
    coins_list: DynArray[address, utils.MAX_COINS],
    coin_amounts: DynArray[uint256, utils.MAX_COINS],
    pools_list: DynArray[address, utils.MAX_POOLS]
) -> DynArray[uint256, utils.MAX_POOLS]:

    # validate inputs
    assert len(coins_list) > 0, "Provide coins to add liquidity!"
    assert len(coins_list) == len(coin_amounts), "Provide amounts for coins!"
    assert len(pools_list) > 0, "Provide pools to add liquidity to!"

    # detect duplicates (clear "seen" mapping to preserve duplicates detection for future calls)
    assert not self._detect_duplicates(coins_list), "Duplicate coins provided!"
    self._unsee(coins_list)

    assert not self._detect_duplicates(pools_list), "Duplicate pools provided!"
    self._unsee(pools_list)

    amounts_to_use: DynArray[uint256, utils.MAX_COINS] = []

    # validate allowances
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        coin_contract: IERC20 = IERC20(coins_list[i])
        user_balance: uint256 = staticcall coin_contract.balanceOf(msg.sender)
        user_allowance: uint256 = staticcall coin_contract.allowance(msg.sender, self)
        coin_amount: uint256 = coin_amounts[i]
        amounts_to_use.append(min(user_balance, coin_amount))
        assert user_allowance >= amounts_to_use[i], "Approve tokens first!"
    
    return liq_loader.load_liq(coins_list, amounts_to_use, pools_list)
    

@nonreentrant
@external
def extract_liquidity(
    pools_list: DynArray[address, utils.MAX_POOLS]
    ) -> DynArray[bool, utils.MAX_POOLS]:

    # validate inputs
    assert len(pools_list) > 0, "Provide pools to remove liquidity from!"

    assert not self._detect_duplicates(pools_list), "Duplicate pools provided!"
    self._unsee(pools_list)

    return liq_unloader.unload_liq(pools_list)


@nonreentrant
@external
def convert_to_one(    
    coins_list: DynArray[address, utils.MAX_COINS],
    coin_amounts: DynArray[uint256, utils.MAX_COINS],
    pools_list: DynArray[address, utils.MAX_POOLS],
    target_coin: address,
    n_iterations: uint256) -> uint256:

    
    # validate inputs
    assert len(coins_list) > 0, "Provide coins to swap!"
    assert len(coins_list) == len(coin_amounts), "Provide amounts for coins!"
    assert len(pools_list) > 0, "Provide pools to swap into!"
    assert n_iterations > 0 and n_iterations < utils.MAX_ITERATIONS, "Provide number of iterations!"
    # detect duplicates (clear "seen" mapping to preserve duplicates detection for future calls)
    assert not self._detect_duplicates(coins_list), "Duplicate coins provided!"
    self._unsee(coins_list)

    assert not self._detect_duplicates(pools_list), "Duplicate pools provided!"
    self._unsee(pools_list)
    
    # validate that user set slippage
    assert self.slippage_map[msg.sender] > 0, "Set slippage protection first!"

    amount_to_use: DynArray[uint256, utils.MAX_POOLS] = []
    # validate allowances
    for i: uint256 in range(len(coins_list), bound=utils.MAX_COINS):
        coin_contract: IERC20 = IERC20(coins_list[i])
        user_balance: uint256 = staticcall coin_contract.balanceOf(msg.sender)
        user_allowance: uint256 = staticcall coin_contract.allowance(msg.sender, self)
        coin_amount: uint256 = coin_amounts[i]
        amount_to_use.append(min(user_balance, coin_amount))
        assert user_allowance >= amount_to_use[i], "Approve tokens first!"

    res: uint256 = coins_converter.market_convert(coins_list, amount_to_use, pools_list, target_coin, n_iterations, self.slippage_map[msg.sender])
    self.slippage_map[msg.sender] = 0
    return res


@external
def commit_slippage_protection(
    coins_list: DynArray[address, utils.MAX_COINS],
    coin_amounts: DynArray[uint256, utils.MAX_COINS],
    pools_list: DynArray[address, utils.MAX_POOLS],
    target_coin: address,
    slippage_percent: uint256
) -> uint256:
    target_coin_decimals: uint256 = staticcall utils.IERC20d(target_coin).decimals()
    target_coin_usd_price: uint256 = utils._estimate_usd_value_of_coins([target_coin], [10**target_coin_decimals], pools_list)
    estimated_sell_value: uint256 = utils._estimate_usd_value_of_coins(coins_list, coin_amounts, pools_list)
    min_amount_out: uint256 = 10 ** target_coin_decimals * (1000 - slippage_percent) * estimated_sell_value // target_coin_usd_price  // 1000
    self.slippage_map[msg.sender] = min_amount_out 
    return self.slippage_map[msg.sender]


@external
@view
def check_my_slippage()-> uint256:
    return self.slippage_map[msg.sender]
    

# @ideas for CTF:
# 1. Code is quite complex, with three large functions. It's possible to hide a bug in one of them. 
#    But then it should clearly contradict functionality descriptions. Also can be unexpected bugs... Not obvious.
# 2. Currently it does a lot of front-end work (approvals, duplicates detection). 
#    Another VERY important front-end feature is slippage protection. Right now code can be sandwiched left and right.
#    Liq is added/removed with minOut=0 and swaps are performed with minOut = get_dx - both are vulnerable to sandwich attacks.
#    Can try to add oracle price checks and slippage protection in contract -> directing CTF to detecting of these unsafe validations.
#    Or, even better - one function - slippage 0, one function - get_dy, one function - oracle vulnerability.
# 3. This code uses vyper 0.4.0 that introduced modularity. May try planting smth related to new features: https://docs.vyperlang.org/en/stable/release-notes.html
# 4. There's no input validation for tricrypto hacked pools. One potential pool is arbitrum tricrypto pool: 0x960ea3e3c7fb317332d990873d354e18d7645590
# 5. implemented get_tokens_value, shoul be input to the marketsell function. to avoid sandwich - multitx?