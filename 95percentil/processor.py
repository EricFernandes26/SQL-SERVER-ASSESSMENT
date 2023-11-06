import platform
import psutil

# Get the processor name
processor_name = platform.processor()

# Get the processor type
processor_type = platform.machine()

# Get the processor frequency in GHz
processor_freq = psutil.cpu_freq().current / 1000  # Convert to GHz

print("Processor Name:", processor_name)
print("Processor Type:", processor_type)
print(f"Processor Frequency (GHz): {processor_freq:.2f}")
