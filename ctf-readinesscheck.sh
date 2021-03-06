#!/bin/bash
#Readiness check script for CTFs
#Aug, 2021
#V1.0
#danieldavidson



#Define Colours
colour(){
	if [ $# -lt 2 ]; then
		exit 1
	fi	
	case "$1" in
		"green")
			printf "\033[01;32m$2\033[0m\n"
			;;
		"red")
			printf "\033[01;31m$2\033[0m\n"
			;;
		"header")
			printf "\033[0;1;4m$2\033[0m\n"
			;;
		"code")
			printf "\033[01;31;47m$2\033[0m\n"
			;;
		"warning")
			printf "\033[01;93m[Warning!]\033[0m $2\n"
			;;
		"process")
			printf "\033[01;94m$2\033[0m\n"
			;;
		*)
			return 1
			;;
	esac
	if [ $# -eq 3 ]; then
		sleep $3s
	fi
}

fin(){
	printf "\n\n"
	exit 1
}


connect(){
	testSuccess() ( if grep -qio "Initialization Sequence Completed" $ovpnoutput;then return 0; else return 1;fi )
	testCert() ( if grep -qioE "Cannot load inline certificate file|certificate verify failed|cannot load CA" $ovpnoutput;then return 0; else return 1;fi )
	ovpnoutput=$(mktemp)
	openvpn $ovpn </dev/null &>$ovpnoutput &
	colour process "[+] Connecting...." 10
	for i in {1..2};do
		if testSuccess; then
			colour green "[+] Connection Process completed successfully!" 1
			return 1
		elif testCert; then
			killall -9 openvpn &>/dev/null 2>/dev/null
			colour red "[-] Fatal Error: Inline Certificate is invalid" 1
			printf "Please regenerate your VPN config on the access page (https://tryhackme.com/access)\nIf errors persist, change server then regenerate the config.\nIf all else fails, ask for further assistance on the TryHackMe Discord server, subreddit or forums.\n"
			colour red "[-] Exiting" 2
			return 0
		fi
		if [ $i -le 1 ]; then
			colour warning "Connection process is taking longer than expected to complete" 30
		else
			colour red "[-] Failed to connect" 1
			printf "Failure to connect to the VPN can usually be solved by one of the following options:\n"
			printf "	-Regenerating your OpenVPN config on the TryHackMe access page (https://tryhackme.com/access)\n"
			printf "	-Switching servers, then regenerating your OpenVPN config\n"
			printf "	-Checking your system time. If your system time is incorrect then this can cause issues with the authentication process\n"
			printf "If none of these methods work, please ask for further assistance in the TryHackMe Discord server, subreddit or forums.\n"
			colour red "[-] Exiting" 2
			return 0
		fi
	done
}


#Banner
banner(){
	printf "\n\n\033[0;1;32m"
	cat << "EOF"
	
 _____ ___________  ______               _ _                       _____ _               _    
/  __ \_   _|  ___| | ___ \             | (_)                     /  __ \ |             | |   
| /  \/ | | | |_    | |_/ /___  __ _  __| |_ _ __   ___  ___ ___  | /  \/ |__   ___  ___| | __
| |     | | |  _|   |    // _ \/ _` |/ _` | | '_ \ / _ \/ __/ __| | |   | '_ \ / _ \/ __| |/ /
| \__/\ | | | |     | |\ \  __/ (_| | (_| | | | | |  __/\__ \__ \ | \__/\ | | |  __/ (__|   < 
 \____/ \_/ \_|     \_| \_\___|\__,_|\__,_|_|_| |_|\___||___/___/  \____/_| |_|\___|\___|_|\_\
                                                                                                
EOF
	printf "\033[0;35m						@danieldavidson\033[0m\n\n\n"
}


if [ ! -f /tmp/ctf-rc-banner ]; then
	banner
else
	colour green "[+] Re-running with root permissions" 1
	rm /tmp/ctf-rc-banner
fi


sleep 1s


#Check that the script is being run with sudo
if [[ $EUID -ne 0 ]]; then
	colour red "[-] Script is being run as a low-privileged user" 1
	read -p "Would you like to run this script with higher privileges automatically (Y/n)? "  choice
	case "$choice" in
		n|N)
			printf "\n\nPlease run the script with the following command:\n"
			colour code "sudo $0" 1
			colour red "[-] Exiting" 2
			fin
			;;
		*)
			touch /tmp/ctf-rc-banner
			sudo -E $0
			;;
	esac
	fin
fi


#Check Internet connectivity
if [ $(ping -c 1 -q 1.1.1.1 >&/dev/null; echo $?)  -gt 0 ]; then
	colour red "[-] You are not connected to the internet" 1
	colour red "[-] Exiting" 2
	fin
else
	colour green "[+] Stable internet connection" 1
fi


#Check for toolkit
colour process "[*] Checking for toolkit items" 2
apt update &>/dev/null && apt install npm python3-pip tree geany gedit remmina shellcheck guake git -y
curl -L "https://go.microsoft.com/fwlink/?LinkID=760868" > /tmp/vscode.deb && apt install /tmp/vscode.deb -y && sudo rm /tmp/vscode.deb
yes | npm install -g tldr
yes | pip3 install updog
yes | pip3 install search-that-hash
yes | pip3 install name-that-hash

#Check Openvpn is installed
if ! dpkg-query -W -f='${Status}' openvpn &>/dev/null; then
	colour red "[-] OpenVPN is not installed" 1
	read -p "Would you like to install OpenVPN automatically (Y/n)? " choice
	case "$choice" in
		n|N)
			printf "\n\nPlease install OpenVPN manually\n"
			colour red "[-] Exiting" 2
			fin
			;;
		*)
			if  ! dpkg-query -W -f='${Status}' apt &>/dev/null; then
				colour red "[-] System doesn't use apt -- please install OpenVPN manually" 1
				colour red "[-] Exiting" 2
				fin
			else
				apt update &>/dev/null && apt install openvpn -y &>/dev/null & pid=$!
				colour process "[+] Installing OpenVPN..."
				while :; do
        			running=$(ps aux | grep $pid | wc -l)
        			if [ $running -eq 1 ]; then
                		break
        			fi
				done
				if dpkg-query -W -f='${Status}' openvpn &>/dev/null; then
					colour green "[+] Installation Process Completed" 1
				else
					colour red "[-] Installation failed. Please try installing OpenVPN manually -- otherwise ask for further assistance in the TryHackMe Discord server, subreddit or forum" 1
					colour red "[-] Exiting" 2
					fin
				fi
			fi
			;;
	esac
else
	colour green "[+] OpenVPN is installed" 1	
fi


#Find the VPN Config
ovpn=$(find . -maxdepth 1 -name "*.ovpn" -print -quit)
if [ ${#ovpn} -eq 0 ]; then
	colour red "[-] Config not found in current directory" 1
	read -ep "Please enter the path to your config: " ovpn
	ovpn=${ovpn/\~/$HOME}
	if [ ${#ovpn} -lt 5 ]; then
		colour red "[-] Invalid File -- Config should be <your-username>.ovpn" 1
		colour red "[-] Exiting" 2
		fin
	elif [ -f $ovpn ] && [ ${ovpn: -5} ==  ".ovpn" ]; then
		colour green "[+] Config Located successfully" 1
	else
		colour red "[-] Config not located" 1
		colour red "[-] Exiting" 2
		fin
	fi
fi


#Check that a tun0 exists
if ! ip a | grep -q tun0; then
	colour red "[-] tun0 interface does not exist" 1
	printf "Would you like the script to attempt a connection automatically (Y/n)? "
	read -p "" choice
	case "$choice" in
		n|N)
			printf "\n\nPlease connect to the vpn using the following command:\n"
			colour code "sudo openvpn $ovpn"
			printf "\n"
			colour red "[-] Exiting" 2
			fin
			;;
		*)
			if connect; then
				exit 0
			fi
			;;
	esac
else
	colour green "[+] tun0 exists" 1
fi	


#Check that the tun0 IP is in the right range
if ! ip a show tun0 | grep -qoE "10\.(2|4|6|8|9|11|13|14|17|50)\.[0-9]{1,3}\.[0-9]{1,3}" | head -1; then
	colour red "[-] tun0 ip is in the wrong range: $(ip addr show tun0 | grep "inet " | awk '{print $2}')" 1
	read -p "Would you like the script to attempt to fix this (Y/n)? " choice
	case "$choice" in
		n|N)
			printf "\n\nIf you're using another VPN, please check that it isn't operating on tun0\nOtherwise please regenerate your TryHackMe VPN config pack, or try another server.\n"
			colour red "[-] Exiting" 2
			fin
			;;
		*)
			colour green "[+] Resetting tun0 interface" 1
			ip link delete tun0
			if connect; then
				exit 0
			elif ! ip a | grep -qoE "10\.(2|4|6|8|9|11|13|14|17|50)\.[0-9]{1,3}\.[0-9]{1,3}" | head -1; then
				colour red "[-] Fatal Error: tun0 IP still in the wrong range: $(ip addr show tun0 | grep "inet " | awk '{print $2}')" 1
				printf "Please try switching servers and/or regenerating your VPN config\n"
				colour red "[-] Exiting" 2
				fin
			fi
			;;
	esac
else
	colour green "[+] tun0 IP is in the correct range" 1
fi


#Check for multivpn
connections=$(ps aux | grep -v "sudo\|grep" | grep -Eo "openvpn .*\.ovpn" | wc -l)
if [ $connections -gt 1 ]; then
	colour red "[-] More than one connection running" 1
	read -p "Would you like the script to attempt to fix this (Y/n)? " choice
	case $choice in
		n|N)
			printf "\n\nPlease run the following command, then reconnect manually:\n"
			colour code "sudo killall -9 openvpn"
			fin
			;;
		*)
			killall -9 openvpn
			colour green "[+] Killed duplicate processes"
			if connect; then
				exit 0
			fi
	esac
else
	colour green "[+] Only one instance of OpenVPN is running" 1
fi


#Final Check
colour process "[+] Confirming connectivity" 1
if [ $(ping -c 1 -q 10\.10\.10\.10 >&/dev/null; echo $?) -eq 0 ];then
	colour green "[+] Connectivity checks completed!" 2
	colour green "[+] You are connected to the TryHackMe Network" 2
	printf "Your TryHackMe IP address is: $(curl -s http://10.10.10.10/whoami)\n\n"
	colour green "Happy Hacking!" 3
else
	colour red "[-] Something went wrong -- please ask for further assistance in the TryHackMe Discord server, subreddit, or forum" 3
fi

printf "\n"
