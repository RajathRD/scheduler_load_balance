import os
import pandas as pd

from glob import glob

log_folder = "./logs"

def load_data(log_folder):
    log_paths = glob(os.path.join(log_folder, "*.log"))
    print(log_paths)
    log_data = [pd.read_csv(path, header=None) for path in log_paths]
    log_data = pd.concat(log_data)
    log_data.columns = ["id", "scheduler", "arrival_time", "duration", "start_time", "finish_time", "jct"]
    log_data = log_data.reset_index(drop=True)

    return log_data

def get_metrics(log_data):
    jct_min = log_data['jct'].min()
    jct_max = log_data['jct'].max()
    jct_mean = log_data['jct'].mean()
    print (f"JCT (Min, Max, Mean): {jct_min, jct_max, jct_mean}")


log_data = load_data(log_folder)
log_data.to_csv("log_data.csv")
print(log_data)
get_metrics(log_data)

