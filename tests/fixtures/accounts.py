import math

import boa
import pytest
# from eth_account.account import Account, LocalAccount

# from tests.utils.tokens import mint_for_testing
# from tests.fixtures.constants import TOKEN_AMOUNT, ETH_AMOUNT


@pytest.fixture(scope="session")
def deployer():
    return boa.env.generate_address()


# @pytest.fixture(scope="session")
# def users():
#     return [boa.env.generate_address() for i in range(10)]


# @pytest.fixture
# def initial_setup(deployer, users, plain_tokens):
#     # Fund deployer
#     mint_for_testing(deployer, ETH_AMOUNT * 10 ** 18, None, mint_eth=True)
#     for token in plain_tokens:
#         mint_for_testing(deployer, TOKEN_AMOUNT * 10 ** token.decimals(), token)
#     # Fund users
#     for user in users:
#         mint_for_testing(user, ETH_AMOUNT * 10 ** 18, None, mint_eth=True)
#         for token in plain_tokens:
#             mint_for_testing(user, TOKEN_AMOUNT * 10 ** token.decimals(), token)

# @pytest.fixture
# def initial_setup_forked(deployer, users, plain_tokens, forked_chain):
#     # Fund deployer
#     mint_for_testing(deployer, ETH_AMOUNT * 10 ** 18, None, mint_eth=True)
#     for token in plain_tokens:
#         mint_for_testing(deployer, TOKEN_AMOUNT * 10 ** token.decimals(), token)
#     # Fund users
#     for user in users:
#         mint_for_testing(user, ETH_AMOUNT * 10 ** 18, None, mint_eth=True)
#         for token in plain_tokens:
#             mint_for_testing(user, TOKEN_AMOUNT * 10 ** token.decimals(), token)


