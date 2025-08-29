#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

check_router() {
    local ip=$1
    local router_found=false
    
    echo -e "${BLUE}Проверяем $ip...${NC}"
    
    local ports=$(timeout 2 nc -z -v -w1 $ip 22 80 81 88 443 7547 8080 2>&1 | grep succeeded | awk '{print $4}' | tr '\n' ' ')
    
    local http_response=$(timeout 3 curl -s -I http://$ip/ 2>/dev/null)
    local server_header=$(echo "$http_response" | grep -i "server:" | tr -d '\r')
    local location_header=$(echo "$http_response" | grep -i "location:" | tr -d '\r')
    
    local upnp_response=$(timeout 2 curl -s -H 'ST: upnp:rootdevice' -H 'MAN: "ssdp:discover"' -H 'MX: 1' http://$ip:1900/ 2>/dev/null)
    
    local admin_response=$(timeout 2 curl -s http://$ip/admin/ 2>/dev/null | head -20)
    
    if [[ -n "$ports" ]]; then
        echo -e "${YELLOW}Обнаружены открытые порты: $ports${NC}"
        router_found=true
    fi
    
    if [[ -n "$server_header" ]]; then
        echo -e "${YELLOW}HTTP-сервер: $server_header${NC}"
        
        if echo "$server_header" | grep -qi "router\|asus\|tplink\|d-link\|linksys\|netgear\|huawei\|zyxel\|mikrotik\|ubiquiti\|edgeos"; then
            echo -e "${GREEN}Обнаружен роутер: $ip (по заголовку сервера)${NC}"
            echo "$ip - $server_header" >> found_routers.txt
            return 0
        fi
        router_found=true
    fi
    
    if [[ -n "$location_header" ]]; then
        echo -e "${YELLOW}Перенаправление: $location_header${NC}"
        router_found=true
    fi
    
    if [[ -n "$upnp_response" ]]; then
        echo -e "${GREEN}Обнаружен UPnP-устройство (вероятно роутер): $ip${NC}"
        echo "$ip - UPnP устройство" >> found_routers.txt
        return 0
    fi
    
    if [[ -n "$admin_response" ]] && echo "$admin_response" | grep -qi "login\|password\|router\|admin"; then
        echo -e "${GREEN}Обнаружена административная панель: $ip${NC}"
        echo "$ip - Веб-интерфейс" >> found_routers.txt
        return 0
    fi
    
    if $router_found; then
        echo -e "${YELLOW}Возможный роутер: $ip (требуется дополнительная проверка)${NC}"
        echo "$ip - Неопознанное сетевое устройство" >> possible_routers.txt
    fi
    
    return 1
}

scan_network() {
    echo -e "${BLUE}Определяем сетевые интерфейсы...${NC}"
    
    local interfaces=$(ip -o -4 addr show | awk '{print $2}' | uniq)
    echo -e "Найдены интерфейсы: $interfaces"
    
    > found_routers.txt
    > possible_routers.txt
    
    for interface in $interfaces; do
        if [[ "$interface" == "lo" || "$interface" == docker* ]]; then
            continue
        fi
        
        echo -e "${BLUE}Сканируем интерфейс $interface...${NC}"
        
        local network=$(ip -o -4 addr show dev $interface | awk '{print $4}')
        if [[ -z "$network" ]]; then
            continue
        fi
        
        echo -e "Сканируем сеть: $network"
        
        local base_ip=$(echo $network | cut -d'/' -f1)
        local prefix=$(echo $network | cut -d'/' -f2)
        
        local base=$(echo $base_ip | cut -d'.' -f1-3)
        
        echo -e "${BLUE}Сканируем диапазон...${NC}"
        
        for i in {1..10} {125..134}; do
            check_router "$base.$i" &
            if (( $i % 10 == 0 )); then
                wait
            fi
        done
        wait
    done
    
    echo -e "\n${GREEN}=== РЕЗУЛЬТАТЫ СКАНИРОВАНИЯ ===${NC}"
    
    if [[ -s found_routers.txt ]]; then
        echo -e "${GREEN}Обнаруженные роутеры:${NC}"
        cat found_routers.txt
    else
        echo -e "${YELLOW}Роутеры не обнаружены${NC}"
    fi
    
    if [[ -s possible_routers.txt ]]; then
        echo -e "${YELLOW}Возможные сетевые устройства:${NC}"
        cat possible_routers.txt
    fi
    
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -n "$gateway" ]]; then
        echo -e "${BLUE}Проверяем шлюз по умолчанию: $gateway${NC}"
        check_router "$gateway"
    fi
}

check_dependencies() {
    local deps=("nc" "curl" "ip")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo -e "${RED}Ошибка: Не найдена утилита $dep${NC}"
            exit 1
        fi
    done
}

main() {
    echo -e "${GREEN}=== СКАНЕР СЕТЕВЫХ УСТРОЙСТВ ===${NC}"
    echo -e "Поиск роутеров и сетевого оборудования\n"
    
    check_dependencies
    
    scan_network
    
    echo -e "\n${GREEN}Сканирование завершено${NC}"
}

main "$@"
