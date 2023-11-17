import os
import psutil
import pandas as pd

# Função para recomendar a instância com base nas métricas
def recommend_instance(percentil95_SQLProcessUtilization, percentil95_AvaiMemKB):
    if percentil95_SQLProcessUtilization <= 5 and percentil95_AvaiMemKB <= 5:
        return 't3.nano'
    elif percentil95_SQLProcessUtilization <= 10 and percentil95_AvaiMemKB <= 10:
        return 't3.small'
    elif percentil95_SQLProcessUtilization >= 20 and percentil95_AvaiMemKB >= 20:
        return 't3.medium'
    elif percentil95_SQLProcessUtilization >= 30 and percentil95_AvaiMemKB >= 30:
        return 't3.large'
    elif percentil95_SQLProcessUtilization >= 40 and percentil95_AvaiMemKB >= 40:
        return 'm5.large'
    elif percentil95_SQLProcessUtilization >= 50 and percentil95_AvaiMemKB >= 50:
        return 'm5.xlarge'
    elif percentil95_SQLProcessUtilization >= 60 and percentil95_AvaiMemKB >= 60:
        return 'm5.2xlarge'
    elif percentil95_SQLProcessUtilization >= 70 and percentil95_AvaiMemKB >= 70:
        return 'r6i.8xlarge'
    elif percentil95_SQLProcessUtilization >= 80 and percentil95_AvaiMemKB >= 80:
        return 'r6i.12xlarge'
    elif percentil95_SQLProcessUtilization >= 90 and percentil95_AvaiMemKB >= 90:
        return 'r6i.16xlarge'
    elif percentil95_SQLProcessUtilization >= 100 or percentil95_AvaiMemKB >= 100:
        return 'x2iedn.32xlarge'
    else:
        return 't3.small'  # Defina o tipo de instância padrão

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

# Recomendação da instância com base nos percentis calculados
instance_type = recommend_instance(p95_cpu, p95_memory)

# Especificar o diretório para salvar o arquivo
output_directory = 'results'
os.makedirs(output_directory, exist_ok=True)

# Caminho completo para o arquivo CSV
output_file_path = os.path.join(output_directory, 'recomendacao_instancia.csv')

# Criar um DataFrame com os resultados
df = pd.DataFrame({
    'Percentil95_CPU': [p95_cpu],
    'Percentil95_Memory': [p95_memory],
    'Avg_CPU': [avg_cpu],
    'Avg_Memory': [avg_memory],
    'InstanceType': [instance_type]
})

# Exportar para CSV com formatação amigável
df.to_csv(output_file_path, sep=';', decimal=',', index=False)

print(f'O arquivo CSV foi salvo em: {output_file_path}')
