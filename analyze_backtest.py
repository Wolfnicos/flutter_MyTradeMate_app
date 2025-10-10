# scripts/analyze_backtest.py
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Load results
df = pd.read_csv('backtest_results/summary_BTCUSDT_2025-10-10.csv')

# Plot comparison
fig, axes = plt.subplots(2, 2, figsize=(15, 10))

# 1. Total Return
df_sorted = df.sort_values('Total Return %', ascending=False)
axes[0, 0].barh(df_sorted['Config'], df_sorted['Total Return %'])
axes[0, 0].set_title('Total Return Comparison')
axes[0, 0].set_xlabel('Return %')

# 2. Sharpe Ratio
df_sorted = df.sort_values('Sharpe Ratio', ascending=False)
axes[0, 1].barh(df_sorted['Config'], df_sorted['Sharpe Ratio'])
axes[0, 1].set_title('Sharpe Ratio Comparison')
axes[0, 1].set_xlabel('Sharpe Ratio')

# 3. Win Rate
axes[1, 0].scatter(df['Win Rate %'], df['Total Return %'], s=100)
axes[1, 0].set_xlabel('Win Rate %')
axes[1, 0].set_ylabel('Total Return %')
axes[1, 0].set_title('Win Rate vs Return')

# 4. Risk-Return
axes[1, 1].scatter(df['Max Drawdown %'], df['Total Return %'], s=100)
axes[1, 1].set_xlabel('Max Drawdown %')
axes[1, 1].set_ylabel('Total Return %')
axes[1, 1].set_title('Risk vs Return')

plt.tight_layout()
plt.savefig('backtest_results/analysis.png', dpi=300)
print('✅ Saved: backtest_results/analysis.png')
