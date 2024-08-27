import boa
import os, re
import requests
from eth_utils import to_checksum_address
from decimal import Decimal


def get_top_holders(address):
    # not functioning without PRO api key (200$/mo as of aug'24)
    req = """https://api.etherscan.io/api?module=token
            &action=tokenholderlist
            &contractaddress=%s
            &page=1
            &offset=0
            &apikey=%s 
    """%(address.lower(), os.environ.get("ETHERSCAN_API_KEY_CS"))
    req = req.replace("\n", "").replace(" ", "")

    resp = requests.get(req)
    return resp.json()


def mint_for_testing_evals(token_contract, addr, amount, mint_eth=False):
    # not functioning for contracts parsed from etherscan, as they are not stateless
    addr = to_checksum_address(addr)

    if token_contract.symbol() == "WETH":
        boa.env.set_balance(addr, boa.env.get_balance(addr) + amount)
        if not mint_eth:
            with boa.env.prank(addr):
                token_contract.deposit(value=amount)
    else:
        token_contract.eval(f"self.totalSupply += {amount}")
        token_contract.eval(f"self.balanceOf[{addr}] += {amount}")
        token_contract.eval(f"log Transfer(empty(address), {addr}, {amount})")

    
def parse_topholders(folder, address):
    filename = [f for f in os.listdir(folder) if f.endswith(".csv") and address.lower() in f.lower()]
    holders = []
    if filename:
        eth_address_pattern = re.compile(r"^0x[a-fA-F0-9]{40}$")
        with open(os.path.join(folder, filename[0]), 'r') as f:
            for line in f:
                raw_line = line.strip().replace('"', '').split(",")
                if eth_address_pattern.match(raw_line[1]):
                    holders.append(raw_line[1])
    if len(holders) == 0:
        raise Exception('No holders found for %s, unable to steal tokens! \nYou must click Download Page data on https://etherscan.io/token/%s#balances and put it to %s' % (address, address, folder))
    return holders



def steal_from_whales(token_contract, addr_to, amount, path_prefix=''):
    # whales = parse_topholders_folder('tests/utils/topholders_etherscan')
    whales = parse_topholders(path_prefix+'tests/utils/topholders_etherscan', token_contract.address)
    # print(whales)
    for whale in whales:
        try: 
            with boa.env.prank(whale):
                token_contract.transfer(addr_to, int(amount))
                return True
        except Exception as e:
            # print(e)
            continue
    


def mint_for_testing(token_contract, addr, amount, mint_eth=False, path_prefix=''):
    addr = to_checksum_address(addr)
    amount = int(Decimal(str(amount)))
    if token_contract.symbol() == "WETH":
        boa.env.set_balance(addr, boa.env.get_balance(addr) + amount)
        if not mint_eth:
            with boa.env.prank(addr):
                token_contract.deposit(value=amount)
    else:
        # print('stealing...')
        steal_from_whales(token_contract, addr, amount, path_prefix)


def get_token_balance(token_address, user_address = None):
    if user_address is None:
        user_address = boa.env.eoa
    source = """
    from ethereum.ercs import IERC20
    @external
    @view
    def get_balance(erc20_token_address: address, user_address: address) -> uint256:
        return staticcall IERC20(erc20_token_address).balanceOf(user_address, default_return_value = 0)
    """
    # print(source)
    contract = boa.loads(source)
    return contract.get_balance(token_address, user_address)



