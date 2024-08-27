import os, sys
from itertools import combinations_with_replacement
from random import Random

import boa
import pytest

# Ensure the path to the project root is added to sys.path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, project_root)

boa.env.set_random_seed(420)

pytest_plugins = [
    "tests.fixtures.accounts",
    "tests.fixtures.constants",
    "tests.fixtures.contracts",
    "tests.fixtures.tokens",
    "tests.fixtures.initial_setup",
]


@pytest.fixture(autouse=True)
def boa_setup():
    # boa.env.enable_fast_mode()
    yield
    # force reset of the environment to prevent memory leaking between tests
    # boa.env._contracts.clear()
    # boa.env._code_registry.clear()
    # boa.reset_env()


# rpc_url = os.getenv("ETH_RPC_URL")
# assert rpc_url is not None, "Provider url is not set, add WEB3_PROVIDER_URL param to env"
# boa.env.fork(url=rpc_url, block_identifier=20420069)
# print(f'Forked the chain on block {boa.env.evm.vm.state.block_number}')

@pytest.fixture(scope="session")
def forked_chain():
    rpc_url = os.getenv("ETH_RPC_URL")
    assert rpc_url is not None, "Provider url is not set, add WEB3_PROVIDER_URL param to env"
    env_forked = boa.Env()
    # env_forked = boa.env
    with boa.swap_env(env_forked):
        env_forked.fork(url=rpc_url, block_identifier=20420069)
        print(f'Forked the chain on block {boa.env.evm.vm.state.block_number}')
        yield
    # yield
