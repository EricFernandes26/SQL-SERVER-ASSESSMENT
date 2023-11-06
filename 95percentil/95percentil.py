import psutil

# Coleta de dados de utilização da CPU e memória
cpu_usage = []
memory_usage = []

for i in range(10):  # Coletando dados de 10 leituras
    cpu_usage.append(psutil.cpu_percent(interval=1))  # Coleta da utilização da CPU
    memory_usage.append(psutil.virtual_memory().percent)  # Coleta do uso da memória

# Ordenar os dados coletados
cpu_usage.sort()
memory_usage.sort()

# Cálculo do percentil 95 para CPU e memória
percentile_95_cpu = int(len(cpu_usage) * 0.95)
p95_cpu = cpu_usage[percentile_95_cpu]

percentile_95_memory = int(len(memory_usage) * 0.95)
p95_memory = memory_usage[percentile_95_memory]

# Cálculo da média de utilização para CPU e memória
avg_cpu = sum(cpu_usage) / len(cpu_usage)
avg_memory = sum(memory_usage) / len(memory_usage)

# Exibição formatada dos resultados com duas casas decimais
print(f'O percentil 95 da utilização da CPU é: {p95_cpu:.2f}%')
print(f'A média de utilização da CPU é: {avg_cpu:.2f}%')

print(f'O percentil 95 do uso de memória é: {p95_memory:.2f}%')
print(f'A média do uso de memória é: {avg_memory:.2f}%')
