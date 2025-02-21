#!/bin/bash

## Force braces
# shellcheck enable=require-variable-braces

## DO NOT REMOVE THESE!
## This is to prevent shellcheck from complaining about false positive issues like unused variables.
# shellcheck disable=SC2034,2002,2004,2010,2154,2064,2164

## File/Field Seperator Reference
OldIFS=${IFS}

## Define 4-bit Color Table
Tpurple="\e[35;40m"
TBpurple="\e[95;40m"
Tgreen="\e[32;40m"
TBgreen="\e[92;40m"
White="\e[0;40m"
TBred="\e[91;40m"
Tred="\e[31;40m"
TByellow="\e[93;40m"
Tyellow="\e[33;40m"
Tcyan="\e[36;40m"
TBcyan="\e[96;40m"

## Define 8-bit (256_color) Table
blue="\e[38;5;20m"
Bblue="\e[38;5;21m"
Red="\e[38;5;160m"
Bred="\e[38;5;196m"
Purple="\e[38;5;91m"
Bpurple="\e[38;5;129m"
Magenta="\e[38;5;165m"
Bmagenta="\e[38;5;177m"
Pink="\e[38;5;201m"
Bpink="\e[38;5;213m"
Yellow="\e[38;5;226m"
Byellow="\e[38;5;228m"
Orange="\e[38;5;215m"
Borange="\e[38;5;220m"
Green="\e[38;5;40m"
Bgreen="\e[38;5;47m"
Teal="\e[38;5;43m"
Bteal="\e[38;5;122m"
Cyan="\e[38;5;51m"
Bcyan="\e[38;5;123m"
Grey="\e[38;5;248m"


## Variant of gofast - intel (old)
#!/bin/bash\nsudo cpupower set --perf-bias 0\nfor ((i = 0 ; i < \"${clientThreadCount}\" ; i++)); do\nsudo cpufreq-set --cpu \"${i}\" --governor performance\ndone\nsudo tuned --daemon -p latency-performance -l"

## Force root to run
if [[ $EUID -ne 0 ]]; then
    printf %b "${White}[${Bred}ERROR${White}] This script requires running as root."
    exit 1
fi


## Distro
clientDistro="$(lsb_release -i | cut -f 2)"
## Linux Version (regex Filter)
clientLinuxVersion="$(uname -r | grep -Eo '^([0-9.]{4,})')"
## Client CPU info
clientCPUMake="$(lscpu | grep "Model name" | grep -Eo "[aAmMdD]{3}|[iInNtTeElL]{5}")"
clientCoreCount="$(($(grep -c ^processor /proc/cpuinfo)/2 ))" ## Divide total in half, proc reports threads not cores
clientThreadCount="$(grep -c ^processor /proc/cpuinfo)"
## Client Memory Capacity | Hacky oneliner - formats /proc/meminfo into GB and filters via grep to GB numeric value
clientMemoryCapacity="$(awk '$3=="kB"{$2=$2/1024**2;$3="GB";} 1' /proc/meminfo | column -t | grep "MemTotal" | grep -Eo "[0-9.]{3,}")"
clientInstalledPackages=("$(pacman -Qqe)")
## Service Files
GoFastScriptFile="#!/bin/bash\nsudo tuned --daemon -p latency-performance -l"
GoFastServiceFile="[Unit]\nDescription='Go Fast Service'\nAfter=tuned.service\n\n[Service]\nUser=root\nType=oneshot\nExecStart=${HOME}/gofast.sh\n[Install]\nWantedBy=multi-user.target"

## Raw Service File For Reference
#-----------------------------------#
#[Unit]
#Description="Go Fast Service"
#After=tuned.service
#
#[Service]
#User=root
#Type=oneshot
#ExecStart=$HOME/gofast.sh
#
#[Install]
#WantedBy=multi-user.target
#-----------------------------------#

## Fugly way of isolating user home directory for working with absolute path (root obscures $HOME val)
UserHomeDir="$(ls /home | grep -E '([a-zA-Z0-9]){4,}' | head -n 1)"
HomeDirReal="/home/${UserHomeDir}"


## Janky Yay installer
InstallYay(){ 
    HomeDir=${PWD}
    sudo pacman -S --needed base-devel git
    mkdir /usr/bin/share/yay-cache
    cd /usr/bin/share/yay-cache && git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si
    # Cleanup
    cd "${HomeDir}" && sudo rm -fr /usr/bin/share/yay-cache
}

## AUR Package Helper Logic
AURHelperIdentify() {
    #Find installed AUR helper (CachyOS and normal Arch so far)
    
    case "${YayStatus:-NULL}" in 
        "yay"|"YAY"|"Yay")
            PackageHelper="yay"
        ;;
    esac

    case "${ParuStatus:-NULL}" in 
        "paru"|"PARU"|"Paru")
            PackageHelper="paru"
        ;;
    esac

    ## Failsafe logic if no helper installed
    case "${PackageHelper:-NULL}" in 
        ""|"NULL"|"null")
            printf %b "${White}[${Byellow}WARN${White}] No AUR package helper detected, installing Yay."
            InstallYay && PackageHelper="yay"
        ;;
    esac
}

## Janky Package Manager Interface
InstallPackage(){
	[[ -z "${1}" ]] && echo -e "[${Bred}ERROR${White}] Package Manager Required" && return
	[[ -z "${2}" ]] && echo -e "[${Bred}ERROR${White}] Operation Required" && return 1
	eval "${1} ${2}"
}

DependencyCheck(){
	## Segregate make check for intel pstate controller
	## Note figure out array passthrough for proper string splits (currently globs and doesn't delimit with space)
	case "${clientCPUMake}" in 
		amd)
			TunedStatus="$(grep -Eo '(tuned)' <<< "${clientInstalledPackages[@]}")"
			case "${TunedStatus:-NULL}" in
				""|"NULL"|"null")
    				MissingPackages+="tuned-git "
    			;;
			esac
			CpuPowerStatus="$(grep -Eo '(cpupower)' <<< "${clientInstalledPackages[@]}")"
			case "${CpuPowerStatus:-NULL}" in
				""|"NULL"|"null")
    				MissingPackages="cpupower "
    			;;
			esac
		;;
		intel)
			TunedStatus="$(grep -Eo '(tuned)' <<< "${clientInstalledPackages[@]}")"
			case "${TunedStatus:-NULL}" in
				""|"NULL"|"null")
    				MissingPackages+="tuned-git "
    			;;
			esac
			CpuPowerStatus="$(grep -Eo '(cpupower)' <<< "${clientInstalledPackages[@]}")"
			case "${CpuPowerStatus:-NULL}" in
				""|"NULL"|"null")
    				MissingPackages="cpupower "
    			;;
			esac
			CpuFreqStatus="$(grep -Eo '(cpufreqctl)' <<< "${clientInstalledPackages[@]}")"
			case "${CpuFreqStatus:-NULL}" in
				""|"NULL"|"null")
    				MissingPackages+="cpufreqctl "
    			;;
			esac
    	;;
    esac
    AURHelperIdentify
    case "${PackageHelper:-NULL}" in 
        ""|"NULL"|"null")
            printf %b "${White}[${Bred}ERROR${White}] No AUR package helper detected when there should be. Please try installing one and re-running this tool"
            exit 1
        ;;
        "yay")
			[[ ${#MissingPackages[@]} -gt 0 ]] && InstallPackage "${PackageHelper} -S" "${MissingPackages[@]}"
        ;;
        "paru")
            [[ ${#MissingPackages[@]} -gt 0 ]] && InstallPackage "${PackageHelper}" "${MissingPackages[@]}"
        ;;
    esac

}


IntelPerfSetup(){
	case "$(ls /usr/lib/systemd/system | grep -o ondemand.service)$?" in
		0)
			sudo systemctl stop ondemand
		;;
	esac
	## Set Govenor for older intel chips and some AMD
    [[ ! -f "/etc/init.d/cpufrequtils" ]] && sudo sed -i 's/^GOVERNOR=.*/GOVERNOR=\"performance\"/' /etc/init.d/cpufrequtils
	## Setting CPU power management to performance bias
	sudo cpupower set --perf-bias 0
	## Set CPU active governor, have to do it for all threads, not cores
	for ((i = 0 ; i < "${clientThreadCount}" ; i++)); do
		sudo cpufreq-set --cpu "${i}" --governor performance
	done
	## Enable Intel CPU Turbo
	case "$(cat "/sys/devices/system/cpu/intel_pstate/no_turbo")" in
		1)
			sudo bash -c "echo \"0\" > /sys/devices/system/cpu/intel_pstate/no_turbo"
			#echo "0" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo <-- No Worky
		;;
	esac
}

AMDPerfSetup(){
	## Check if Ondemand.service is enabled
	case "$(ls /usr/lib/systemd/system | grep -o ondemand.service)$?" in
		0)
			sudo systemctl stop ondemand
		;;
	esac
    ## Set Govenor for older intel chips and some AMD
    [[ ! -f "/etc/init.d/cpufrequtils" ]] && sudo sed -i 's/^GOVERNOR=.*/GOVERNOR=\"performance\"/' /etc/init.d/cpufrequtils
	## Setting CPU power management to performance bias
	sudo cpupower set --perf-bias 0
}

PerfSetup(){
	DependencyCheck
	case "${clientCPUMake}" in 
		amd)
			AMDPerfSetup
		;;
		intel)
            IntelPerfSetup
        ;;
    esac
	case "$(ls /usr/lib/systemd/system | grep -o tuned.service)$?" in
		0)
			sudo tuned --daemon -p latency-performance -l
		;;
		1)
			sudo systemctl enable --now tuned
			sudo tuned --daemon -p latency-performance -l
		;;
	esac
	case "$(ls "${HomeDirReal}" | grep -o gofast.sh)$?" in
		1)
			echo -e "${GoFastScriptFile}" > "${HomeDirReal}"/gofast.sh
			chmod +x "${HomeDirReal}"/gofast.sh
		;;
	esac
	case "$(ls /usr/lib/systemd/system/ | grep -o gofast.service)$?" in
		1)
			## For some reason directly iterating to the service file is a nono
			## Using this fugly ass workaround for now
			echo -e "${GoFastServiceFile}" > "${HomeDirReal}"/temp
			sudo cp "${HomeDirReal}/temp"  /usr/lib/systemd/system/gofast.service
			rm "${HomeDirReal}"/temp
			sudo systemctl daemon-reload && sudo systemctl enable --now gofast.service
		;;
	esac	
}

PerfSetup