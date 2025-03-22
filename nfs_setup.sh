#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền root."
  exit 1
fi

# Lấy địa chỉ IP của VPS
get_ip() {
  hostname -I | awk '{print $1}'
}

# Cài đặt NFS Server trên Ubuntu/Debian
install_nfs_server_ubuntu() {
  apt update
  apt install nfs-kernel-server -y
}

# Cài đặt NFS Server trên CentOS/RHEL
install_nfs_server_centos() {
  yum install nfs-utils -y
  systemctl enable nfs-server
  systemctl start nfs-server
}

# Tạo thư mục chia sẻ
create_shared_directories() {
  mkdir -p /mnt/nfs/downloads
  mkdir -p /mnt/nfs/temp
  chown nobody:nogroup /mnt/nfs/downloads
  chown nobody:nogroup /mnt/nfs/temp
  chmod 777 /mnt/nfs/downloads
  chmod 777 /mnt/nfs/temp
}

# Cấu hình NFS Exports
configure_exports() {
  local ip_vps1="$1"
  local ip_vps2="$2"

  echo "/mnt/nfs/downloads $ip_vps1(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/mnt/nfs/downloads $ip_vps2(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/mnt/nfs/temp $ip_vps1(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/mnt/nfs/temp $ip_vps2(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports

  exportfs -a
}

# Khởi động lại dịch vụ NFS
restart_nfs_service() {
  if [[ -f /etc/debian_version ]]; then
    systemctl restart nfs-kernel-server
  else
    systemctl restart nfs-server
  fi
}

# Cấu hình Firewall cho Ubuntu UFW hoặc CentOS firewalld
configure_firewall() {
  local ip_vps1="$1"
  local ip_vps2="$2"

  if command -v ufw &> /dev/null; then
    ufw allow from "$ip_vps1" to any port nfs
    ufw allow from "$ip_vps2" to any port nfs
  elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --zone=public --add-service=nfs
    firewall-cmd --permanent --zone=public --add-service=mountd
    firewall-cmd --permanent --zone=public --add-service=rpc-bind
    firewall-cmd --reload
  else
    echo "Không tìm thấy công cụ quản lý tường lửa."
    exit 1
  fi
}

# Cài đặt NFS Client trên Ubuntu/Debian hoặc CentOS/RHEL
install_nfs_client() {
  if [[ -f /etc/debian_version ]]; then 
    apt update && apt install nfs-common -y 
  else 
    yum install nfs-utils -y 
  fi 
}

# Tạo thư mục mount point cho NFS Client 
create_mount_points() {
  mkdir -p /mnt/nfs/downloads 
  mkdir -p /mnt/nfs/temp 
}

# Mount thư mục NFS trên Client 
mount_nfs() {
  local ip_vps_chinh="$1"
  
  mount "$ip_vps_chinh:/mnt/nfs/downloads" /mnt/nfs/downloads 
  mount "$ip_vps_chinh:/mnt/nfs/temp" /mnt/nfs/temp 
}

# Kiểm tra mount đã thành công 
check_mount_success() {
  df -h 
}

# Cấu hình auto-mount khi khởi động trên Client 
configure_auto_mount() {
  local ip_vps_chinh="$1"

cat <<EOF >> /etc/fstab
$ip_vps_chinh:/mnt/nfs/downloads /mnt/nfs/downloads nfs rw,sync,hard,intr 0 0 
$ip_vps_chinh:/mnt/nfs/temp /mnt/nfs/temp nfs rw,sync,hard,intr 0 0 
EOF

}

# Chạy script chính 
main() {
  
echo "Thiết lập NFS Server..."
local ip_vps1=$(get_ip)
echo "Địa chỉ IP của VPS chính (NFS Server): $ip_vps1"

read -p "Nhập địa chỉ IP của VPS khác (NFS Client): " ip_vps2 

if [[ -f /etc/debian_version ]]; then 
   install_nfs_server_ubuntu 
else 
   install_nfs_server_centos 
fi 

create_shared_directories 
configure_exports "$ip_vps1" "$ip_vps2" 
restart_nfs_service 
configure_firewall "$ip_vps1" "$ip_vps2" 

echo "Thiết lập NFS Client..."
local ip_vps_chinh=$(get_ip)
echo "Địa chỉ IP của VPS Client: $ip_vps_chinh"

install_nfs_client 
create_mount_points 
mount_nfs "$ip_vps_chinh" 
check_mount_success 
configure_auto_mount "$ip_vps_chinh" 

echo "Hoàn tất thiết lập NFS!"
}

main "$@"
