## Lore
A prominent Russian citizen, Vladimir, is experiencing problems with spending money abroad. Neither Revolut nor TransferWise agrees to open an account for him. Determined to obfuscate his capital via cryptocurrencies, he asked a friend to write a custom smart contract tailored to his needs. And, as no one has ever refused Vladimir, his friend threw all his efforts into this task, despite his degrees being in completely unrelated fields.

The beginner developer chose the latest version of Vyper to write the contract, mainly because he heard it was a Pythonic language, and he had studied Python in school. He also decided to build interactions around Curve Finance, as it stirred a sense of patriotism within him.

When he sought someone to create a GUI, he was rejected, as apparently all the skilled people were either on a working trip somewhere in the south or fortunate enough to have left the country in the past year. Lacking any JavaScript skills and with ChatGPT blocked along with all VPN services, he decided to implement all necessary functionalities directly in the contract.

While there could be numerous bugs in the code, the developer is confident that the contract will work as intended. After all, he has tested it thoroughly in Jupyter notebooks and even wrote a few tests in Python. He is now ready to deploy the contract and share it with Vladimir, who is eagerly waiting to convert his rubles into a more stable currency.

## Rules
**Your task is to find the numerous ways in which Vladimir could lose money interacting with this contract.** You should assume that Vladimir will only use "legit" tokens and curve pools - i.e. ones that he can find on main page of curve.fi. You should also assume that Vladimir will behave rationally and not try to compromise himself (i.e. with slippage = 100%). If you doubt Vladimir's rationality, please expect a call from competent authorities.

Please submit your findings as a separate branch of this repository. You can either document findings directly in the code, or summarize them in FINDINGS.md, or both.
 - Findings will be graded with non-transparent points system.
 - If vulnerability is conditional, please mention that explicitly and describe the conditions under which Vladimir's bags will suffer.
 - If you find flaws in contract logic, malfuctions of DoS, or gas optimizations, report them for bonus points.
 - Incorrect bug reports may lead to a penalty.
 - If you point out ways to improve the code - please share them as well in hope that the developer will learn from them. Good advise may lead to a bonus.
 - The developer hopes to learn from your findings and improve his skills, so please provide detailed explanations.
 - If exploitation involves multiple transactions - please describe each of them and execution order.


## Contract description
CurveAssistant is a comprehensive smart contract suite developed in Vyper to facilitate interactions with Curve’s non-stablecoin TriCrypto and TriCrypto-NG pools. The suite is composed of several modules, each handling specific aspects of liquidity management:
 - TriCryptoLiqLoader.vy: This module distributes input tokens across multiple Curve pools, adding liquidity in an imbalanced manner based on token presence in different pools.
 - TriCryptoLiqUnloader.vy: A module for collecting liquidity from specified pools, withdrawing it in a balanced way but potentially leading to imbalanced token values across pools if tokens are present in multiple pools.
 - TriCryptoCoinsConverter.vy: A module for converting input tokens into a single target token using specified pools. It supports one-hop conversions and iterative swapping to potentially achieve better rates at the cost of higher gas consumption. A slippage commitment must be called in advance (using the same set of inputs as in the swap) with allowed slippage in percentages (10 = 1%, 100 = 10%, and so on) to prevent sandwich attacks.
 - CurveAssistant.vy: The main contract that includes all the aforementioned contracts as modules and exposes their functionality to the user. It incorporates essential checks typically managed by front-end applications, such as approval validation and duplicate detection.
 - _TriCryptoHelpers.vy: A library of helper functions to simplify interactions with Curve pools.

## Disclaimer
These contracts are designed as a demonstration of Vyper’s capabilities and are not intended for production use.

## Interactive Testing

Two Jupyter notebooks are provided for running the code interactively and exploring its functionality:
 - playground_liq.ipynb demonstrates the usage of TriCryptoLiqLoader and TriCryptoLiqUnloader modules, allowing you to mint tokens and add/withdraw liquidity from Curve pools.
 - playground_convert.ipynb shows the usage of the TriCryptoCoinsConverter module, allowing you to convert tokens using multiple pools at once.

## Automated Testing
Running pytest -s will launch a test suite that:
1) Deploys the CurveAssistant contract (all other contracts mentioned are automatically included as Vyper modules);
2) Parses required contracts (tokens and Curve pools from the Etherscan API); 
3) Initiates token balances;
4) Calls the main function (tests/test_main.py) to verify the contract’s behavior

## Dependencies
Vyper (0.4.0)
boa (for testing)

## Gas Profiling
Due to titanoboa active development state please use 
```
pip uninstall titanoboa
pip install git+https://github.com/vyperlang/titanoboa.git@0ca93fcd540ceb38e051fb8acd5194e4be926158#egg=titanoboa
```
to install the correct version of titanoboa.
If you want to use stable 0.2.0 release, please comment out all ```@pytest.mark.gas_profile``` decorators in tests.