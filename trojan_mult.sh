#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi

function install_trojan(){
$systemPackage -y install net-tools

red "===输入一个未占用的端口号："
read new_port
red "===输入cer证书位置："
read new_cer
red "===输入key证书位置："
read new_key

if [ "$release" == "centos" ]; then
    if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop firewalld
    systemctl disable firewalld
elif [ "$release" == "ubuntu" ]; then
    if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop ufw
    systemctl disable ufw
    apt-get update
fi
$systemPackage -y install wget unzip zip curl tar >/dev/null 2>&1
green "======================="
blue "请输入绑定到本VPS的域名"
green "======================="
read your_domain
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
	green "=========================================="
	green "       域名解析正常，开始安装trojan"
	green "=========================================="
	sleep 1s
	# 
	if test -s $new_cer; then
        cd /usr/src
	#wget https://github.com/trojan-gfw/trojan/releases/download/v1.13.0/trojan-1.13.0-linux-amd64.tar.xz
	wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest
	latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
	wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz
	tar xf trojan-${latest_version}-linux-amd64.tar.xz
	#下载trojan客户端
	wget https://github.com/atrandys/trojan/raw/master/trojan-cli.zip
	wget -P /usr/src/trojan-temp https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-win.zip
	unzip trojan-cli.zip
	unzip /usr/src/trojan-temp/trojan-${latest_version}-win.zip -d /usr/src/trojan-temp/
	cp $new_cer /usr/src/trojan-cli/fullchain.cer
	mv -f /usr/src/trojan-temp/trojan/trojan.exe /usr/src/trojan-cli/ 
	trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
	cat > /usr/src/trojan-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": $new_port,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
	rm -rf /usr/src/trojan/server.conf
	cat > /usr/src/trojan/server.conf <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $new_port,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "$new_cer",
        "key": "$new_key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF
	cd /usr/src/trojan-cli/
	zip -q -r trojan-cli.zip /usr/src/trojan-cli/
	trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 16)
	#增加启动脚本
	
cat > ${systempwd}trojan.service <<-EOF
[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
ExecReload=  
ExecStop=/usr/src/trojan/trojan  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target
EOF

	chmod +x ${systempwd}trojan.service
	systemctl start trojan.service
	systemctl enable trojan.service
	green "======================================================================"
	green "Trojan已安装完成，请使用以下方法下载trojan客户端，此客户端已配置好所有参数"
	green "1、下载以下文件"
	blue "/usr/src/trojan-cli/trojan-cli.zip"
	green "2、将下载的压缩包解压，打开文件夹，打开start.bat即打开并运行Trojan客户端"
	green "3、打开stop.bat即关闭Trojan客户端"
	green "4、Trojan客户端需要搭配浏览器插件使用，例如switchyomega等"
	green "======================================================================"
	else
        red "==================================="
	red "https证书位置错误"
	red "==================================="
	fi
	
else
	red "================================"
	red "域名解析地址与本VPS IP地址不一致"
	red "本次安装失败，请确保域名解析正常"
	red "================================"
fi
}

function repair_cert(){
green "===========空============"	
}

function remove_trojan(){
    red "================================"
    red "即将卸载trojan"
    red "================================"
    systemctl stop trojan
    systemctl disable trojan
    rm -f ${systempwd}trojan.service
    rm -rf /usr/src/trojan*
    green "=============="
    green "trojan删除完毕"
    green "=============="
}

function update_trojan(){
    green "======================"
    green "开发中"
    green "======================"
}

start_menu(){
    clear
    green " ===================================="
    green " 介绍：一键安装trojan      "
    green " 系统：centos7+/debian9+/ubuntu16.04+"
    green " 网站：www.atrandys.com              "
    green " Youtube：Randy's 堡垒                "
    green " ===================================="
    echo
    green " 1. 安装trojan"
    red " 2. 卸载trojan"
    green " 3. 升级trojan"
    green " 4. 修复证书"
    blue " 0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    install_trojan
    ;;
    2)
    remove_trojan 
    ;;
    3)
    update_trojan 
    ;;
    4)
    repair_cert 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "请输入正确数字"
    sleep 1s
    start_menu
    ;;
    esac
}

start_menu
