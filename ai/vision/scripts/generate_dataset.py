import os
import random
from typing import Tuple, List

import numpy as np
import matplotlib.pyplot as plt


class ChartPatternGenerator:
    def __init__(self):
        self.patterns = {
            'bullish_trend': self.generate_bullish_trend,
            'bearish_trend': self.generate_bearish_trend,
            'sideways': self.generate_sideways,
            'breakout_up': self.generate_breakout_up,
            'breakdown': self.generate_breakdown,
            'consolidation': self.generate_consolidation,
            'volatile': self.generate_volatile,
            'reversal_up': self.generate_reversal_up,
            'reversal_down': self.generate_reversal_down,
        }

    # --- Pattern generators ---

    def generate_bullish_trend(self, length: int = 100) -> Tuple[np.ndarray, str]:
        trend = np.linspace(0, random.uniform(0.3, 0.8), length)
        noise = np.random.normal(0, 0.02, length)
        return trend + noise, 'buy'

    def generate_bearish_trend(self, length: int = 100) -> Tuple[np.ndarray, str]:
        trend = np.linspace(0, -random.uniform(0.3, 0.8), length)
        noise = np.random.normal(0, 0.02, length)
        return trend + noise, 'sell'

    def generate_sideways(self, length: int = 100) -> Tuple[np.ndarray, str]:
        base = np.zeros(length)
        noise = np.random.normal(0, 0.03, length)
        return base + noise, 'hold'

    def generate_breakout_up(self, length: int = 100) -> Tuple[np.ndarray, str]:
        base = np.zeros(length)
        k = random.randint(length // 3, 2 * length // 3)
        base[k:] += np.linspace(0.0, random.uniform(0.3, 0.6), length - k)
        noise = np.random.normal(0, 0.02, length)
        return base + noise, 'buy'

    def generate_breakdown(self, length: int = 100) -> Tuple[np.ndarray, str]:
        base = np.zeros(length)
        k = random.randint(length // 3, 2 * length // 3)
        base[k:] -= np.linspace(0.0, random.uniform(0.3, 0.6), length - k)
        noise = np.random.normal(0, 0.02, length)
        return base + noise, 'sell'

    def generate_consolidation(self, length: int = 100) -> Tuple[np.ndarray, str]:
        base = np.zeros(length)
        noise = np.random.normal(0, 0.015, length)
        return base + noise, 'hold'

    def generate_volatile(self, length: int = 100) -> Tuple[np.ndarray, str]:
        base = np.zeros(length)
        noise = np.random.normal(0, 0.08, length)
        return base + noise, 'hold'

    def generate_reversal_up(self, length: int = 100) -> Tuple[np.ndarray, str]:
        half = length // 2
        down = np.linspace(0.2, -0.1, half)
        up = np.linspace(-0.1, 0.3, length - half)
        series = np.concatenate([down, up])
        noise = np.random.normal(0, 0.02, length)
        return series + noise, 'buy'

    def generate_reversal_down(self, length: int = 100) -> Tuple[np.ndarray, str]:
        half = length // 2
        up = np.linspace(-0.2, 0.1, half)
        down = np.linspace(0.1, -0.3, length - half)
        series = np.concatenate([up, down])
        noise = np.random.normal(0, 0.02, length)
        return series + noise, 'sell'

    # --- Dataset generation ---

    def generate_dataset(self, samples_per_pattern: int = 500, width: int = 320, height: int = 200):
        dataset = []
        labels = []
        for pattern_name, generator in self.patterns.items():
            for _ in range(samples_per_pattern):
                prices, label = generator()
                chart_image = self.render_chart(prices, width=width, height=height)
                dataset.append(chart_image)
                labels.append(self.encode_label(label))
        X = np.array(dataset, dtype=np.uint8)
        y = np.array(labels, dtype=np.float32)
        # Shuffle
        idx = np.arange(len(X))
        np.random.shuffle(idx)
        return X[idx], y[idx]

    def render_chart(self, prices: np.ndarray, width: int = 320, height: int = 200) -> np.ndarray:
        fig, ax = plt.subplots(figsize=(width / 100.0, height / 100.0), dpi=100)
        ax.plot(prices, linewidth=2, color='#00ff00')
        ax.set_xlim(0, len(prices))
        ymin, ymax = float(np.min(prices)), float(np.max(prices))
        if ymin == ymax:
            ymin -= 0.01
            ymax += 0.01
        ax.set_ylim(ymin * 1.1, ymax * 1.1)
        ax.axis('off')
        fig.tight_layout(pad=0)

        fig.canvas.draw()
        buf = np.frombuffer(fig.canvas.tostring_rgb(), dtype=np.uint8)
        w, h = fig.canvas.get_width_height()
        buf = buf.reshape(h, w, 3)
        plt.close(fig)
        return buf

    @staticmethod
    def encode_label(label: str) -> List[float]:
        # [pBuy, pHold, pSell]
        if label == 'buy':
            return [1.0, 0.0, 0.0]
        if label == 'sell':
            return [0.0, 0.0, 1.0]
        return [0.0, 1.0, 0.0]  # hold


def save_dataset(X: np.ndarray, y: np.ndarray, out_dir: str = 'ai/vision/datasets', prefix: str = 'charts'):
    os.makedirs(out_dir, exist_ok=True)
    np.save(os.path.join(out_dir, f'{prefix}_images.npy'), X)
    np.save(os.path.join(out_dir, f'{prefix}_labels.npy'), y)


if __name__ == '__main__':
    gen = ChartPatternGenerator()
    X, y = gen.generate_dataset(samples_per_pattern=500, width=320, height=200)
    save_dataset(X, y)
    print(f'[Dataset] Generated X={X.shape}, y={y.shape} → ai/vision/datasets')


