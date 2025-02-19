#!/bin/bash
curl -s https://raw.githubusercontent.com/HydraSql/HydraSql/refs/heads/main/my/logo.sh | bash
sleep 5
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERSION="0.5.0"

NEXUS_HOME="$HOME/.nexus"
NODE_ID_FILE="$NEXUS_HOME/node-id"
SESSION_NAME="nexus-network"
ARCH=$(uname -m)
OS=$(uname -s)

check_and_install_git() {
    if ! command -v git &> /dev/null; then
        if [ "$OS" = "Darwin" ]; then
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}Silakan instal terlebih dahulu Homebrew: https://brew.sh${NC}"
                exit 1
            fi
            brew install git
        elif [ "$OS" = "Linux" ]; then
            if command -v apt &> /dev/null; then
                echo -e "${YELLOW}Menginstal git...${NC}"
                sudo apt update && sudo apt install -y git
            elif command -v yum &> /dev/null; then
                echo -e "${YELLOW}Menginstal git...${NC}"
                sudo yum install -y git
            else
                echo -e "${RED}Gagal mengenali pengelola paket, silakan instal secara manual git${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Sistem operasi yang tidak didukung${NC}"
            exit 1
        fi
    fi
}

check_and_install_rust() {
    # Periksa apakah itu ada cargo env file dan aktifkan lingkungan
    if [ -f "$HOME/.cargo/env" ]; then
        echo -e "${YELLOW}Terpasang terdeteksi Rust，Mengaktifkan lingkungan...${NC}"
        source "$HOME/.cargo/env"
    elif ! command -v rustc &> /dev/null; then
        echo -e "${YELLOW}RustTidak diinstal，Menginstal...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source "$HOME/.cargo/env"
        if [ $? -ne 0 ]; then
            echo -e "${RED}RustInstalasi gagal${NC}"
            exit 1
        fi
    fi
}

setup_directories() {
    if [ ! -d "$NEXUS_HOME" ]; then
        echo -e "${YELLOW}menciptakan $NEXUS_HOME direktori...${NC}"
        mkdir -p "$NEXUS_HOME"
    fi

    if [ ! -d "$NEXUS_HOME/network-api" ]; then
        echo -e "${YELLOW}Clone network-api gudang...${NC}"
        cd "$NEXUS_HOME"
        git clone https://github.com/nexus-xyz/network-api.git
        if [ $? -ne 0 ]; then
            echo -e "${RED}Kloning gudang gagal${NC}"
            exit 1
        fi
    fi
}

check_system_compatibility() {
    local is_compatible=false
    if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
        is_compatible=true
        BINARY_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/nexus-network-linux-x86"
        EXAMPLE_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/example-linux-x86"
    elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ]; then
        is_compatible=true
        BINARY_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/nexus-network-macos-arm64"
        EXAMPLE_URL="https://github.com/qzz0518/nexus-run/releases/download/v$VERSION/example-macos-arm64"
    fi

    if [ "$is_compatible" = false ]; then
        echo -e "${RED}Sistem atau arsitektur yang tidak didukung: $OS $ARCH${NC}"
        exit 1
    fi
}

download_binary() {
    local binary_path="$NEXUS_HOME/network-api/clients/cli/nexus-network"
    local example_path="$NEXUS_HOME/network-api/clients/cli/example"
    
    if [ ! -f "$binary_path" ]; then
        echo -e "${YELLOW}Unduh program utama...${NC}"
        curl -L "$BINARY_URL" -o "$binary_path"
        if [ $? -eq 0 ]; then
            chmod +x "$binary_path"
            echo -e "${GREEN}Unduhan program utama selesai{NC}"
        else
            echo -e "${RED}Unduhan program utama gagal${NC}"
            exit 1
        fi
    fi

    if [ ! -f "$example_path" ]; then
        echo -e "${YELLOW}Mengunduh example Prosedur...${NC}"
        curl -L "$EXAMPLE_URL" -o "$example_path"
        if [ $? -eq 0 ]; then
            chmod +x "$example_path"
            echo -e "${GREEN}example Pengunduhan program selesai{NC}"
        else
            echo -e "${RED}example Pengunduhan program gagal${NC}"
            exit 1
        fi
    fi
}

start_network() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}NetworkSudah berjalan，Silakan pilih 3 untuk melihat log eksekusi${NC}"
        return
    fi

    cd "$NEXUS_HOME/network-api/clients/cli" || exit

    tmux new-session -d -s "$SESSION_NAME" "cd '$NEXUS_HOME/network-api/clients/cli' && ./nexus-network --start --beta"
    echo -e "${GREEN}Network Dimulai, pilih 3 untuk melihat log eksekusi${NC}"
}

check_status() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}NetworkMenjalankan. Jendela log terbuka...${NC}"
        echo -e "${YELLOW}Tip: Setelah melihat, tutup saja terminal dan jangan gunakan Ctrl+C${NC}"
        sleep 2
        tmux attach-session -t "$SESSION_NAME"
    else
        echo -e "${RED}Network tidak berjalan${NC}"
    fi
}

show_node_id() {
    if [ -f "$NODE_ID_FILE" ]; then
        local id=$(cat "$NODE_ID_FILE")
        echo -e "${GREEN}arus Node ID: $id${NC}"
    else
        echo -e "${RED}Tidak ditemukan Node ID${NC}"
    fi
}

set_node_id() {
    read -p "Silakan masukkan yang baru Node ID: " new_id
    if [ -n "$new_id" ]; then
        echo "$new_id" > "$NODE_ID_FILE"
        echo -e "${GREEN}Node ID Diperbarui${NC}"
    else
        echo -e "${RED}Node ID Itu tidak bisa kosong${NC}"
    fi
}

stop_network() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
        echo -e "${GREEN}NetworkDihentikan${NC}"
    else
        echo -e "${RED}NetworkTidak berjalan${NC}"
    fi
}

update_nexus() {
    echo -e "${YELLOW}Mulai pembaruan Nexus...${NC}"

    stop_network

    cd "$NEXUS_HOME/network-api"
    git pull

    rm -f "$NEXUS_HOME/network-api/clients/cli/nexus-network"
    rm -f "$NEXUS_HOME/network-api/clients/cli/example"
    download_binary

    echo -e "${GREEN}Pembaruan selesai! Mulai Network...${NC}"
    start_network
}

cleanup() {
    echo -e "\n${YELLOW}Membersihkan...${NC}"
    exit 0
}

install_network() {
    echo -e "${YELLOW}Mulai instalasi Nexus Network...${NC}"
    check_system_compatibility
    check_and_install_git
    check_and_install_rust
    setup_directories
    download_binary
    echo -e "${GREEN}Instalasi selesai！${NC}"
}

trap cleanup SIGINT SIGTERM

while true; do
#!/bin/bash
curl -s https://raw.githubusercontent.com/HydraSql/HydraSql/refs/heads/main/my/logo.sh | bash
sleep 5

    echo "1. Instalasi Network"
    echo "2. Memulai Network"
    echo "3. Lihat status operasional saat ini"
    echo "4. Melihat Node ID"
    echo "5. Mengatur Node ID"
    echo "6. Stop Network"
    echo "7. pemutakhiran Network"
    echo "8. berhenti"

    read -p "Pilih tindakan [1-8]: " choice
    case $choice in
        1)
            install_network
            ;;
        2)
            if [ ! -f "$NEXUS_HOME/network-api/clients/cli/nexus-network" ]; then
                echo -e "${RED}Silakan instal terlebih dahulu Network（Pilihan1）${NC}"
            else
                if [ ! -f "$NODE_ID_FILE" ]; then
                    echo -e "${YELLOW}Tidak terdeteksi Node ID，Silakan atur terlebih dahulu${NC}"
                    set_node_id
                fi
                if [ -f "$NODE_ID_FILE" ]; then
                    start_network
                fi
            fi
            ;;
        3)
            check_status
            ;;
        4)
            show_node_id
            ;;
        5)
            set_node_id
            ;;
        6)
            stop_network
            ;;
        7)
            update_nexus
            ;;
        8)
            #!/bin/bash
            curl -s https://raw.githubusercontent.com/HydraSql/HydraSql/refs/heads/main/my/logo.sh | bash
            sleep 5
            cleanup
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid${NC}"
            ;;
    esac
done
