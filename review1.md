# Rules:

1. I suggest you clarify the rules by separating the "Your task is..." paragraph into a separate #Rules or #Task section. Otherwise it is easily missed.
2. Some people like to spam potential bugs. To make your life easier and to prevent spam bug reports add something like "Incorrect bug reports will result in point deduction."
3. Clarify what you accept as solution: (up to you)
    Just ways to steal funds? Then explicitly say than any DoS/gas optimizations/... are out of scope.
    Malfunctions or the contract?
    Gas optimizations?
4. I would recommend that you demand precise explanations, e.g. you won't accept "this can be front-run" (which will otherwise 100% be submitted as a solution), but demand steps and assumptions.
    ```
    A: Rewrote the "Rules" section and mentioned all points.
    ```
# Planted Bug Feedback: (feel free to proof me wrong on this)
1. remove_liquidity cannot be sandwiched successfully. If you disbalance the pool before someone else call remove_liquidity you will increase the value of what they receive (assuming the pool was roughly balanced before). So there is no vulnerability there.
    ```
    A: I had to spend 15 minutes modelling various cases, assuming imbalacing, prior LP of sandwicher and so on, and couldn't find a profitable sandwich. Is it really the case? What's the sense of mintokenout in LP withdrawal? R.n. in the code there is mintokensout=[0,0,0], really triggering the expectation of sandwich. Do you think everyone will immediately discard this and see no attack vector there? or someone can report it by mistake and get negative points? ha-ha
    ```
2. add_liquidity can only be sandwiched successfully when it is not balanced (most obviously it can be sandwiched successfully when only one coin is added). So you should make sure solutions mention this. So this is a conditional vulnerability.
    ```
    A: If he adds unbalanced liq it's equal to sandwichable trade. And contract executes it without balance check, so yeah, conditional to user input.
    ```

# High-Level Code Feedback:
1. Did you consider reentrancies? It seems that unload_liq could be reentered under certain conditions (e.g. tokens with callbacks like ERC-777).  Did you leave this open intentionally? Are you sure no exploits are possible? I have thought about it, but am not totally sure yet.
    ```
    A: all the outer functions are nonreentrant, does it mean ones inside can be reentered and exploited? If no, I must investigate. I assumed if I pack outermost fcn as nonreentrant, all the inner ones are safe....
    ```
2. Do any of the relevant pools potentially send back raw ETH (instead of wrapped ETH)? I am not aware, but just checking whether you considered this.
    ```
    A: tricrypto-ng supports native eth, but because I tried to be compatible with old pools, my contract only supports weth. So use_eth is always false (default in ng, absent in my interface)
    ```
# Low-Level Code Feedback: (in no particular order)
1. Isn't there a bug in smart_approve? Shouldn't "staticcall token_contract.allowance(msg.sender, spender_address)" contain self instead of msg.sender?
    ```
   A: good catch, it's unintentional and breaking in some cases. I will keep it, let's see how many people will notice it. 
    ```
2. Very important: You are using storage variables where you really shouldn't! As discussed storage operations (even if zeroed at the end) can be very expensive. Hence, it should be avoided if possible and it seems that these variables could be transient storage variables.  Please do gas measurements and check the difference. Examples include:
TriCryptoLiqUnloader.tokens_owed
CurveAssistant.seen

    ```
    A: I can't declare memory hashmaps! Vyper prohibits this! Am I missing something? 
    
    I did some testing here:
    1. No duplicate-checking functionality at all: 433903 gas average
    2. Duplicate-checking with zeroing of storage: 439684 gas average
    3. Duplicate-checking and non-zeroing: 609751 gas

    I guess these estimates show that with zero-storage keeping, it's okay to keep those structures.
    ```
3. _get_pool_coin_id sometimes returns 69: I recognize that in the current code it should not matter, but I would still revert (even though that it will later anyway lead to a revert. Just revert asap.)
    ```
    A: Fixed, I first learned asserts, now it's time for reverts. Also renamed it to _find_address_index
    ```
4. I personally prefer if functions like _get_lp_token_for_pool have Interfaces like CurveTriCryptoPool as argument types instead of address. To me it increases readability. But that is a matter of taste.
    ```
    A: refactored the code a bit, now _internal_functions mostly use Interfaces as inputs.
    ```
5. I think, the way load_liq sets up user_coin_use_in_pools is pretty inefficient. I think an outer static array would be better here. This way you can avoid the loop and vyper does one big initialization. Please do gas measurements and check.
    ```
    A: I started refactoring it, but it needed to be rewritten to use uint256 as simple counter, so i didn't measure different cases here explcitly...
    ```
6. load_liq has three nested loops. That should be avoided gas-wise if possible and I think here it is possible.
I think pools_coins can probably be optimized out completely, but parsing the results directly
You only use len(user_coin_use_in_pools[i]), so no need to keep an array, just keep the count.
Also here, please measure gas consumption before and after.
    ```
    A: Refactored. With counter instead of address list, we save 2k gas. With pools_coins removed we save another 1k gas. 
    ```
7. "for i: uint256 in range(len(lp_tokens), bound=utils.MAX_COINS):" shouldn't MAX_POOLS be the bound?
    ```
    A: you're right, fixed
    ```
8. _load_liq_multiple_pools also has three nested for loops. By passing better data structures, I think you can avoid that. That would be desirable.
    ```
    A: That was a fun one. I had to introduce a hashmap (non-local ha-ha) to store coins amounts, eliminating one loop (longest potentially) that was mostly used to match indices.
    ```
# Misc:
1. "resulting in imbalanced value across all collected tokens" as a description for unload_liq is a bit confusing. I think what you are trying to say is: When a token appears in multiple pools, we get more of it. But I would call this imbalanced. Not sure if this sentence is even needed here.
    ```
    A: edited
    ```
2. When I run pytest -s in our docker I get:
PluggyTeardownRaisedWarning: A plugin raised an exception during an old-style hookwrapper teardown.
The docker has vyper and boa installed.
    ```
    Can you try now? apparently env switching was affecting fixture hooks (and also breaking gas measurements), now changed the code
    ```