import pandas as pd
import numpy as np
import matplotlib.pylab as plt

a = pd.read_csv('input_data.csv')

# Save chunk from 8000 to 16000 (assuming row indices)
chunk = a.iloc[8000:16000]
chunk.to_csv('test_spike_detection.csv', index=False)

print(a.values)

fig, ax = plt.subplots(figsize=(10, 6))
ax.plot(a.values, linestyle='-', color='b', label='Data Points')
ax.set_title('Input Data Plot')

plt.show()
