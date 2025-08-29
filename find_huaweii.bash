#!/bin/bash

check_huawei() {
    local ip=$1
    local response=$(curl -s -I -m 2 http://$ip/ 2>/dev/null | grep -i "server:")
    
    if [[ $response == *"Huawei"* ]] || [[ $response == *"HW"* ]]; then
        echo "Найден Huawei-роутер: $ip"
        echo "Заголовок сервера: $response"
        exit 0
    fi
}


scan_network() {
    echo "Начинаю сканирование сети..."
    
    # Получаем текущий шлюз по умолчанию
    local gateway=$(ip route | grep default | awk '{print $3}')
    echo "Текущий шлюз: $gateway"
    
   
    check_huawei $gateway
    
    local network_info=$(ip -o -f inet addr show | awk '/scope global/ {print $2,$4}')
    while read -r interface cidr; do
        echo "Сканирую сеть: $cidr на интерфейсе $interface"
        
        local base_ip=$(echo $cidr | cut -d'/' -f1)
        local prefix=$(echo $cidr | cut -d'/' -f2)
        
        local network=$(ipcalc -n $cidr | cut -d'=' -f2)
        local broadcast=$(ipcalc -b $cidr | cut -d'=' -f2)
        
        echo "Диапазон для сканирования: $network - $broadcast"
        
        local base=$(echo $network | cut -d'.' -f1-3)
        for i in {1..20} {230..254}; do
            check_huawei "$base.$i" &
        done       
        wait
    done <<< "$network_info"
}

scan_network

echo "Huawei-роутер не найден в сети."
exit 1
