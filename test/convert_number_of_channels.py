import pandas as pd

# Configuration: set these variables as needed
input_file = "input_data.csv"       # Path to the input CSV file
num_columns = 2               # Desired number of columns (set to None for single-row output)
output_file = f"input_data_{num_columns}ch.csv"     # Path to the output CSV file

# Read the data into a DataFrame
df = pd.read_csv(input_file, header=None)
values = df.iloc[:, 0]

if num_columns:
    # Duplicate the single column into the desired number of columns
    df_out = pd.concat([values] * num_columns, axis=1)
    # Assign integer column names (optional)
    df_out.columns = range(1, num_columns + 1)
    # Convert to integer type
    df_out = df_out.astype(int)
else:
    # Transpose to a single row
    df_out = pd.DataFrame(values).T
    # Convert to integer type
    df_out = df_out.astype(int)

# Save to output CSV without index or header (integers only)
df_out.to_csv(output_file, index=False, header=False)

# Informational message
if num_columns:
    print(f"Data has been duplicated into {num_columns} columns in {output_file}.")
else:
    print(f"Data has been written as a single row with {df_out.shape[1]} columns in {output_file}.")
