import matplotlib
matplotlib.use('Agg')  # Force non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
try:
    import tensorflow as tf
    _HAS_TF = True
except Exception:
    tf = None
    _HAS_TF = False
from PIL import Image


def test_vision_model_diversity():
    """Test if the new model produces diverse outputs for different inputs"""

    if _HAS_TF:
        interpreter = tf.lite.Interpreter(model_path='assets/models/vision_fp16.tflite')
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        expected_shape = input_details[0]['shape']
        print(f'Model expects input shape: {expected_shape}')
    else:
        expected_shape = [1, 200, 320, 3]
        print('TensorFlow not available; using fallback expected shape [1,200,320,3] and skipping inference.')

    # Test with different synthetic patterns using expected input shape
    test_cases = [
        create_bullish_chart(expected_shape),
        create_bearish_chart(expected_shape),
        create_sideways_chart(expected_shape),
        create_volatile_chart(expected_shape),
    ]

    outputs = []
    for i, chart in enumerate(test_cases):
        print(f'Test case {i+1} input shape: {chart.shape}')
        # Save chart preview for inspection
        Image.fromarray((chart[0] * 255).astype(np.uint8)).save(f'test_chart_{i+1}.png')
        if _HAS_TF:
            interpreter.set_tensor(input_details[0]['index'], chart)
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]['index'])
            outputs.append(output[0])
            print(f'Test case {i+1}: {np.round(output[0], 3)}')

    # Check diversity
    if _HAS_TF and outputs:
        outputs = np.array(outputs)
        variance = np.var(outputs, axis=0)
        print(f'Output variance across test cases: {np.round(variance, 4)}')
        print(f'Max variance: {np.max(variance):.6f}')
        if np.max(variance) > 0.01:
            print('✅ Model shows some diversity')
        else:
            print('❌ Model still lacks diversity')
    else:
        print('Saved test_chart_*.png without running inference (TensorFlow unavailable).')


def create_bullish_chart(target_shape):
    prices = np.cumsum(np.random.normal(0.01, 0.02, 100)) + 100
    return render_test_chart(prices, target_shape)


def create_bearish_chart(target_shape):
    prices = np.cumsum(np.random.normal(-0.01, 0.02, 100)) + 100
    return render_test_chart(prices, target_shape)


def create_sideways_chart(target_shape):
    prices = np.random.normal(100, 0.5, 100)
    return render_test_chart(prices, target_shape)


def create_volatile_chart(target_shape):
    prices = np.cumsum(np.random.normal(0.0, 0.05, 100)) + 100
    return render_test_chart(prices, target_shape)


def render_test_chart(prices, target_shape):
    """Render chart with exact dimensions the model expects"""
    plt.ioff()

    # target_shape is [batch, height, width, channels]
    height = int(target_shape[1])
    width = int(target_shape[2])

    fig, ax = plt.subplots(figsize=(width/100, height/100), dpi=100)
    ax.plot(prices, linewidth=2, color='#00ff00')
    ax.set_xlim(0, len(prices))
    if len(prices) > 0:
        price_range = float(np.max(prices) - np.min(prices))
        if price_range > 0:
            ax.set_ylim(float(np.min(prices)) - price_range*0.1, float(np.max(prices)) + price_range*0.1)
        else:
            ax.set_ylim(-1, 1)
    ax.axis('off')
    ax.set_facecolor('black')
    fig.patch.set_facecolor('black')

    fig.canvas.draw()
    buf = np.frombuffer(fig.canvas.tostring_argb(), dtype=np.uint8)
    buf = buf.reshape(fig.canvas.get_width_height()[::-1] + (4,))
    rgb_buf = np.zeros((buf.shape[0], buf.shape[1], 3), dtype=np.uint8)
    rgb_buf[:, :, 0] = buf[:, :, 1]  # R
    rgb_buf[:, :, 1] = buf[:, :, 2]  # G
    rgb_buf[:, :, 2] = buf[:, :, 3]  # B
    plt.close(fig)

    image = Image.fromarray(rgb_buf)
    image = image.resize((width, height), Image.Resampling.LANCZOS)
    return np.array(image).reshape(1, height, width, 3).astype(np.float32) / 255.0


if __name__ == '__main__':
    test_vision_model_diversity()


