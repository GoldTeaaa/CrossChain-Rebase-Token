# Cross-chain Rebase Token

# The Rebase Token in this contract does not adjust its value to maintain a stable peg (like algorithmic stablecoins such as AMPL or OHM). Instead, it rebases user balances to reflect accrued interest over time.

# Each user's token balance automatically increases as interest accrues, based on the interest rate they had when they first received or deposited tokens. This ensures that token holders passively earn yield without requiring manual claims, making it function similarly to yield-bearing assets in DeFi (e.g., AAVE's aTokens or stETH).

1. Protocol that allows user to deposit into a vault and in return, receiver rebase token that represent their underlying balance
2. Rebase token -> balanceOf function is dynamic to show the changing balance with time.
    - Balance increases linearly with time.
    - mint tokens to out users every time they perform an action [minting, burning, transffering, or... bridging]
3. Interest Rate
    - Individually set an interest rate or each user based on some global interest rate of the protocol at the time the user deposits into the vault