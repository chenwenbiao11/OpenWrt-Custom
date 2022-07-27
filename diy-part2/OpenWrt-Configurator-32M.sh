#!/bin/bash
#
# Copyright (c) 2022-now 1-1-2 <https://github.com/1-1-2>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# File name: OpenWrt-Configurator-32M.sh
# Description: OpenWrt .config maker script (for addon&paks) for 32MB(256Mb) flash device
#

cat << EOF
=======OpenWrt-Configurator-32M.sh=======
    functions loaded:
        1. add_packages, modification
        2. config_func
        3. config_basic
        4. config_clean
        5. config_test
=========================================
EOF

modification() {
    # 一些可能必要的修改
    echo '[MOD]更换 luci-app-clash 的依赖 openssl 为 wolfssl'
    find -type f -path '*/luci-app-clash/Makefile' -print -exec sed -i 's/openssl/wolfssl/w /dev/stdout' {} \;

    echo '[MOD]更换 luci-app-easymesh 的依赖 openssl 为 wolfssl'
    find -type f -path '*/luci-app-easymesh/Makefile' -print -exec sed -i 's/openssl/wolfssl/w /dev/stdout' {} \;

    echo '[MOD]除去 luci-app-dockerman 的架构限制'
    find -type f -path '*/luci-app-dockerman/Makefile' -print -exec sed -i 's#@(aarch64||arm||x86_64)##w /dev/stdout' {} \;
    find -type f -path '*/luci-lib-docker/Makefile' -print -exec sed -i 's#@(aarch64||arm||x86_64)##w /dev/stdout' {} \;

    echo '[MOD]使能 SOFT_FLOAT 环境下的 node'
    [ -e feeds/packages/lang/node/Makefile ] && sed -i 's/HAS_FPU/(HAS_FPU||SOFT_FLOAT)/w /dev/stdout' feeds/packages/lang/node/Makefile
}

add_packages(){
    #=========================================
    # 两种方式（没有本质上的区别）：
    # M1. 从别的(类)OpenWrt源码仓库部分借用，放到feeds文件夹(通常为feeds/luci)
    # M2. 拉取专门的luci包到package文件夹（注意 /package 与 /feeds/packages 的区别）
    # M3. 修正语言名（zh-cn -> zh_Hans），更新feeds索引，安装feeds
    #=========================================
    [ -e is_add_packages ] && echo Add packages is done already. && return 0
    
    # M1
    echo '从 lean 那里借个 luci-app-vsftpd'
    svn co https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-vsftpd feeds/luci/applications/luci-app-vsftpd
    echo '还有依赖 vsftpd-alt'
    svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/vsftpd-alt package/lean/vsftpd-alt
    echo '从 lean 那里借个 luci-app-unblockmusic'
    svn co https://github.com/coolsnowwolf/luci/trunk/applications/luci-app-unblockmusic feeds/luci/applications/luci-app-unblockmusic
    echo '还有依赖 UnblockNeteaseMusic 和 UnblockNeteaseMusic-Go'
    svn co https://github.com/coolsnowwolf/packages/trunk/multimedia/UnblockNeteaseMusic feeds/packages/multimedia/UnblockNeteaseMusic
    svn co https://github.com/coolsnowwolf/packages/trunk/multimedia/UnblockNeteaseMusic-Go feeds/packages/multimedia/UnblockNeteaseMusic-Go

    echo '从天灵那里借个 luci-app-nps'
    svn co https://github.com/immortalwrt/luci/trunk/applications/luci-app-nps feeds/luci/applications/luci-app-nps
    echo '还有依赖 nps'
    svn co https://github.com/immortalwrt/packages/trunk/net/nps feeds/packages/net/nps

    exist_sed(){
        if [ -f "$1" ]; then
            cp -f "$1" tmp/exist_sed.before
            sed -i 's/services/nas/' "$1"
            echo "将 $(basename "$1" | cut -d. -f1) 从 services 移动到 nas" [$1]
            diff tmp/exist_sed.before "$1"
            echo "=====================EOF======================="
        else
            echo 没找到$1
        fi
    }
    echo 'luci-app-vsftpd 定义了一级菜单 <nas>，顺便修改一些菜单入口到该菜单'
    exist_sed feeds/luci/applications/luci-app-ksmbd/root/usr/share/luci/menu.d/luci-app-ksmbd.json
    exist_sed feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/luci-app-hd-idle.json
    exist_sed feeds/luci/applications/luci-app-aria2/root/usr/share/luci/menu.d/luci-app-aria2.json
    exist_sed feeds/luci/applications/luci-app-transmission/root/usr/share/luci/menu.d/luci-app-transmission.json

    # M2
    cd package

    # echo '从 Hyy2001X 那里借一个改好的 luci-app-npc'
    # svn co https://github.com/Hyy2001X/AutoBuild-Packages/trunk/luci-app-npc

    echo '从 lean 那里借一个自动外存挂载 automount'
    svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/automount lean/automount
    sed -i 's/ +ntfs3-mount//w /dev/stdout' lean/automount/Makefile      # 去掉不存在的包

    cd ..

    # 解决无法正确识别出简体中文语言包的问题
    # ref: https://github.com/ysc3839/luci-proto-minieap/pull/2
    find -type d -path '*/po/zh-cn' | xargs dirname | xargs -I'{}' ln -srvn {}/zh-cn {}/zh_Hans

    # 修改一些依赖
    modification
    # 最后[强制]更新一下索引和安装一下包
    ./scripts/feeds update -ifa
    ./scripts/feeds install -a

    # 已修改标志（其实也就DEBUG的时候有用）
    touch is_add_packages
}

config_clean() {
    #=========================================
    # Stripping options
    #=========================================
    cat >> .config << EOF
CONFIG_STRIP_KERNEL_EXPORTS=y
# CONFIG_USE_MKLIBS is not set
EOF
    #=========================================
    # Luci
    #=========================================
    cat >> .config << EOF
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF
    #=========================================
    # unset some default to avoid duplication
    #=========================================
    cat >> .config << EOF
# CONFIG_PACKAGE_luci-app-passwall_Transparent_Proxy is not set
# CONFIG_PACKAGE_luci-app-passwall2_Transparent_Proxy is not set
EOF
    #=========================================
    # use dnsmasq-full as default instead of
    # dnsmasq to avoid potential conflicts
    #=========================================
    cat >> .config << EOF
# CONFIG_PACKAGE_dnsmasq is not set
CONFIG_PACKAGE_dnsmasq-full=y
EOF
}

config_basic() {
    config_clean
    #=========================================
    # 基础包和应用
    #=========================================
    cat >> .config << EOF
# ----------select for openwrt
CONFIG_PACKAGE_luci-app-acl=y
CONFIG_PACKAGE_luci-app-advanced=y
CONFIG_PACKAGE_luci-app-ddns=y
CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_luci-app-store=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wol=y
# ----------automount from lean
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_kmod-fs-ntfs=y
# ----------Utilities-usbutils
CONFIG_PACKAGE_usbutils=y
# ----------Kernel modules-USB Support-kmod-usb3
CONFIG_DEFAULT_kmod-usb3=y
# ----------Utilities-Disc-cfdisk&fdisk
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_fdisk=y
# ----------Utilities-Filesystem-e2fsprogs
CONFIG_PACKAGE_e2fsprogs=y
# ----------luci-app-hd-idle
CONFIG_PACKAGE_luci-app-hd-idle=y
# ----------Utilities-jq
CONFIG_PACKAGE_jq=y
# ----------Utilities-coreutils-base64
CONFIG_PACKAGE_coreutils-base64=y
# ----------luci-app-ksmbd
CONFIG_PACKAGE_luci-app-ksmbd=y
# ----------luci-app-commands
CONFIG_PACKAGE_luci-app-commands=y
# ----------luci-app-qos
CONFIG_PACKAGE_luci-app-qos=y
# ----------luci-app-nft-qos
CONFIG_PACKAGE_luci-app-nft-qos=y
# ----------luci-app-eqos
CONFIG_PACKAGE_luci-app-eqos=y
# ----------luci-app-sqm
CONFIG_PACKAGE_luci-app-sqm=y
# ----------luci-app-ttyd
CONFIG_PACKAGE_luci-app-ttyd=y
# ----------luci-theme-argon
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
EOF
}

config_func() {
    config_basic
    #=========================================
    # 功能包
    #=========================================
    cat >> .config << EOF
# ----------luci-app-vsftpd
CONFIG_PACKAGE_luci-app-vsftpd=y
# ----------luci-app-aria2
CONFIG_PACKAGE_luci-app-aria2=y
# ----------luci-app-VPNs
CONFIG_PACKAGE_luci-app-nps=y
CONFIG_PACKAGE_luci-app-frpc=y
# ----------luci-app-openclash
CONFIG_PACKAGE_luci-app-openclash=y
# ----------network-firewall-ip6tables-ip6tables-mod-nat
# CONFIG_PACKAGE_ip6tables-mod-nat=y
# ----------luci-app-transmission
CONFIG_PACKAGE_luci-app-transmission=y
# ----------luci-app-watchcat
CONFIG_PACKAGE_luci-app-watchcat=y
#
# Automatically generated file; DO NOT EDIT.
# OpenWrt Configuration
#
CONFIG_MODULES=y
CONFIG_HAVE_DOT_CONFIG=y
CONFIG_HOST_OS_LINUX=y
# CONFIG_HOST_OS_MACOS is not set
# CONFIG_TARGET_sunxi is not set
# CONFIG_TARGET_apm821xx is not set
# CONFIG_TARGET_ath25 is not set
# CONFIG_TARGET_ath79 is not set
# CONFIG_TARGET_bcm27xx is not set
# CONFIG_TARGET_bcm53xx is not set
# CONFIG_TARGET_bcm47xx is not set
# CONFIG_TARGET_bcm4908 is not set
# CONFIG_TARGET_bcm63xx is not set
# CONFIG_TARGET_bmips is not set
# CONFIG_TARGET_octeon is not set
# CONFIG_TARGET_gemini is not set
# CONFIG_TARGET_mpc85xx is not set
# CONFIG_TARGET_mxs is not set
# CONFIG_TARGET_lantiq is not set
# CONFIG_TARGET_malta is not set
# CONFIG_TARGET_pistachio is not set
# CONFIG_TARGET_mvebu is not set
# CONFIG_TARGET_kirkwood is not set
# CONFIG_TARGET_mediatek is not set
CONFIG_TARGET_ramips=y
# CONFIG_TARGET_at91 is not set
# CONFIG_TARGET_tegra is not set
# CONFIG_TARGET_layerscape is not set
# CONFIG_TARGET_qoriq is not set
# CONFIG_TARGET_imx is not set
# CONFIG_TARGET_octeontx is not set
# CONFIG_TARGET_oxnas is not set
# CONFIG_TARGET_armvirt is not set
# CONFIG_TARGET_ipq40xx is not set
# CONFIG_TARGET_ipq806x is not set
# CONFIG_TARGET_realtek is not set
# CONFIG_TARGET_rockchip is not set
# CONFIG_TARGET_archs38 is not set
# CONFIG_TARGET_omap is not set
# CONFIG_TARGET_uml is not set
# CONFIG_TARGET_zynq is not set
# CONFIG_TARGET_x86 is not set
# CONFIG_TARGET_ramips_mt7620 is not set
CONFIG_TARGET_ramips_mt7621=y
# CONFIG_TARGET_ramips_mt76x8 is not set
# CONFIG_TARGET_ramips_rt288x is not set
# CONFIG_TARGET_ramips_rt305x is not set
# CONFIG_TARGET_ramips_rt3883 is not set
# CONFIG_TARGET_MULTI_PROFILE is not set
CONFIG_TARGET_ramips_mt7621_DEVICE_jdcloud_re-sp-01b=y
# CONFIG_TARGET_ramips_mt7621_DEVICE_adslr_g7 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_afoundry_ew1200 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_alfa-network_quad-e4g is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ampedwireless_ally-r1900k is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ampedwireless_ally-00x19k is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asiarf_ap7621-001 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asiarf_ap7621-nv1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asus_rp-ac87 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asus_rt-ac57u is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asus_rt-ac65p is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asus_rt-ac85p is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asus_rt-n56u-b1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_asus_rt-ax53u is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_beeline_smartbox-flash is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_beeline_smartbox-giga is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_buffalo_wsr-1166dhp is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_buffalo_wsr-2533dhpl is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_buffalo_wsr-600dhp is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_bolt_arion is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_cudy_wr1300 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_cudy_wr2100 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_cudy_x6 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-1960-a1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-2640-a1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-2660-a1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-853-a3 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-853-r1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-860l-b1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-867-a1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-878-a1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-878-r1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-882-a1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dlink_dir-882-r1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_dual-q_h721 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_d-team_newifi-d2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_d-team_pbr-m1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_edimax_ra21s is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_edimax_re23s is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_edimax_rg21s is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1167ghbk2-s is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1167gs2-b is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1167gst2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1750gs is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1750gst2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1750gsv is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-1900gst is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-2533ghbk-i is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-2533gs2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-2533gst is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_elecom_wrc-2533gst2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_firefly_firewrt is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_gehua_ghl-r-001 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_glinet_gl-mt1300 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_gnubee_gb-pc1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_gnubee_gb-pc2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_hilink_hlk-7621a-evb is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_hiwifi_hc5962 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_humax_e10 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-ax1167gr is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-ax1167gr2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-ax2033gr is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-dx1167r is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-dx1200gr is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-dx2033gr is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wn-gx300gr is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iodata_wnpr2600g is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_a3002mesh is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_a3004ns-dual is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_a3004t is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_a6004ns-m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_a6ns-m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_a8004t is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_ax2004m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_iptime_t5004 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_jcg_jhr-ac876m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_jcg_q20 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_jcg_y2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_lenovo_newifi-d1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_e5600 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_ea6350-v4 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_ea7300-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_ea7300-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_ea7500-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_ea8100-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_ea8100-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_linksys_re6500 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mediatek_ap-mt7621a-v60 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mediatek_mt7621-eval-board is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mikrotik_routerboard-750gr3 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mikrotik_routerboard-760igs is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mikrotik_routerboard-m11g is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mikrotik_routerboard-m33g is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mqmaker_witi is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mtc_wr1201 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_mts_wg430223 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_ex6150 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6220 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6260 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6350 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6700-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6800 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6850 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r6900-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r7200 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_r7450 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_wac104 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_wac124 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_wax202 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netgear_wndr3700-v5 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_netis_wf2881 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_oraybox_x3a is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_phicomm_k2p is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_planex_vr500 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_raisecom_msg1500-x-00 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_renkforce_ws-wn530hp3-a is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_samknows_whitebox-v8 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_sercomm_na502 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_sercomm_na502s is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_storylink_sap-g3200u3 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_telco-electronics_x1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tenbay_t-mb5eu-v01 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_thunder_timecloud is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_totolink_a7000r is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_totolink_x5000r is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_archer-a6-v3 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_archer-c6-v3 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_archer-c6u-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_eap235-wall-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_eap615-wall-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_re350-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_re500-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_re650-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_re650-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_tplink_tl-wpa8631p-v3 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ubnt_edgerouter-x is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ubnt_edgerouter-x-sfp is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ubnt_unifi-6-lite is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ubnt_unifi-nanohd is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_ubnt_usw-flex is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_unielec_u7621-01-16m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_unielec_u7621-06-16m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_unielec_u7621-06-64m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_wavlink_wl-wn531a6 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_wavlink_wl-wn533a8 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_wevo_11acnas is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_wevo_w2914ns-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_winstars_ws-wn583a6 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-3g is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-3g-v2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-3-pro is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-4 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-4a-gigabit is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-ac2100 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-cr6606 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-cr6608 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mi-router-cr6609 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_redmi-router-ac2100 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xiaoyu_xy-c5 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_xzwifi_creativebox-v1 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_youhua_wr1200js is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_youku_yk-l2 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_yuncore_ax820 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-we1326 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-we3526 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-wg1602-16m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-wg1608-16m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-wg2626 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-wg3526-16m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zbtlink_zbt-wg3526-32m is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zio_freezio is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zyxel_nr7101 is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zyxel_nwa50ax is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zyxel_nwa55axe is not set
# CONFIG_TARGET_ramips_mt7621_DEVICE_zyxel_wap6805 is not set
CONFIG_HAS_SUBTARGETS=y
CONFIG_HAS_DEVICES=y
CONFIG_TARGET_BOARD="ramips"
CONFIG_TARGET_SUBTARGET="mt7621"
CONFIG_TARGET_PROFILE="DEVICE_jdcloud_re-sp-01b"
CONFIG_TARGET_ARCH_PACKAGES="mipsel_24kc"
CONFIG_DEFAULT_TARGET_OPTIMIZATION="-Os -pipe -mno-branch-likely -mips32r2 -mtune=24kc"
CONFIG_CPU_TYPE="24kc"
CONFIG_LINUX_5_10=y
CONFIG_DEFAULT_base-files=y
CONFIG_DEFAULT_busybox=y
CONFIG_DEFAULT_ca-bundle=y
# CONFIG_DEFAULT_dnsmasq is not set
CONFIG_DEFAULT_dropbear=y
CONFIG_DEFAULT_firewall4=y
CONFIG_DEFAULT_fstools=y
CONFIG_DEFAULT_iwinfo=y
CONFIG_DEFAULT_kmod-fs-ext4=y
CONFIG_DEFAULT_kmod-gpio-button-hotplug=y
CONFIG_DEFAULT_kmod-leds-gpio=y
CONFIG_DEFAULT_kmod-mt7603=y
CONFIG_DEFAULT_kmod-mt7615-firmware=y
CONFIG_DEFAULT_kmod-mt7615e=y
CONFIG_DEFAULT_kmod-nft-offload=y
CONFIG_DEFAULT_kmod-sdhci-mt7620=y
CONFIG_DEFAULT_kmod-usb3=y
CONFIG_DEFAULT_libc=y
CONFIG_DEFAULT_libgcc=y
CONFIG_DEFAULT_libustream-wolfssl=y
CONFIG_DEFAULT_logd=y
CONFIG_DEFAULT_mtd=y
CONFIG_DEFAULT_netifd=y
CONFIG_DEFAULT_nftables=y
CONFIG_DEFAULT_odhcp6c=y
CONFIG_DEFAULT_odhcpd-ipv6only=y
CONFIG_DEFAULT_opkg=y
CONFIG_DEFAULT_ppp=y
CONFIG_DEFAULT_ppp-mod-pppoe=y
CONFIG_DEFAULT_procd=y
CONFIG_DEFAULT_procd-ujail=y
CONFIG_DEFAULT_uci=y
CONFIG_DEFAULT_uclient-fetch=y
CONFIG_DEFAULT_urandom-seed=y
CONFIG_DEFAULT_urngd=y
CONFIG_DEFAULT_wpad-basic-wolfssl=y
CONFIG_DEFAULT_wpad-openssl=y
CONFIG_HAS_TESTING_KERNEL=y
CONFIG_AUDIO_SUPPORT=y
CONFIG_GPIO_SUPPORT=y
CONFIG_PCI_SUPPORT=y
CONFIG_USB_SUPPORT=y
CONFIG_RTC_SUPPORT=y
CONFIG_USES_DEVICETREE=y
CONFIG_USES_INITRAMFS=y
CONFIG_USES_SQUASHFS=y
CONFIG_USES_MINOR=y
CONFIG_HAS_MIPS16=y
CONFIG_NAND_SUPPORT=y
CONFIG_mipsel=y
CONFIG_ARCH="mipsel"

#
# Target Images
#
CONFIG_TARGET_ROOTFS_INITRAMFS=y
# CONFIG_TARGET_INITRAMFS_COMPRESSION_NONE is not set
# CONFIG_TARGET_INITRAMFS_COMPRESSION_GZIP is not set
# CONFIG_TARGET_INITRAMFS_COMPRESSION_BZIP2 is not set
CONFIG_TARGET_INITRAMFS_COMPRESSION_LZMA=y
# CONFIG_TARGET_INITRAMFS_COMPRESSION_LZO is not set
# CONFIG_TARGET_INITRAMFS_COMPRESSION_LZ4 is not set
# CONFIG_TARGET_INITRAMFS_COMPRESSION_XZ is not set
# CONFIG_TARGET_INITRAMFS_COMPRESSION_ZSTD is not set
CONFIG_EXTERNAL_CPIO=""
# CONFIG_TARGET_INITRAMFS_FORCE is not set

#
# Root filesystem archives
#
# CONFIG_TARGET_ROOTFS_CPIOGZ is not set
# CONFIG_TARGET_ROOTFS_TARGZ is not set

#
# Root filesystem images
#
# CONFIG_TARGET_ROOTFS_EXT4FS is not set
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=256
CONFIG_TARGET_UBIFS_FREE_SPACE_FIXUP=y
CONFIG_TARGET_UBIFS_JOURNAL_SIZE=""

#
# Image Options
#
# CONFIG_TARGET_ROOTFS_PERSIST_VAR is not set
# end of Target Images

# CONFIG_EXPERIMENTAL is not set

#
# Global build settings
#
CONFIG_JSON_OVERVIEW_IMAGE_INFO=y
# CONFIG_ALL_NONSHARED is not set
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL is not set
# CONFIG_BUILDBOT is not set
CONFIG_SIGNED_PACKAGES=y
CONFIG_SIGNATURE_CHECK=y

#
# General build options
#
# CONFIG_TESTING_KERNEL is not set
# CONFIG_DISPLAY_SUPPORT is not set
# CONFIG_BUILD_PATENTED is not set
# CONFIG_BUILD_NLS is not set
CONFIG_SHADOW_PASSWORDS=y
# CONFIG_CLEAN_IPKG is not set
# CONFIG_IPK_FILES_CHECKSUMS is not set
# CONFIG_INCLUDE_CONFIG is not set
# CONFIG_REPRODUCIBLE_DEBUG_INFO is not set
# CONFIG_COLLECT_KERNEL_DEBUG is not set

#
# Kernel build options
#
CONFIG_KERNEL_BUILD_USER=""
CONFIG_KERNEL_BUILD_DOMAIN=""
CONFIG_KERNEL_PRINTK=y
CONFIG_KERNEL_SWAP=y
# CONFIG_KERNEL_PROC_STRIPPED is not set
CONFIG_KERNEL_DEBUG_FS=y
# CONFIG_KERNEL_PERF_EVENTS is not set
# CONFIG_KERNEL_PROFILING is not set
# CONFIG_KERNEL_UBSAN is not set
# CONFIG_KERNEL_KCOV is not set
# CONFIG_KERNEL_TASKSTATS is not set
CONFIG_KERNEL_KALLSYMS=y
# CONFIG_KERNEL_FTRACE is not set
CONFIG_KERNEL_DEBUG_KERNEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=y
# CONFIG_KERNEL_DEBUG_VIRTUAL is not set
# CONFIG_KERNEL_DYNAMIC_DEBUG is not set
# CONFIG_KERNEL_KPROBES is not set
# CONFIG_KERNEL_BPF_EVENTS is not set
CONFIG_KERNEL_AIO=y
CONFIG_KERNEL_IO_URING=y
CONFIG_KERNEL_FHANDLE=y
CONFIG_KERNEL_FANOTIFY=y
# CONFIG_KERNEL_BLK_DEV_BSG is not set
# CONFIG_KERNEL_HUGETLB_PAGE is not set
CONFIG_KERNEL_MAGIC_SYSRQ=y
# CONFIG_KERNEL_DEBUG_PINCTRL is not set
# CONFIG_KERNEL_DEBUG_GPIO is not set
CONFIG_KERNEL_COREDUMP=y
CONFIG_KERNEL_ELF_CORE=y
# CONFIG_KERNEL_PROVE_LOCKING is not set
# CONFIG_KERNEL_SOFTLOCKUP_DETECTOR is not set
# CONFIG_KERNEL_DETECT_HUNG_TASK is not set
# CONFIG_KERNEL_WQ_WATCHDOG is not set
# CONFIG_KERNEL_DEBUG_ATOMIC_SLEEP is not set
# CONFIG_KERNEL_DEBUG_VM is not set
CONFIG_KERNEL_PRINTK_TIME=y
# CONFIG_KERNEL_SLABINFO is not set
# CONFIG_KERNEL_PROC_PAGE_MONITOR is not set
# CONFIG_KERNEL_KEXEC is not set
# CONFIG_USE_RFKILL is not set
# CONFIG_USE_SPARSE is not set
# CONFIG_KERNEL_DEVTMPFS is not set
CONFIG_KERNEL_KEYS=y
# CONFIG_KERNEL_PERSISTENT_KEYRINGS is not set
# CONFIG_KERNEL_KEYS_REQUEST_CACHE is not set
# CONFIG_KERNEL_BIG_KEYS is not set
CONFIG_KERNEL_CGROUPS=y
# CONFIG_KERNEL_CGROUP_DEBUG is not set
CONFIG_KERNEL_FREEZER=y
# CONFIG_KERNEL_CGROUP_FREEZER is not set
# CONFIG_KERNEL_CGROUP_DEVICE is not set
# CONFIG_KERNEL_CGROUP_HUGETLB is not set
CONFIG_KERNEL_CGROUP_PIDS=y
CONFIG_KERNEL_CGROUP_RDMA=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_CPUSETS=y
# CONFIG_KERNEL_PROC_PID_CPUSET is not set
CONFIG_KERNEL_CGROUP_CPUACCT=y
CONFIG_KERNEL_RESOURCE_COUNTERS=y
CONFIG_KERNEL_MM_OWNER=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_MEMCG_SWAP=y
# CONFIG_KERNEL_MEMCG_SWAP_ENABLED is not set
CONFIG_KERNEL_MEMCG_KMEM=y
# CONFIG_KERNEL_CGROUP_PERF is not set
CONFIG_KERNEL_CGROUP_SCHED=y
CONFIG_KERNEL_FAIR_GROUP_SCHED=y
CONFIG_KERNEL_CFS_BANDWIDTH=y
CONFIG_KERNEL_RT_GROUP_SCHED=y
CONFIG_KERNEL_BLK_CGROUP=y
# CONFIG_KERNEL_CFQ_GROUP_IOSCHED is not set
CONFIG_KERNEL_BLK_DEV_THROTTLING=y
# CONFIG_KERNEL_BLK_DEV_THROTTLING_LOW is not set
# CONFIG_KERNEL_DEBUG_BLK_CGROUP is not set
# CONFIG_KERNEL_NET_CLS_CGROUP is not set
# CONFIG_KERNEL_CGROUP_NET_CLASSID is not set
# CONFIG_KERNEL_CGROUP_NET_PRIO is not set
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_UTS_NS=y
CONFIG_KERNEL_IPC_NS=y
CONFIG_KERNEL_USER_NS=y
CONFIG_KERNEL_PID_NS=y
CONFIG_KERNEL_NET_NS=y
CONFIG_KERNEL_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_KERNEL_POSIX_MQUEUE=y
CONFIG_KERNEL_SECCOMP_FILTER=y
CONFIG_KERNEL_SECCOMP=y
CONFIG_KERNEL_IP_MROUTE=y
CONFIG_KERNEL_IP_MROUTE_MULTIPLE_TABLES=y
CONFIG_KERNEL_IP_PIMSM_V1=y
CONFIG_KERNEL_IP_PIMSM_V2=y
CONFIG_KERNEL_IPV6=y
CONFIG_KERNEL_IPV6_MULTIPLE_TABLES=y
CONFIG_KERNEL_IPV6_SUBTREES=y
CONFIG_KERNEL_IPV6_MROUTE=y
CONFIG_KERNEL_IPV6_MROUTE_MULTIPLE_TABLES=y
CONFIG_KERNEL_IPV6_PIMSM_V2=y
CONFIG_KERNEL_IPV6_SEG6_LWTUNNEL=y
# CONFIG_KERNEL_LWTUNNEL_BPF is not set
# CONFIG_KERNEL_NET_L3_MASTER_DEV is not set
# CONFIG_KERNEL_IP_PNP is not set

#
# Filesystem ACL and attr support options
#
# CONFIG_USE_FS_ACL_ATTR is not set
# CONFIG_KERNEL_FS_POSIX_ACL is not set
# CONFIG_KERNEL_BTRFS_FS_POSIX_ACL is not set
# CONFIG_KERNEL_EXT4_FS_POSIX_ACL is not set
# CONFIG_KERNEL_F2FS_FS_POSIX_ACL is not set
# CONFIG_KERNEL_JFFS2_FS_POSIX_ACL is not set
# CONFIG_KERNEL_TMPFS_POSIX_ACL is not set
# CONFIG_KERNEL_CIFS_ACL is not set
# CONFIG_KERNEL_HFS_FS_POSIX_ACL is not set
# CONFIG_KERNEL_HFSPLUS_FS_POSIX_ACL is not set
# CONFIG_KERNEL_NFS_ACL_SUPPORT is not set
# CONFIG_KERNEL_NFS_V3_ACL_SUPPORT is not set
# CONFIG_KERNEL_NFSD_V2_ACL_SUPPORT is not set
# CONFIG_KERNEL_NFSD_V3_ACL_SUPPORT is not set
# CONFIG_KERNEL_REISER_FS_POSIX_ACL is not set
# CONFIG_KERNEL_XFS_POSIX_ACL is not set
# CONFIG_KERNEL_JFS_POSIX_ACL is not set
# end of Filesystem ACL and attr support options

# CONFIG_KERNEL_DEVMEM is not set
# CONFIG_KERNEL_DEVKMEM is not set
CONFIG_KERNEL_SQUASHFS_FRAGMENT_CACHE_SIZE=3
# CONFIG_KERNEL_SQUASHFS_XATTR is not set
CONFIG_KERNEL_CC_OPTIMIZE_FOR_PERFORMANCE=y
# CONFIG_KERNEL_CC_OPTIMIZE_FOR_SIZE is not set
# CONFIG_KERNEL_AUDIT is not set
# CONFIG_KERNEL_SECURITY is not set
# CONFIG_KERNEL_SECURITY_NETWORK is not set
# CONFIG_KERNEL_SECURITY_SELINUX is not set
# CONFIG_KERNEL_EXT4_FS_SECURITY is not set
# CONFIG_KERNEL_F2FS_FS_SECURITY is not set
# CONFIG_KERNEL_UBIFS_FS_SECURITY is not set
# CONFIG_KERNEL_JFFS2_FS_SECURITY is not set
# end of Kernel build options

#
# Package build options
#
# CONFIG_DEBUG is not set
CONFIG_IPV6=y

#
# Stripping options
#
# CONFIG_NO_STRIP is not set
# CONFIG_USE_STRIP is not set
CONFIG_USE_SSTRIP=y
CONFIG_SSTRIP_ARGS="-z"
CONFIG_STRIP_KERNEL_EXPORTS=y
# CONFIG_USE_MKLIBS is not set

#
# Hardening build options
#
CONFIG_PKG_CHECK_FORMAT_SECURITY=y
# CONFIG_PKG_ASLR_PIE_NONE is not set
CONFIG_PKG_ASLR_PIE_REGULAR=y
# CONFIG_PKG_ASLR_PIE_ALL is not set
# CONFIG_PKG_CC_STACKPROTECTOR_NONE is not set
CONFIG_PKG_CC_STACKPROTECTOR_REGULAR=y
# CONFIG_PKG_CC_STACKPROTECTOR_STRONG is not set
# CONFIG_KERNEL_CC_STACKPROTECTOR_NONE is not set
CONFIG_KERNEL_CC_STACKPROTECTOR_REGULAR=y
# CONFIG_KERNEL_CC_STACKPROTECTOR_STRONG is not set
CONFIG_KERNEL_STACKPROTECTOR=y
# CONFIG_KERNEL_STACKPROTECTOR_STRONG is not set
# CONFIG_PKG_FORTIFY_SOURCE_NONE is not set
CONFIG_PKG_FORTIFY_SOURCE_1=y
# CONFIG_PKG_FORTIFY_SOURCE_2 is not set
# CONFIG_PKG_RELRO_NONE is not set
# CONFIG_PKG_RELRO_PARTIAL is not set
CONFIG_PKG_RELRO_FULL=y
# CONFIG_SELINUX is not set
CONFIG_SECCOMP=y
# end of Global build settings

# CONFIG_DEVEL is not set
# CONFIG_BROKEN is not set
CONFIG_BINARY_FOLDER=""
CONFIG_DOWNLOAD_FOLDER=""
CONFIG_LOCALMIRROR=""
CONFIG_AUTOREBUILD=y
# CONFIG_AUTOREMOVE is not set
CONFIG_BUILD_SUFFIX=""
CONFIG_TARGET_ROOTFS_DIR=""
# CONFIG_CCACHE is not set
CONFIG_CCACHE_DIR=""
CONFIG_KERNEL_CFLAGS=""
CONFIG_EXTERNAL_KERNEL_TREE=""
CONFIG_KERNEL_GIT_CLONE_URI=""
CONFIG_BUILD_LOG_DIR=""
CONFIG_EXTRA_OPTIMIZATION="-fno-caller-saves -fno-plt"
CONFIG_TARGET_OPTIMIZATION="-Os -pipe -mno-branch-likely -mips32r2 -mtune=24kc"
CONFIG_SOFT_FLOAT=y
CONFIG_USE_MIPS16=y
# CONFIG_EXTRA_TARGET_ARCH is not set
CONFIG_EXTRA_BINUTILS_CONFIG_OPTIONS=""
# CONFIG_DWARVES is not set
CONFIG_EXTRA_GCC_CONFIG_OPTIONS=""
# CONFIG_GCC_DEFAULT_PIE is not set
# CONFIG_GCC_DEFAULT_SSP is not set
# CONFIG_SJLJ_EXCEPTIONS is not set
# CONFIG_INSTALL_GFORTRAN is not set
CONFIG_MUSL_DISABLE_CRYPT_SIZE_HACK=y
CONFIG_GDB=y
# CONFIG_GDB_PYTHON is not set
# CONFIG_HAS_PREBUILT_LLVM_TOOLCHAIN is not set
CONFIG_USE_MUSL=y
CONFIG_SSP_SUPPORT=y
CONFIG_BINUTILS_VERSION_2_37=y
CONFIG_BINUTILS_VERSION="2.37"
CONFIG_GCC_VERSION="11.3.0"
CONFIG_LIBC="musl"
CONFIG_TARGET_SUFFIX="musl"
# CONFIG_IB is not set
# CONFIG_SDK is not set
# CONFIG_MAKE_TOOLCHAIN is not set
# CONFIG_IMAGEOPT is not set
# CONFIG_PREINITOPT is not set
CONFIG_TARGET_PREINIT_SUPPRESS_STDERR=y
# CONFIG_TARGET_PREINIT_DISABLE_FAILSAFE is not set
CONFIG_TARGET_PREINIT_TIMEOUT=2
# CONFIG_TARGET_PREINIT_SHOW_NETMSG is not set
# CONFIG_TARGET_PREINIT_SUPPRESS_FAILSAFE_NETMSG is not set
CONFIG_TARGET_PREINIT_IFNAME=""
CONFIG_TARGET_PREINIT_IP="192.168.1.1"
CONFIG_TARGET_PREINIT_NETMASK="255.255.255.0"
CONFIG_TARGET_PREINIT_BROADCAST="192.168.1.255"
# CONFIG_INITOPT is not set
CONFIG_TARGET_INIT_PATH="/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_TARGET_INIT_ENV=""
CONFIG_TARGET_INIT_CMD="/sbin/init"
CONFIG_TARGET_INIT_SUPPRESS_STDERR=y
# CONFIG_VERSIONOPT is not set
CONFIG_PER_FEED_REPO=y
CONFIG_FEED_packages=y
CONFIG_FEED_luci=y
CONFIG_FEED_routing=y
CONFIG_FEED_telephony=y
CONFIG_FEED_kenzo=y
CONFIG_FEED_small=y
CONFIG_FEED_mtk=y

#
# Base system
#
# CONFIG_PACKAGE_attendedsysupgrade-common is not set
# CONFIG_PACKAGE_auc is not set
CONFIG_PACKAGE_base-files=y
# CONFIG_PACKAGE_block-mount is not set
# CONFIG_PACKAGE_blockd is not set
# CONFIG_PACKAGE_bridge is not set
CONFIG_PACKAGE_busybox=y
# CONFIG_BUSYBOX_CUSTOM is not set
CONFIG_BUSYBOX_DEFAULT_HAVE_DOT_CONFIG=y
# CONFIG_BUSYBOX_DEFAULT_DESKTOP is not set
# CONFIG_BUSYBOX_DEFAULT_EXTRA_COMPAT is not set
# CONFIG_BUSYBOX_DEFAULT_FEDORA_COMPAT is not set
CONFIG_BUSYBOX_DEFAULT_INCLUDE_SUSv2=y
CONFIG_BUSYBOX_DEFAULT_LONG_OPTS=y
CONFIG_BUSYBOX_DEFAULT_SHOW_USAGE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VERBOSE_USAGE=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_COMPRESS_USAGE is not set
CONFIG_BUSYBOX_DEFAULT_LFS=y
# CONFIG_BUSYBOX_DEFAULT_PAM is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_DEVPTS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UTMP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WTMP is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_PIDFILE=y
CONFIG_BUSYBOX_DEFAULT_PID_FILE_PATH="/var/run"
# CONFIG_BUSYBOX_DEFAULT_BUSYBOX is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SHOW_SCRIPT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSTALLER is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL_NO_USR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SUID is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SUID_CONFIG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SUID_CONFIG_QUIET is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_PREFER_APPLETS=y
CONFIG_BUSYBOX_DEFAULT_BUSYBOX_EXEC_PATH="/proc/self/exe"
# CONFIG_BUSYBOX_DEFAULT_SELINUX is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CLEAN_UP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SYSLOG_INFO is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_SYSLOG=y
# CONFIG_BUSYBOX_DEFAULT_STATIC is not set
# CONFIG_BUSYBOX_DEFAULT_PIE is not set
# CONFIG_BUSYBOX_DEFAULT_NOMMU is not set
# CONFIG_BUSYBOX_DEFAULT_BUILD_LIBBUSYBOX is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LIBBUSYBOX_STATIC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INDIVIDUAL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SHARED_BUSYBOX is not set
CONFIG_BUSYBOX_DEFAULT_CROSS_COMPILER_PREFIX=""
CONFIG_BUSYBOX_DEFAULT_SYSROOT=""
CONFIG_BUSYBOX_DEFAULT_EXTRA_CFLAGS=""
CONFIG_BUSYBOX_DEFAULT_EXTRA_LDFLAGS=""
CONFIG_BUSYBOX_DEFAULT_EXTRA_LDLIBS=""
# CONFIG_BUSYBOX_DEFAULT_USE_PORTABLE_CODE is not set
# CONFIG_BUSYBOX_DEFAULT_STACK_OPTIMIZATION_386 is not set
# CONFIG_BUSYBOX_DEFAULT_STATIC_LIBGCC is not set
CONFIG_BUSYBOX_DEFAULT_INSTALL_APPLET_SYMLINKS=y
# CONFIG_BUSYBOX_DEFAULT_INSTALL_APPLET_HARDLINKS is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL_APPLET_SCRIPT_WRAPPERS is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL_APPLET_DONT is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL_SH_APPLET_SYMLINK is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL_SH_APPLET_HARDLINK is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL_SH_APPLET_SCRIPT_WRAPPER is not set
CONFIG_BUSYBOX_DEFAULT_PREFIX="./_install"
# CONFIG_BUSYBOX_DEFAULT_DEBUG is not set
# CONFIG_BUSYBOX_DEFAULT_DEBUG_PESSIMIZE is not set
# CONFIG_BUSYBOX_DEFAULT_DEBUG_SANITIZE is not set
# CONFIG_BUSYBOX_DEFAULT_UNIT_TEST is not set
# CONFIG_BUSYBOX_DEFAULT_WERROR is not set
# CONFIG_BUSYBOX_DEFAULT_WARN_SIMPLE_MSG is not set
CONFIG_BUSYBOX_DEFAULT_NO_DEBUG_LIB=y
# CONFIG_BUSYBOX_DEFAULT_DMALLOC is not set
# CONFIG_BUSYBOX_DEFAULT_EFENCE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_USE_BSS_TAIL is not set
# CONFIG_BUSYBOX_DEFAULT_FLOAT_DURATION is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_RTMINMAX is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_RTMINMAX_USE_LIBC_DEFINITIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BUFFERS_USE_MALLOC is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_BUFFERS_GO_ON_STACK=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BUFFERS_GO_IN_BSS is not set
CONFIG_BUSYBOX_DEFAULT_PASSWORD_MINLEN=6
CONFIG_BUSYBOX_DEFAULT_MD5_SMALL=1
CONFIG_BUSYBOX_DEFAULT_SHA3_SMALL=1
CONFIG_BUSYBOX_DEFAULT_FEATURE_NON_POSIX_CP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VERBOSE_CP_MESSAGE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_USE_SENDFILE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_COPYBUF_KB=4
CONFIG_BUSYBOX_DEFAULT_MONOTONIC_SYSCALL=y
CONFIG_BUSYBOX_DEFAULT_IOCTL_HEX2STR_ERROR=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_MAX_LEN=512
# CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_VI is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_HISTORY=256
# CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_SAVEHISTORY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_SAVE_ON_EXIT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_REVERSE_SEARCH is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_TAB_COMPLETION=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_USERNAME_COMPLETION is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_FANCY_PROMPT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_WINCH is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_EDITING_ASK_TERMINAL is not set
# CONFIG_BUSYBOX_DEFAULT_LOCALE_SUPPORT is not set
# CONFIG_BUSYBOX_DEFAULT_UNICODE_SUPPORT is not set
# CONFIG_BUSYBOX_DEFAULT_UNICODE_USING_LOCALE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHECK_UNICODE_IN_ENV is not set
CONFIG_BUSYBOX_DEFAULT_SUBST_WCHAR=0
CONFIG_BUSYBOX_DEFAULT_LAST_SUPPORTED_WCHAR=0
# CONFIG_BUSYBOX_DEFAULT_UNICODE_COMBINING_WCHARS is not set
# CONFIG_BUSYBOX_DEFAULT_UNICODE_WIDE_WCHARS is not set
# CONFIG_BUSYBOX_DEFAULT_UNICODE_BIDI_SUPPORT is not set
# CONFIG_BUSYBOX_DEFAULT_UNICODE_NEUTRAL_TABLE is not set
# CONFIG_BUSYBOX_DEFAULT_UNICODE_PRESERVE_BROKEN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SEAMLESS_XZ is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SEAMLESS_LZMA is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SEAMLESS_BZ2 is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_SEAMLESS_GZ=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SEAMLESS_Z is not set
# CONFIG_BUSYBOX_DEFAULT_AR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_AR_LONG_FILENAMES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_AR_CREATE is not set
# CONFIG_BUSYBOX_DEFAULT_UNCOMPRESS is not set
CONFIG_BUSYBOX_DEFAULT_GUNZIP=y
CONFIG_BUSYBOX_DEFAULT_ZCAT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_GUNZIP_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_BUNZIP2 is not set
# CONFIG_BUSYBOX_DEFAULT_BZCAT is not set
# CONFIG_BUSYBOX_DEFAULT_UNLZMA is not set
# CONFIG_BUSYBOX_DEFAULT_LZCAT is not set
# CONFIG_BUSYBOX_DEFAULT_LZMA is not set
# CONFIG_BUSYBOX_DEFAULT_UNXZ is not set
# CONFIG_BUSYBOX_DEFAULT_XZCAT is not set
# CONFIG_BUSYBOX_DEFAULT_XZ is not set
# CONFIG_BUSYBOX_DEFAULT_BZIP2 is not set
CONFIG_BUSYBOX_DEFAULT_BZIP2_SMALL=0
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BZIP2_DECOMPRESS is not set
# CONFIG_BUSYBOX_DEFAULT_CPIO is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CPIO_O is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CPIO_P is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CPIO_IGNORE_DEVNO is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CPIO_RENUMBER_INODES is not set
# CONFIG_BUSYBOX_DEFAULT_DPKG is not set
# CONFIG_BUSYBOX_DEFAULT_DPKG_DEB is not set
CONFIG_BUSYBOX_DEFAULT_GZIP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_GZIP_LONG_OPTIONS is not set
CONFIG_BUSYBOX_DEFAULT_GZIP_FAST=0
# CONFIG_BUSYBOX_DEFAULT_FEATURE_GZIP_LEVELS is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_GZIP_DECOMPRESS=y
# CONFIG_BUSYBOX_DEFAULT_LZOP is not set
# CONFIG_BUSYBOX_DEFAULT_UNLZOP is not set
# CONFIG_BUSYBOX_DEFAULT_LZOPCAT is not set
# CONFIG_BUSYBOX_DEFAULT_LZOP_COMPR_HIGH is not set
# CONFIG_BUSYBOX_DEFAULT_RPM is not set
# CONFIG_BUSYBOX_DEFAULT_RPM2CPIO is not set
CONFIG_BUSYBOX_DEFAULT_TAR=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_LONG_OPTIONS is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_CREATE=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_AUTODETECT is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_FROM=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_OLDGNU_COMPATIBILITY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_OLDSUN_COMPATIBILITY is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_GNU_EXTENSIONS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_TO_COMMAND is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_UNAME_GNAME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_NOPRESERVE_TIME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TAR_SELINUX is not set
# CONFIG_BUSYBOX_DEFAULT_UNZIP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UNZIP_CDF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UNZIP_BZIP2 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UNZIP_LZMA is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UNZIP_XZ is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LZMA_FAST is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VERBOSE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TIMEZONE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_PRESERVE_HARDLINKS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_HUMAN_READABLE=y
CONFIG_BUSYBOX_DEFAULT_BASENAME=y
CONFIG_BUSYBOX_DEFAULT_CAT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CATN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CATV is not set
CONFIG_BUSYBOX_DEFAULT_CHGRP=y
CONFIG_BUSYBOX_DEFAULT_CHMOD=y
CONFIG_BUSYBOX_DEFAULT_CHOWN=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHOWN_LONG_OPTIONS is not set
CONFIG_BUSYBOX_DEFAULT_CHROOT=y
# CONFIG_BUSYBOX_DEFAULT_CKSUM is not set
# CONFIG_BUSYBOX_DEFAULT_CRC32 is not set
# CONFIG_BUSYBOX_DEFAULT_COMM is not set
CONFIG_BUSYBOX_DEFAULT_CP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CP_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CP_REFLINK is not set
CONFIG_BUSYBOX_DEFAULT_CUT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CUT_REGEX is not set
CONFIG_BUSYBOX_DEFAULT_DATE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_DATE_ISOFMT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DATE_NANO is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DATE_COMPAT is not set
CONFIG_BUSYBOX_DEFAULT_DD=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_DD_SIGNAL_HANDLING=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DD_THIRD_STATUS_LINE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_DD_IBS_OBS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DD_STATUS is not set
CONFIG_BUSYBOX_DEFAULT_DF=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DF_FANCY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SKIP_ROOTFS is not set
CONFIG_BUSYBOX_DEFAULT_DIRNAME=y
# CONFIG_BUSYBOX_DEFAULT_DOS2UNIX is not set
# CONFIG_BUSYBOX_DEFAULT_UNIX2DOS is not set
CONFIG_BUSYBOX_DEFAULT_DU=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_DU_DEFAULT_BLOCKSIZE_1K=y
CONFIG_BUSYBOX_DEFAULT_ECHO=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FANCY_ECHO=y
CONFIG_BUSYBOX_DEFAULT_ENV=y
# CONFIG_BUSYBOX_DEFAULT_EXPAND is not set
# CONFIG_BUSYBOX_DEFAULT_UNEXPAND is not set
CONFIG_BUSYBOX_DEFAULT_EXPR=y
CONFIG_BUSYBOX_DEFAULT_EXPR_MATH_SUPPORT_64=y
# CONFIG_BUSYBOX_DEFAULT_FACTOR is not set
CONFIG_BUSYBOX_DEFAULT_FALSE=y
# CONFIG_BUSYBOX_DEFAULT_FOLD is not set
CONFIG_BUSYBOX_DEFAULT_HEAD=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FANCY_HEAD=y
# CONFIG_BUSYBOX_DEFAULT_HOSTID is not set
CONFIG_BUSYBOX_DEFAULT_ID=y
# CONFIG_BUSYBOX_DEFAULT_GROUPS is not set
# CONFIG_BUSYBOX_DEFAULT_INSTALL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSTALL_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_LINK is not set
CONFIG_BUSYBOX_DEFAULT_LN=y
# CONFIG_BUSYBOX_DEFAULT_LOGNAME is not set
CONFIG_BUSYBOX_DEFAULT_LS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_FILETYPES=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_FOLLOWLINKS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_RECURSIVE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_WIDTH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_SORTFILES=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_TIMESTAMPS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_USERNAME=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_COLOR=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LS_COLOR_IS_DEFAULT=y
CONFIG_BUSYBOX_DEFAULT_MD5SUM=y
# CONFIG_BUSYBOX_DEFAULT_SHA1SUM is not set
CONFIG_BUSYBOX_DEFAULT_SHA256SUM=y
# CONFIG_BUSYBOX_DEFAULT_SHA512SUM is not set
# CONFIG_BUSYBOX_DEFAULT_SHA3SUM is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_MD5_SHA1_SUM_CHECK=y
CONFIG_BUSYBOX_DEFAULT_MKDIR=y
CONFIG_BUSYBOX_DEFAULT_MKFIFO=y
CONFIG_BUSYBOX_DEFAULT_MKNOD=y
CONFIG_BUSYBOX_DEFAULT_MKTEMP=y
CONFIG_BUSYBOX_DEFAULT_MV=y
CONFIG_BUSYBOX_DEFAULT_NICE=y
# CONFIG_BUSYBOX_DEFAULT_NL is not set
# CONFIG_BUSYBOX_DEFAULT_NOHUP is not set
# CONFIG_BUSYBOX_DEFAULT_NPROC is not set
# CONFIG_BUSYBOX_DEFAULT_OD is not set
# CONFIG_BUSYBOX_DEFAULT_PASTE is not set
# CONFIG_BUSYBOX_DEFAULT_PRINTENV is not set
CONFIG_BUSYBOX_DEFAULT_PRINTF=y
CONFIG_BUSYBOX_DEFAULT_PWD=y
CONFIG_BUSYBOX_DEFAULT_READLINK=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_READLINK_FOLLOW=y
# CONFIG_BUSYBOX_DEFAULT_REALPATH is not set
CONFIG_BUSYBOX_DEFAULT_RM=y
CONFIG_BUSYBOX_DEFAULT_RMDIR=y
CONFIG_BUSYBOX_DEFAULT_SEQ=y
# CONFIG_BUSYBOX_DEFAULT_SHRED is not set
# CONFIG_BUSYBOX_DEFAULT_SHUF is not set
CONFIG_BUSYBOX_DEFAULT_SLEEP=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FANCY_SLEEP=y
CONFIG_BUSYBOX_DEFAULT_SORT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SORT_BIG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SORT_OPTIMIZE_MEMORY is not set
# CONFIG_BUSYBOX_DEFAULT_SPLIT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SPLIT_FANCY is not set
# CONFIG_BUSYBOX_DEFAULT_STAT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_STAT_FORMAT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_STAT_FILESYSTEM is not set
# CONFIG_BUSYBOX_DEFAULT_STTY is not set
# CONFIG_BUSYBOX_DEFAULT_SUM is not set
CONFIG_BUSYBOX_DEFAULT_SYNC=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SYNC_FANCY is not set
CONFIG_BUSYBOX_DEFAULT_FSYNC=y
# CONFIG_BUSYBOX_DEFAULT_TAC is not set
CONFIG_BUSYBOX_DEFAULT_TAIL=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FANCY_TAIL=y
CONFIG_BUSYBOX_DEFAULT_TEE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_TEE_USE_BLOCK_IO=y
CONFIG_BUSYBOX_DEFAULT_TEST=y
CONFIG_BUSYBOX_DEFAULT_TEST1=y
CONFIG_BUSYBOX_DEFAULT_TEST2=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_TEST_64=y
# CONFIG_BUSYBOX_DEFAULT_TIMEOUT is not set
CONFIG_BUSYBOX_DEFAULT_TOUCH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_TOUCH_SUSV3=y
CONFIG_BUSYBOX_DEFAULT_TR=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TR_CLASSES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TR_EQUIV is not set
CONFIG_BUSYBOX_DEFAULT_TRUE=y
# CONFIG_BUSYBOX_DEFAULT_TRUNCATE is not set
# CONFIG_BUSYBOX_DEFAULT_TTY is not set
CONFIG_BUSYBOX_DEFAULT_UNAME=y
CONFIG_BUSYBOX_DEFAULT_UNAME_OSNAME="GNU/Linux"
# CONFIG_BUSYBOX_DEFAULT_BB_ARCH is not set
CONFIG_BUSYBOX_DEFAULT_UNIQ=y
# CONFIG_BUSYBOX_DEFAULT_UNLINK is not set
# CONFIG_BUSYBOX_DEFAULT_USLEEP is not set
# CONFIG_BUSYBOX_DEFAULT_UUDECODE is not set
# CONFIG_BUSYBOX_DEFAULT_BASE32 is not set
# CONFIG_BUSYBOX_DEFAULT_BASE64 is not set
# CONFIG_BUSYBOX_DEFAULT_UUENCODE is not set
CONFIG_BUSYBOX_DEFAULT_WC=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WC_LARGE is not set
# CONFIG_BUSYBOX_DEFAULT_WHO is not set
# CONFIG_BUSYBOX_DEFAULT_W is not set
# CONFIG_BUSYBOX_DEFAULT_USERS is not set
# CONFIG_BUSYBOX_DEFAULT_WHOAMI is not set
CONFIG_BUSYBOX_DEFAULT_YES=y
# CONFIG_BUSYBOX_DEFAULT_CHVT is not set
CONFIG_BUSYBOX_DEFAULT_CLEAR=y
# CONFIG_BUSYBOX_DEFAULT_DEALLOCVT is not set
# CONFIG_BUSYBOX_DEFAULT_DUMPKMAP is not set
# CONFIG_BUSYBOX_DEFAULT_FGCONSOLE is not set
# CONFIG_BUSYBOX_DEFAULT_KBD_MODE is not set
# CONFIG_BUSYBOX_DEFAULT_LOADFONT is not set
# CONFIG_BUSYBOX_DEFAULT_SETFONT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SETFONT_TEXTUAL_MAP is not set
CONFIG_BUSYBOX_DEFAULT_DEFAULT_SETFONT_DIR=""
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LOADFONT_PSF2 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LOADFONT_RAW is not set
# CONFIG_BUSYBOX_DEFAULT_LOADKMAP is not set
# CONFIG_BUSYBOX_DEFAULT_OPENVT is not set
CONFIG_BUSYBOX_DEFAULT_RESET=y
# CONFIG_BUSYBOX_DEFAULT_RESIZE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_RESIZE_PRINT is not set
# CONFIG_BUSYBOX_DEFAULT_SETCONSOLE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SETCONSOLE_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_SETKEYCODES is not set
# CONFIG_BUSYBOX_DEFAULT_SETLOGCONS is not set
# CONFIG_BUSYBOX_DEFAULT_SHOWKEY is not set
# CONFIG_BUSYBOX_DEFAULT_PIPE_PROGRESS is not set
# CONFIG_BUSYBOX_DEFAULT_RUN_PARTS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_RUN_PARTS_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_RUN_PARTS_FANCY is not set
CONFIG_BUSYBOX_DEFAULT_START_STOP_DAEMON=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_START_STOP_DAEMON_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_START_STOP_DAEMON_FANCY is not set
CONFIG_BUSYBOX_DEFAULT_WHICH=y
# CONFIG_BUSYBOX_DEFAULT_MINIPS is not set
# CONFIG_BUSYBOX_DEFAULT_NUKE is not set
# CONFIG_BUSYBOX_DEFAULT_RESUME is not set
# CONFIG_BUSYBOX_DEFAULT_RUN_INIT is not set
CONFIG_BUSYBOX_DEFAULT_AWK=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_AWK_LIBM=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_AWK_GNU_EXTENSIONS=y
CONFIG_BUSYBOX_DEFAULT_CMP=y
# CONFIG_BUSYBOX_DEFAULT_DIFF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DIFF_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DIFF_DIR is not set
# CONFIG_BUSYBOX_DEFAULT_ED is not set
# CONFIG_BUSYBOX_DEFAULT_PATCH is not set
CONFIG_BUSYBOX_DEFAULT_SED=y
CONFIG_BUSYBOX_DEFAULT_VI=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_MAX_LEN=1024
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_8BIT is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_COLON=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_COLON_EXPAND is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_YANKMARK=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_SEARCH=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_REGEX_SEARCH is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_USE_SIGNALS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_DOT_CMD=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_READONLY=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_SETOPTS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_SET=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_WIN_RESIZE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_ASK_TERMINAL=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_UNDO is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_UNDO_QUEUE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_UNDO_QUEUE_MAX=0
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VI_VERBOSE_STATUS is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_ALLOW_EXEC=y
CONFIG_BUSYBOX_DEFAULT_FIND=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_PRINT0=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_MTIME=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_ATIME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_CTIME is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_MMIN=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_AMIN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_CMIN is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_PERM=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_TYPE=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_EXECUTABLE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_XDEV=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_MAXDEPTH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_NEWER=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_INUM is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_SAMEFILE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_EXEC=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_EXEC_PLUS is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_USER=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_GROUP=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_NOT=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_DEPTH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_PAREN=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_SIZE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_PRUNE=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_QUIT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_DELETE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_EMPTY is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_PATH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_REGEX=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_CONTEXT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FIND_LINKS is not set
CONFIG_BUSYBOX_DEFAULT_GREP=y
CONFIG_BUSYBOX_DEFAULT_EGREP=y
CONFIG_BUSYBOX_DEFAULT_FGREP=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_GREP_CONTEXT=y
CONFIG_BUSYBOX_DEFAULT_XARGS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_CONFIRMATION=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_QUOTES=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_TERMOPT=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_ZERO_TERM=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_REPL_STR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_PARALLEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_XARGS_SUPPORT_ARGS_FILE is not set
# CONFIG_BUSYBOX_DEFAULT_BOOTCHARTD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BOOTCHARTD_BLOATED_HEADER is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BOOTCHARTD_CONFIG_FILE is not set
CONFIG_BUSYBOX_DEFAULT_HALT=y
CONFIG_BUSYBOX_DEFAULT_POWEROFF=y
CONFIG_BUSYBOX_DEFAULT_REBOOT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WAIT_FOR_INIT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CALL_TELINIT is not set
CONFIG_BUSYBOX_DEFAULT_TELINIT_PATH=""
# CONFIG_BUSYBOX_DEFAULT_INIT is not set
# CONFIG_BUSYBOX_DEFAULT_LINUXRC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_USE_INITTAB is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_KILL_REMOVED is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_KILL_DELAY=0
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INIT_SCTTY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INIT_SYSLOG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INIT_QUIET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INIT_COREDUMPS is not set
CONFIG_BUSYBOX_DEFAULT_INIT_TERMINAL_TYPE=""
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INIT_MODIFY_CMDLINE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_SHADOWPASSWDS=y
# CONFIG_BUSYBOX_DEFAULT_USE_BB_PWD_GRP is not set
# CONFIG_BUSYBOX_DEFAULT_USE_BB_SHADOW is not set
# CONFIG_BUSYBOX_DEFAULT_USE_BB_CRYPT is not set
# CONFIG_BUSYBOX_DEFAULT_USE_BB_CRYPT_SHA is not set
# CONFIG_BUSYBOX_DEFAULT_ADD_SHELL is not set
# CONFIG_BUSYBOX_DEFAULT_REMOVE_SHELL is not set
# CONFIG_BUSYBOX_DEFAULT_ADDGROUP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_ADDUSER_TO_GROUP is not set
# CONFIG_BUSYBOX_DEFAULT_ADDUSER is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHECK_NAMES is not set
CONFIG_BUSYBOX_DEFAULT_LAST_ID=0
CONFIG_BUSYBOX_DEFAULT_FIRST_SYSTEM_ID=0
CONFIG_BUSYBOX_DEFAULT_LAST_SYSTEM_ID=0
# CONFIG_BUSYBOX_DEFAULT_CHPASSWD is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_DEFAULT_PASSWD_ALGO="md5"
# CONFIG_BUSYBOX_DEFAULT_CRYPTPW is not set
# CONFIG_BUSYBOX_DEFAULT_MKPASSWD is not set
# CONFIG_BUSYBOX_DEFAULT_DELUSER is not set
# CONFIG_BUSYBOX_DEFAULT_DELGROUP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DEL_USER_FROM_GROUP is not set
# CONFIG_BUSYBOX_DEFAULT_GETTY is not set
CONFIG_BUSYBOX_DEFAULT_LOGIN=y
CONFIG_BUSYBOX_DEFAULT_LOGIN_SESSION_AS_CHILD=y
# CONFIG_BUSYBOX_DEFAULT_LOGIN_SCRIPTS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_NOLOGIN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SECURETTY is not set
CONFIG_BUSYBOX_DEFAULT_PASSWD=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_PASSWD_WEAK_CHECK=y
# CONFIG_BUSYBOX_DEFAULT_SU is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SU_SYSLOG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SU_CHECKS_SHELLS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SU_BLANK_PW_NEEDS_SECURE_TTY is not set
# CONFIG_BUSYBOX_DEFAULT_SULOGIN is not set
# CONFIG_BUSYBOX_DEFAULT_VLOCK is not set
# CONFIG_BUSYBOX_DEFAULT_CHATTR is not set
# CONFIG_BUSYBOX_DEFAULT_FSCK is not set
# CONFIG_BUSYBOX_DEFAULT_LSATTR is not set
# CONFIG_BUSYBOX_DEFAULT_TUNE2FS is not set
# CONFIG_BUSYBOX_DEFAULT_MODPROBE_SMALL is not set
# CONFIG_BUSYBOX_DEFAULT_DEPMOD is not set
# CONFIG_BUSYBOX_DEFAULT_INSMOD is not set
# CONFIG_BUSYBOX_DEFAULT_LSMOD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LSMOD_PRETTY_2_6_OUTPUT is not set
# CONFIG_BUSYBOX_DEFAULT_MODINFO is not set
# CONFIG_BUSYBOX_DEFAULT_MODPROBE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MODPROBE_BLACKLIST is not set
# CONFIG_BUSYBOX_DEFAULT_RMMOD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CMDLINE_MODULE_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MODPROBE_SMALL_CHECK_ALREADY_LOADED is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_2_4_MODULES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSMOD_VERSION_CHECKING is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSMOD_KSYMOOPS_SYMBOLS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSMOD_LOADINKMEM is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSMOD_LOAD_MAP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSMOD_LOAD_MAP_FULL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHECK_TAINTED_MODULE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INSMOD_TRY_MMAP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MODUTILS_ALIAS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MODUTILS_SYMBOLS is not set
CONFIG_BUSYBOX_DEFAULT_DEFAULT_MODULES_DIR=""
CONFIG_BUSYBOX_DEFAULT_DEFAULT_DEPMOD_FILE=""
# CONFIG_BUSYBOX_DEFAULT_ACPID is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_ACPID_COMPAT is not set
# CONFIG_BUSYBOX_DEFAULT_BLKDISCARD is not set
# CONFIG_BUSYBOX_DEFAULT_BLKID is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BLKID_TYPE is not set
# CONFIG_BUSYBOX_DEFAULT_BLOCKDEV is not set
# CONFIG_BUSYBOX_DEFAULT_CAL is not set
# CONFIG_BUSYBOX_DEFAULT_CHRT is not set
CONFIG_BUSYBOX_DEFAULT_DMESG=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_DMESG_PRETTY=y
# CONFIG_BUSYBOX_DEFAULT_EJECT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_EJECT_SCSI is not set
# CONFIG_BUSYBOX_DEFAULT_FALLOCATE is not set
# CONFIG_BUSYBOX_DEFAULT_FATATTR is not set
# CONFIG_BUSYBOX_DEFAULT_FBSET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FBSET_FANCY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FBSET_READMODE is not set
# CONFIG_BUSYBOX_DEFAULT_FDFORMAT is not set
# CONFIG_BUSYBOX_DEFAULT_FDISK is not set
# CONFIG_BUSYBOX_DEFAULT_FDISK_SUPPORT_LARGE_DISKS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FDISK_WRITABLE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_AIX_LABEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SGI_LABEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SUN_LABEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_OSF_LABEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_GPT_LABEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FDISK_ADVANCED is not set
# CONFIG_BUSYBOX_DEFAULT_FINDFS is not set
CONFIG_BUSYBOX_DEFAULT_FLOCK=y
# CONFIG_BUSYBOX_DEFAULT_FDFLUSH is not set
# CONFIG_BUSYBOX_DEFAULT_FREERAMDISK is not set
# CONFIG_BUSYBOX_DEFAULT_FSCK_MINIX is not set
# CONFIG_BUSYBOX_DEFAULT_FSFREEZE is not set
# CONFIG_BUSYBOX_DEFAULT_FSTRIM is not set
# CONFIG_BUSYBOX_DEFAULT_GETOPT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_GETOPT_LONG is not set
CONFIG_BUSYBOX_DEFAULT_HEXDUMP=y
# CONFIG_BUSYBOX_DEFAULT_HD is not set
# CONFIG_BUSYBOX_DEFAULT_XXD is not set
CONFIG_BUSYBOX_DEFAULT_HWCLOCK=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HWCLOCK_ADJTIME_FHS is not set
# CONFIG_BUSYBOX_DEFAULT_IONICE is not set
# CONFIG_BUSYBOX_DEFAULT_IPCRM is not set
# CONFIG_BUSYBOX_DEFAULT_IPCS is not set
# CONFIG_BUSYBOX_DEFAULT_LAST is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LAST_FANCY is not set
# CONFIG_BUSYBOX_DEFAULT_LOSETUP is not set
# CONFIG_BUSYBOX_DEFAULT_LSPCI is not set
# CONFIG_BUSYBOX_DEFAULT_LSUSB is not set
# CONFIG_BUSYBOX_DEFAULT_MDEV is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MDEV_CONF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MDEV_RENAME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MDEV_RENAME_REGEXP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MDEV_EXEC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MDEV_LOAD_FIRMWARE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MDEV_DAEMON is not set
# CONFIG_BUSYBOX_DEFAULT_MESG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MESG_ENABLE_ONLY_GROUP is not set
# CONFIG_BUSYBOX_DEFAULT_MKE2FS is not set
# CONFIG_BUSYBOX_DEFAULT_MKFS_EXT2 is not set
# CONFIG_BUSYBOX_DEFAULT_MKFS_MINIX is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MINIX2 is not set
# CONFIG_BUSYBOX_DEFAULT_MKFS_REISER is not set
# CONFIG_BUSYBOX_DEFAULT_MKDOSFS is not set
# CONFIG_BUSYBOX_DEFAULT_MKFS_VFAT is not set
CONFIG_BUSYBOX_DEFAULT_MKSWAP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MKSWAP_UUID is not set
# CONFIG_BUSYBOX_DEFAULT_MORE is not set
CONFIG_BUSYBOX_DEFAULT_MOUNT=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_FAKE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_VERBOSE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_HELPERS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_LABEL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_NFS is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_CIFS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_FLAGS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_FSTAB=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_OTHERTAB is not set
# CONFIG_BUSYBOX_DEFAULT_MOUNTPOINT is not set
# CONFIG_BUSYBOX_DEFAULT_NOLOGIN is not set
# CONFIG_BUSYBOX_DEFAULT_NOLOGIN_DEPENDENCIES is not set
# CONFIG_BUSYBOX_DEFAULT_NSENTER is not set
CONFIG_BUSYBOX_DEFAULT_PIVOT_ROOT=y
# CONFIG_BUSYBOX_DEFAULT_RDATE is not set
# CONFIG_BUSYBOX_DEFAULT_RDEV is not set
# CONFIG_BUSYBOX_DEFAULT_READPROFILE is not set
# CONFIG_BUSYBOX_DEFAULT_RENICE is not set
# CONFIG_BUSYBOX_DEFAULT_REV is not set
# CONFIG_BUSYBOX_DEFAULT_RTCWAKE is not set
# CONFIG_BUSYBOX_DEFAULT_SCRIPT is not set
# CONFIG_BUSYBOX_DEFAULT_SCRIPTREPLAY is not set
# CONFIG_BUSYBOX_DEFAULT_SETARCH is not set
# CONFIG_BUSYBOX_DEFAULT_LINUX32 is not set
# CONFIG_BUSYBOX_DEFAULT_LINUX64 is not set
# CONFIG_BUSYBOX_DEFAULT_SETPRIV is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SETPRIV_DUMP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SETPRIV_CAPABILITIES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SETPRIV_CAPABILITY_NAMES is not set
# CONFIG_BUSYBOX_DEFAULT_SETSID is not set
CONFIG_BUSYBOX_DEFAULT_SWAPON=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_SWAPON_DISCARD=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_SWAPON_PRI=y
CONFIG_BUSYBOX_DEFAULT_SWAPOFF=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SWAPONOFF_LABEL is not set
CONFIG_BUSYBOX_DEFAULT_SWITCH_ROOT=y
# CONFIG_BUSYBOX_DEFAULT_TASKSET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TASKSET_FANCY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TASKSET_CPULIST is not set
# CONFIG_BUSYBOX_DEFAULT_UEVENT is not set
CONFIG_BUSYBOX_DEFAULT_UMOUNT=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_UMOUNT_ALL=y
# CONFIG_BUSYBOX_DEFAULT_UNSHARE is not set
# CONFIG_BUSYBOX_DEFAULT_WALL is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_LOOP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MOUNT_LOOP_CREATE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MTAB_SUPPORT is not set
# CONFIG_BUSYBOX_DEFAULT_VOLUMEID is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_BCACHE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_BTRFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_CRAMFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_EROFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_EXFAT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_EXT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_F2FS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_FAT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_HFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_ISO9660 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_JFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_LFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_LINUXRAID is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_LINUXSWAP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_LUKS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_MINIX is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_NILFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_NTFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_OCFS2 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_REISERFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_ROMFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_SQUASHFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_SYSV is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_UBIFS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_UDF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_VOLUMEID_XFS is not set
# CONFIG_BUSYBOX_DEFAULT_ADJTIMEX is not set
# CONFIG_BUSYBOX_DEFAULT_ASCII is not set
# CONFIG_BUSYBOX_DEFAULT_BBCONFIG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_COMPRESS_BBCONFIG is not set
# CONFIG_BUSYBOX_DEFAULT_BC is not set
# CONFIG_BUSYBOX_DEFAULT_DC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DC_BIG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DC_LIBM is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BC_INTERACTIVE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_BC_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_BEEP is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_BEEP_FREQ=0
CONFIG_BUSYBOX_DEFAULT_FEATURE_BEEP_LENGTH_MS=0
# CONFIG_BUSYBOX_DEFAULT_CHAT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_NOFAIL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_TTY_HIFI is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_IMPLICIT_CR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_SWALLOW_OPTS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_SEND_ESCAPES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_VAR_ABORT_LEN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CHAT_CLR_ABORT is not set
# CONFIG_BUSYBOX_DEFAULT_CONSPY is not set
CONFIG_BUSYBOX_DEFAULT_CROND=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CROND_D is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CROND_CALL_SENDMAIL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_CROND_SPECIAL_TIMES is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_CROND_DIR="/etc"
CONFIG_BUSYBOX_DEFAULT_CRONTAB=y
# CONFIG_BUSYBOX_DEFAULT_DEVFSD is not set
# CONFIG_BUSYBOX_DEFAULT_DEVFSD_MODLOAD is not set
# CONFIG_BUSYBOX_DEFAULT_DEVFSD_FG_NP is not set
# CONFIG_BUSYBOX_DEFAULT_DEVFSD_VERBOSE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_DEVFS is not set
# CONFIG_BUSYBOX_DEFAULT_DEVMEM is not set
# CONFIG_BUSYBOX_DEFAULT_FBSPLASH is not set
# CONFIG_BUSYBOX_DEFAULT_FLASH_ERASEALL is not set
# CONFIG_BUSYBOX_DEFAULT_FLASH_LOCK is not set
# CONFIG_BUSYBOX_DEFAULT_FLASH_UNLOCK is not set
# CONFIG_BUSYBOX_DEFAULT_FLASHCP is not set
# CONFIG_BUSYBOX_DEFAULT_HDPARM is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HDPARM_GET_IDENTITY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HDPARM_HDIO_SCAN_HWIF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HDPARM_HDIO_UNREGISTER_HWIF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HDPARM_HDIO_DRIVE_RESET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HDPARM_HDIO_TRISTATE_HWIF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HDPARM_HDIO_GETSET_DMA is not set
# CONFIG_BUSYBOX_DEFAULT_HEXEDIT is not set
# CONFIG_BUSYBOX_DEFAULT_I2CGET is not set
# CONFIG_BUSYBOX_DEFAULT_I2CSET is not set
# CONFIG_BUSYBOX_DEFAULT_I2CDUMP is not set
# CONFIG_BUSYBOX_DEFAULT_I2CDETECT is not set
# CONFIG_BUSYBOX_DEFAULT_I2CTRANSFER is not set
# CONFIG_BUSYBOX_DEFAULT_INOTIFYD is not set
CONFIG_BUSYBOX_DEFAULT_LESS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_MAXLINES=9999999
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_BRACKETS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_FLAGS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_TRUNCATE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_MARKS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_REGEXP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_WINCH is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_ASK_TERMINAL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_DASHCMD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_LINENUMS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_RAW is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LESS_ENV is not set
CONFIG_BUSYBOX_DEFAULT_LOCK=y
# CONFIG_BUSYBOX_DEFAULT_LSSCSI is not set
# CONFIG_BUSYBOX_DEFAULT_MAKEDEVS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MAKEDEVS_LEAF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_MAKEDEVS_TABLE is not set
# CONFIG_BUSYBOX_DEFAULT_MAN is not set
# CONFIG_BUSYBOX_DEFAULT_MICROCOM is not set
# CONFIG_BUSYBOX_DEFAULT_MIM is not set
# CONFIG_BUSYBOX_DEFAULT_MT is not set
# CONFIG_BUSYBOX_DEFAULT_NANDWRITE is not set
# CONFIG_BUSYBOX_DEFAULT_NANDDUMP is not set
# CONFIG_BUSYBOX_DEFAULT_PARTPROBE is not set
# CONFIG_BUSYBOX_DEFAULT_RAIDAUTORUN is not set
# CONFIG_BUSYBOX_DEFAULT_READAHEAD is not set
# CONFIG_BUSYBOX_DEFAULT_RFKILL is not set
# CONFIG_BUSYBOX_DEFAULT_RUNLEVEL is not set
# CONFIG_BUSYBOX_DEFAULT_RX is not set
# CONFIG_BUSYBOX_DEFAULT_SETFATTR is not set
# CONFIG_BUSYBOX_DEFAULT_SETSERIAL is not set
CONFIG_BUSYBOX_DEFAULT_STRINGS=y
CONFIG_BUSYBOX_DEFAULT_TIME=y
# CONFIG_BUSYBOX_DEFAULT_TS is not set
# CONFIG_BUSYBOX_DEFAULT_TTYSIZE is not set
# CONFIG_BUSYBOX_DEFAULT_UBIATTACH is not set
# CONFIG_BUSYBOX_DEFAULT_UBIDETACH is not set
# CONFIG_BUSYBOX_DEFAULT_UBIMKVOL is not set
# CONFIG_BUSYBOX_DEFAULT_UBIRMVOL is not set
# CONFIG_BUSYBOX_DEFAULT_UBIRSVOL is not set
# CONFIG_BUSYBOX_DEFAULT_UBIUPDATEVOL is not set
# CONFIG_BUSYBOX_DEFAULT_UBIRENAME is not set
# CONFIG_BUSYBOX_DEFAULT_VOLNAME is not set
# CONFIG_BUSYBOX_DEFAULT_WATCHDOG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WATCHDOG_OPEN_TWICE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_IPV6=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UNIX_LOCAL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PREFER_IPV4_ADDRESS is not set
CONFIG_BUSYBOX_DEFAULT_VERBOSE_RESOLUTION_ERRORS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_ETC_NETWORKS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_ETC_SERVICES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HWIB is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TLS_SHA1 is not set
# CONFIG_BUSYBOX_DEFAULT_ARP is not set
# CONFIG_BUSYBOX_DEFAULT_ARPING is not set
CONFIG_BUSYBOX_DEFAULT_BRCTL=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_BRCTL_FANCY=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_BRCTL_SHOW=y
# CONFIG_BUSYBOX_DEFAULT_DNSD is not set
# CONFIG_BUSYBOX_DEFAULT_ETHER_WAKE is not set
# CONFIG_BUSYBOX_DEFAULT_FTPD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FTPD_WRITE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FTPD_ACCEPT_BROKEN_LIST is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FTPD_AUTHENTICATION is not set
# CONFIG_BUSYBOX_DEFAULT_FTPGET is not set
# CONFIG_BUSYBOX_DEFAULT_FTPPUT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_FTPGETPUT_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_HOSTNAME is not set
# CONFIG_BUSYBOX_DEFAULT_DNSDOMAINNAME is not set
# CONFIG_BUSYBOX_DEFAULT_HTTPD is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_PORT_DEFAULT=80
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_RANGES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_SETUID is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_BASIC_AUTH is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_AUTH_MD5 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_CGI is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_CONFIG_WITH_SCRIPT_INTERPR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_SET_REMOTE_PORT_TO_ENV is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_ENCODE_URL_STR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_ERROR_PAGES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_PROXY is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_GZIP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_ETAG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_LAST_MODIFIED is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_DATE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_HTTPD_ACL_IP is not set
CONFIG_BUSYBOX_DEFAULT_IFCONFIG=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_IFCONFIG_STATUS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFCONFIG_SLIP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFCONFIG_MEMSTART_IOADDR_IRQ is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_IFCONFIG_HW=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_IFCONFIG_BROADCAST_PLUS=y
# CONFIG_BUSYBOX_DEFAULT_IFENSLAVE is not set
# CONFIG_BUSYBOX_DEFAULT_IFPLUGD is not set
# CONFIG_BUSYBOX_DEFAULT_IFUP is not set
# CONFIG_BUSYBOX_DEFAULT_IFDOWN is not set
CONFIG_BUSYBOX_DEFAULT_IFUPDOWN_IFSTATE_PATH=""
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFUPDOWN_IP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFUPDOWN_IPV4 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFUPDOWN_IPV6 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFUPDOWN_MAPPING is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IFUPDOWN_EXTERNAL_DHCP is not set
# CONFIG_BUSYBOX_DEFAULT_INETD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INETD_SUPPORT_BUILTIN_ECHO is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INETD_SUPPORT_BUILTIN_DISCARD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INETD_SUPPORT_BUILTIN_TIME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INETD_SUPPORT_BUILTIN_DAYTIME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INETD_SUPPORT_BUILTIN_CHARGEN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_INETD_RPC is not set
CONFIG_BUSYBOX_DEFAULT_IP=y
# CONFIG_BUSYBOX_DEFAULT_IPADDR is not set
# CONFIG_BUSYBOX_DEFAULT_IPLINK is not set
# CONFIG_BUSYBOX_DEFAULT_IPROUTE is not set
# CONFIG_BUSYBOX_DEFAULT_IPTUNNEL is not set
# CONFIG_BUSYBOX_DEFAULT_IPRULE is not set
# CONFIG_BUSYBOX_DEFAULT_IPNEIGH is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_ADDRESS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_LINK=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_ROUTE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_ROUTE_DIR="/etc/iproute2"
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_TUNNEL is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_RULE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_NEIGH=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IP_RARE_PROTOCOLS is not set
# CONFIG_BUSYBOX_DEFAULT_IPCALC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IPCALC_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IPCALC_FANCY is not set
# CONFIG_BUSYBOX_DEFAULT_FAKEIDENTD is not set
# CONFIG_BUSYBOX_DEFAULT_NAMEIF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_NAMEIF_EXTENDED is not set
# CONFIG_BUSYBOX_DEFAULT_NBDCLIENT is not set
CONFIG_BUSYBOX_DEFAULT_NC=y
# CONFIG_BUSYBOX_DEFAULT_NETCAT is not set
# CONFIG_BUSYBOX_DEFAULT_NC_SERVER is not set
# CONFIG_BUSYBOX_DEFAULT_NC_EXTRA is not set
# CONFIG_BUSYBOX_DEFAULT_NC_110_COMPAT is not set
CONFIG_BUSYBOX_DEFAULT_NETMSG=y
CONFIG_BUSYBOX_DEFAULT_NETSTAT=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_NETSTAT_WIDE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_NETSTAT_PRG=y
CONFIG_BUSYBOX_DEFAULT_NSLOOKUP=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_NSLOOKUP_BIG=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_NSLOOKUP_LONG_OPTIONS is not set
CONFIG_BUSYBOX_DEFAULT_NTPD=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_NTPD_SERVER=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_NTPD_CONF is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_NTP_AUTH is not set
CONFIG_BUSYBOX_DEFAULT_PING=y
CONFIG_BUSYBOX_DEFAULT_PING6=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_FANCY_PING=y
# CONFIG_BUSYBOX_DEFAULT_PSCAN is not set
CONFIG_BUSYBOX_DEFAULT_ROUTE=y
# CONFIG_BUSYBOX_DEFAULT_SLATTACH is not set
# CONFIG_BUSYBOX_DEFAULT_SSL_CLIENT is not set
# CONFIG_BUSYBOX_DEFAULT_TC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TC_INGRESS is not set
# CONFIG_BUSYBOX_DEFAULT_TCPSVD is not set
# CONFIG_BUSYBOX_DEFAULT_UDPSVD is not set
# CONFIG_BUSYBOX_DEFAULT_TELNET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TELNET_TTYPE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TELNET_AUTOLOGIN is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TELNET_WIDTH is not set
# CONFIG_BUSYBOX_DEFAULT_TELNETD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TELNETD_STANDALONE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_TELNETD_PORT_DEFAULT=23
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TELNETD_INETD_WAIT is not set
# CONFIG_BUSYBOX_DEFAULT_TFTP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TFTP_PROGRESS_BAR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TFTP_HPA_COMPAT is not set
# CONFIG_BUSYBOX_DEFAULT_TFTPD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TFTP_GET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TFTP_PUT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TFTP_BLOCKSIZE is not set
# CONFIG_BUSYBOX_DEFAULT_TFTP_DEBUG is not set
# CONFIG_BUSYBOX_DEFAULT_TLS is not set
CONFIG_BUSYBOX_DEFAULT_TRACEROUTE=y
CONFIG_BUSYBOX_DEFAULT_TRACEROUTE6=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_TRACEROUTE_VERBOSE=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TRACEROUTE_USE_ICMP is not set
# CONFIG_BUSYBOX_DEFAULT_TUNCTL is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TUNCTL_UG is not set
# CONFIG_BUSYBOX_DEFAULT_VCONFIG is not set
# CONFIG_BUSYBOX_DEFAULT_WGET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_LONG_OPTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_STATUSBAR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_FTP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_AUTHENTICATION is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_TIMEOUT is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_HTTPS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_WGET_OPENSSL is not set
# CONFIG_BUSYBOX_DEFAULT_WHOIS is not set
# CONFIG_BUSYBOX_DEFAULT_ZCIP is not set
# CONFIG_BUSYBOX_DEFAULT_UDHCPD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPD_BASE_IP_ON_MAC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPD_WRITE_LEASES_EARLY is not set
CONFIG_BUSYBOX_DEFAULT_DHCPD_LEASES_FILE=""
# CONFIG_BUSYBOX_DEFAULT_DUMPLEASES is not set
# CONFIG_BUSYBOX_DEFAULT_DHCPRELAY is not set
CONFIG_BUSYBOX_DEFAULT_UDHCPC=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPC_ARPING is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPC_SANITIZEOPT is not set
CONFIG_BUSYBOX_DEFAULT_UDHCPC_DEFAULT_SCRIPT="/usr/share/udhcpc/default.script"
# CONFIG_BUSYBOX_DEFAULT_UDHCPC6 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPC6_RFC3646 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPC6_RFC4704 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPC6_RFC4833 is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCPC6_RFC5970 is not set
CONFIG_BUSYBOX_DEFAULT_UDHCPC_DEFAULT_INTERFACE=""
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCP_PORT is not set
CONFIG_BUSYBOX_DEFAULT_UDHCP_DEBUG=0
CONFIG_BUSYBOX_DEFAULT_UDHCPC_SLACK_FOR_BUGGY_SERVERS=80
CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCP_RFC3397=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UDHCP_8021Q is not set
CONFIG_BUSYBOX_DEFAULT_IFUPDOWN_UDHCPC_CMD_OPTIONS=""
# CONFIG_BUSYBOX_DEFAULT_LPD is not set
# CONFIG_BUSYBOX_DEFAULT_LPR is not set
# CONFIG_BUSYBOX_DEFAULT_LPQ is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_MIME_CHARSET=""
# CONFIG_BUSYBOX_DEFAULT_MAKEMIME is not set
# CONFIG_BUSYBOX_DEFAULT_POPMAILDIR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_POPMAILDIR_DELIVERY is not set
# CONFIG_BUSYBOX_DEFAULT_REFORMIME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_REFORMIME_COMPAT is not set
# CONFIG_BUSYBOX_DEFAULT_SENDMAIL is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_FAST_TOP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SHOW_THREADS is not set
CONFIG_BUSYBOX_DEFAULT_FREE=y
# CONFIG_BUSYBOX_DEFAULT_FUSER is not set
# CONFIG_BUSYBOX_DEFAULT_IOSTAT is not set
CONFIG_BUSYBOX_DEFAULT_KILL=y
CONFIG_BUSYBOX_DEFAULT_KILLALL=y
# CONFIG_BUSYBOX_DEFAULT_KILLALL5 is not set
# CONFIG_BUSYBOX_DEFAULT_LSOF is not set
# CONFIG_BUSYBOX_DEFAULT_MPSTAT is not set
# CONFIG_BUSYBOX_DEFAULT_NMETER is not set
CONFIG_BUSYBOX_DEFAULT_PGREP=y
# CONFIG_BUSYBOX_DEFAULT_PKILL is not set
CONFIG_BUSYBOX_DEFAULT_PIDOF=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PIDOF_SINGLE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PIDOF_OMIT is not set
# CONFIG_BUSYBOX_DEFAULT_PMAP is not set
# CONFIG_BUSYBOX_DEFAULT_POWERTOP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_POWERTOP_INTERACTIVE is not set
CONFIG_BUSYBOX_DEFAULT_PS=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_PS_WIDE=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PS_LONG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PS_TIME is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PS_UNUSUAL_SYSTEMS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_PS_ADDITIONAL_COLUMNS is not set
# CONFIG_BUSYBOX_DEFAULT_PSTREE is not set
# CONFIG_BUSYBOX_DEFAULT_PWDX is not set
# CONFIG_BUSYBOX_DEFAULT_SMEMCAP is not set
CONFIG_BUSYBOX_DEFAULT_BB_SYSCTL=y
CONFIG_BUSYBOX_DEFAULT_TOP=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TOP_INTERACTIVE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_TOP_CPU_USAGE_PERCENTAGE=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_TOP_CPU_GLOBAL_PERCENTS=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TOP_SMP_CPU is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TOP_DECIMALS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TOP_SMP_PROCESS is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_TOPMEM is not set
CONFIG_BUSYBOX_DEFAULT_UPTIME=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_UPTIME_UTMP_SUPPORT is not set
# CONFIG_BUSYBOX_DEFAULT_WATCH is not set
# CONFIG_BUSYBOX_DEFAULT_CHPST is not set
# CONFIG_BUSYBOX_DEFAULT_SETUIDGID is not set
# CONFIG_BUSYBOX_DEFAULT_ENVUIDGID is not set
# CONFIG_BUSYBOX_DEFAULT_ENVDIR is not set
# CONFIG_BUSYBOX_DEFAULT_SOFTLIMIT is not set
# CONFIG_BUSYBOX_DEFAULT_RUNSV is not set
# CONFIG_BUSYBOX_DEFAULT_RUNSVDIR is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_RUNSVDIR_LOG is not set
# CONFIG_BUSYBOX_DEFAULT_SV is not set
CONFIG_BUSYBOX_DEFAULT_SV_DEFAULT_SERVICE_DIR=""
# CONFIG_BUSYBOX_DEFAULT_SVC is not set
# CONFIG_BUSYBOX_DEFAULT_SVOK is not set
# CONFIG_BUSYBOX_DEFAULT_SVLOGD is not set
# CONFIG_BUSYBOX_DEFAULT_CHCON is not set
# CONFIG_BUSYBOX_DEFAULT_GETENFORCE is not set
# CONFIG_BUSYBOX_DEFAULT_GETSEBOOL is not set
# CONFIG_BUSYBOX_DEFAULT_LOAD_POLICY is not set
# CONFIG_BUSYBOX_DEFAULT_MATCHPATHCON is not set
# CONFIG_BUSYBOX_DEFAULT_RUNCON is not set
# CONFIG_BUSYBOX_DEFAULT_SELINUXENABLED is not set
# CONFIG_BUSYBOX_DEFAULT_SESTATUS is not set
# CONFIG_BUSYBOX_DEFAULT_SETENFORCE is not set
# CONFIG_BUSYBOX_DEFAULT_SETFILES is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SETFILES_CHECK_OPTION is not set
# CONFIG_BUSYBOX_DEFAULT_RESTORECON is not set
# CONFIG_BUSYBOX_DEFAULT_SETSEBOOL is not set
CONFIG_BUSYBOX_DEFAULT_SH_IS_ASH=y
# CONFIG_BUSYBOX_DEFAULT_SH_IS_HUSH is not set
# CONFIG_BUSYBOX_DEFAULT_SH_IS_NONE is not set
# CONFIG_BUSYBOX_DEFAULT_BASH_IS_ASH is not set
# CONFIG_BUSYBOX_DEFAULT_BASH_IS_HUSH is not set
CONFIG_BUSYBOX_DEFAULT_BASH_IS_NONE=y
CONFIG_BUSYBOX_DEFAULT_SHELL_ASH=y
CONFIG_BUSYBOX_DEFAULT_ASH=y
# CONFIG_BUSYBOX_DEFAULT_ASH_OPTIMIZE_FOR_SIZE is not set
CONFIG_BUSYBOX_DEFAULT_ASH_INTERNAL_GLOB=y
CONFIG_BUSYBOX_DEFAULT_ASH_BASH_COMPAT=y
# CONFIG_BUSYBOX_DEFAULT_ASH_BASH_SOURCE_CURDIR is not set
# CONFIG_BUSYBOX_DEFAULT_ASH_BASH_NOT_FOUND_HOOK is not set
CONFIG_BUSYBOX_DEFAULT_ASH_JOB_CONTROL=y
CONFIG_BUSYBOX_DEFAULT_ASH_ALIAS=y
# CONFIG_BUSYBOX_DEFAULT_ASH_RANDOM_SUPPORT is not set
CONFIG_BUSYBOX_DEFAULT_ASH_EXPAND_PRMT=y
# CONFIG_BUSYBOX_DEFAULT_ASH_IDLE_TIMEOUT is not set
# CONFIG_BUSYBOX_DEFAULT_ASH_MAIL is not set
CONFIG_BUSYBOX_DEFAULT_ASH_ECHO=y
CONFIG_BUSYBOX_DEFAULT_ASH_PRINTF=y
CONFIG_BUSYBOX_DEFAULT_ASH_TEST=y
# CONFIG_BUSYBOX_DEFAULT_ASH_HELP is not set
CONFIG_BUSYBOX_DEFAULT_ASH_GETOPTS=y
CONFIG_BUSYBOX_DEFAULT_ASH_CMDCMD=y
# CONFIG_BUSYBOX_DEFAULT_CTTYHACK is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH is not set
# CONFIG_BUSYBOX_DEFAULT_SHELL_HUSH is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_BASH_COMPAT is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_BRACE_EXPANSION is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_BASH_SOURCE_CURDIR is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_LINENO_VAR is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_INTERACTIVE is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_SAVEHISTORY is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_JOB is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_TICK is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_IF is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_LOOPS is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_CASE is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_FUNCTIONS is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_LOCAL is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_RANDOM_SUPPORT is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_MODE_X is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_ECHO is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_PRINTF is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_TEST is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_HELP is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_EXPORT is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_EXPORT_N is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_READONLY is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_KILL is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_WAIT is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_COMMAND is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_TRAP is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_TYPE is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_TIMES is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_READ is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_SET is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_UNSET is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_ULIMIT is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_UMASK is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_GETOPTS is not set
# CONFIG_BUSYBOX_DEFAULT_HUSH_MEMLEAK is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_MATH=y
CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_MATH_64=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_MATH_BASE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_EXTRA_QUIET is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_STANDALONE is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_NOFORK=y
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_READ_FRAC is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_HISTFILESIZE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SH_EMBEDDED_SCRIPTS is not set
# CONFIG_BUSYBOX_DEFAULT_KLOGD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_KLOGD_KLOGCTL is not set
CONFIG_BUSYBOX_DEFAULT_LOGGER=y
# CONFIG_BUSYBOX_DEFAULT_LOGREAD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_LOGREAD_REDUCED_LOCKING is not set
# CONFIG_BUSYBOX_DEFAULT_SYSLOGD is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_ROTATE_LOGFILE is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_REMOTE_LOG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SYSLOGD_DUP is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SYSLOGD_CFG is not set
# CONFIG_BUSYBOX_DEFAULT_FEATURE_SYSLOGD_PRECISE_TIMESTAMPS is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_SYSLOGD_READ_BUFFER_SIZE=0
# CONFIG_BUSYBOX_DEFAULT_FEATURE_IPC_SYSLOG is not set
CONFIG_BUSYBOX_DEFAULT_FEATURE_IPC_SYSLOG_BUFFER_SIZE=0
# CONFIG_BUSYBOX_DEFAULT_FEATURE_KMSG_SYSLOG is not set
# CONFIG_PACKAGE_busybox-selinux is not set
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_ca-certificates=y
# CONFIG_PACKAGE_dnsmasq is not set
# CONFIG_PACKAGE_dnsmasq-dhcpv6 is not set
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_dnsmasq_full_dhcp=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_dnsmasq_full_dnssec=y
CONFIG_PACKAGE_dnsmasq_full_auth=y
CONFIG_PACKAGE_dnsmasq_full_ipset=y
CONFIG_PACKAGE_dnsmasq_full_conntrack=y
CONFIG_PACKAGE_dnsmasq_full_noid=y
# CONFIG_PACKAGE_dnsmasq_full_broken_rtc is not set
CONFIG_PACKAGE_dnsmasq_full_tftp=y
CONFIG_PACKAGE_dropbear=y

#
# Configuration
#
CONFIG_DROPBEAR_CURVE25519=y
# CONFIG_DROPBEAR_ECC is not set
CONFIG_DROPBEAR_ED25519=y
CONFIG_DROPBEAR_CHACHA20POLY1305=y
# CONFIG_DROPBEAR_ZLIB is not set
CONFIG_DROPBEAR_DBCLIENT=y
CONFIG_DROPBEAR_DBCLIENT_AGENTFORWARD=y
CONFIG_DROPBEAR_SCP=y
# CONFIG_DROPBEAR_ASKPASS is not set
CONFIG_DROPBEAR_AGENTFORWARD=y
# end of Configuration

# CONFIG_PACKAGE_ead is not set
# CONFIG_PACKAGE_firewall is not set
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_fstools=y
CONFIG_FSTOOLS_UBIFS_EXTROOT=y
# CONFIG_FSTOOLS_OVL_MOUNT_FULL_ACCESS_TIME is not set
# CONFIG_FSTOOLS_OVL_MOUNT_COMPRESS_ZLIB is not set
CONFIG_PACKAGE_fwtool=y
CONFIG_PACKAGE_getrandom=y
CONFIG_PACKAGE_jsonfilter=y
CONFIG_PACKAGE_libatomic=y
CONFIG_PACKAGE_libc=y
CONFIG_PACKAGE_libgcc=y
# CONFIG_PACKAGE_libgomp is not set
CONFIG_PACKAGE_libpthread=y
CONFIG_PACKAGE_librt=y
CONFIG_PACKAGE_libstdcpp=y
CONFIG_PACKAGE_logd=y
CONFIG_PACKAGE_mtd=y
CONFIG_PACKAGE_netifd=y
# CONFIG_PACKAGE_nft-qos is not set
# CONFIG_PACKAGE_nvram is not set
CONFIG_PACKAGE_openwrt-keyring=y
CONFIG_PACKAGE_opkg=y
CONFIG_PACKAGE_procd=y

#
# Configuration
#
# CONFIG_PROCD_SHOW_BOOT is not set
# end of Configuration

CONFIG_PACKAGE_procd-seccomp=y
# CONFIG_PACKAGE_procd-selinux is not set
CONFIG_PACKAGE_procd-ujail=y
CONFIG_PACKAGE_qos-scripts=y
# CONFIG_PACKAGE_refpolicy is not set
CONFIG_PACKAGE_resolveip=y
CONFIG_PACKAGE_rpcd=y
CONFIG_PACKAGE_rpcd-mod-file=y
CONFIG_PACKAGE_rpcd-mod-iwinfo=y
# CONFIG_PACKAGE_rpcd-mod-rpcsys is not set
# CONFIG_PACKAGE_rpcd-mod-ucode is not set
# CONFIG_PACKAGE_selinux-policy is not set
# CONFIG_PACKAGE_snapshot-tool is not set
CONFIG_PACKAGE_sqm-scripts=y
# CONFIG_PACKAGE_sqm-scripts-extra is not set
# CONFIG_PACKAGE_swconfig is not set
CONFIG_PACKAGE_ubox=y
CONFIG_PACKAGE_ubus=y
CONFIG_PACKAGE_ubusd=y
# CONFIG_PACKAGE_ucert is not set
# CONFIG_PACKAGE_ucert-full is not set
CONFIG_PACKAGE_uci=y
# CONFIG_PACKAGE_uencrypt is not set
CONFIG_PACKAGE_urandom-seed=y
CONFIG_PACKAGE_urngd=y
CONFIG_PACKAGE_usign=y
# CONFIG_PACKAGE_uxc is not set
CONFIG_PACKAGE_wireless-tools=y
# CONFIG_PACKAGE_zram-swap is not set
# CONFIG_PACKAGE_zyxel-bootconfig is not set
# end of Base system

#
# Administration
#

#
# Zabbix
#
# CONFIG_PACKAGE_zabbix-agentd is not set

#
# SSL support
#
# CONFIG_ZABBIX_OPENSSL is not set
# CONFIG_ZABBIX_GNUTLS is not set
CONFIG_ZABBIX_NOSSL=y
# CONFIG_PACKAGE_zabbix-extra-mac80211 is not set
# CONFIG_PACKAGE_zabbix-extra-network is not set
# CONFIG_PACKAGE_zabbix-extra-wifi is not set
# CONFIG_PACKAGE_zabbix-get is not set
# CONFIG_PACKAGE_zabbix-proxy is not set
# CONFIG_PACKAGE_zabbix-sender is not set
# CONFIG_PACKAGE_zabbix-server is not set

#
# Database Software
#
# CONFIG_ZABBIX_MYSQL is not set
CONFIG_ZABBIX_POSTGRESQL=y
# CONFIG_PACKAGE_zabbix-server-frontend is not set
# end of Zabbix

#
# openwisp
#
# CONFIG_PACKAGE_netjson-monitoring is not set
# CONFIG_PACKAGE_openwisp-config is not set
# CONFIG_PACKAGE_openwisp-monitoring is not set
# end of openwisp

# CONFIG_PACKAGE_atop is not set
# CONFIG_PACKAGE_backuppc is not set
# CONFIG_PACKAGE_debian-archive-keyring is not set
# CONFIG_PACKAGE_debootstrap is not set
# CONFIG_PACKAGE_gkrellmd is not set
# CONFIG_PACKAGE_htop is not set
# CONFIG_PACKAGE_ipmitool is not set
# CONFIG_PACKAGE_monit is not set
# CONFIG_PACKAGE_monit-nossl is not set
# CONFIG_PACKAGE_muninlite is not set
# CONFIG_PACKAGE_netatop is not set
# CONFIG_PACKAGE_netdata is not set
# CONFIG_PACKAGE_nyx is not set
# CONFIG_PACKAGE_rsyslog is not set
# CONFIG_PACKAGE_schroot is not set

#
# Configuration
#
# CONFIG_SCHROOT_BTRFS is not set
# CONFIG_SCHROOT_LOOPBACK is not set
# CONFIG_SCHROOT_LVM is not set
# CONFIG_SCHROOT_UUID is not set
# end of Configuration

# CONFIG_PACKAGE_sudo is not set
# CONFIG_PACKAGE_syslog-ng is not set
# end of Administration

#
# Boot Loaders
#
# CONFIG_PACKAGE_u-boot-mt7621_nand_rfb is not set
# CONFIG_PACKAGE_u-boot-mt7621_rfb is not set
# end of Boot Loaders

#
# Development
#

#
# Libraries
#
# CONFIG_PACKAGE_libncurses-dev is not set
# CONFIG_PACKAGE_libxml2-dev is not set
# CONFIG_PACKAGE_zlib-dev is not set
# end of Libraries

# CONFIG_PACKAGE_ar is not set
# CONFIG_PACKAGE_autoconf is not set
# CONFIG_PACKAGE_automake is not set
# CONFIG_PACKAGE_binutils is not set
# CONFIG_PACKAGE_bison is not set
# CONFIG_PACKAGE_diffutils is not set
# CONFIG_PACKAGE_flex is not set
# CONFIG_PACKAGE_gcc is not set
# CONFIG_PACKAGE_gdb is not set
# CONFIG_PACKAGE_gdbserver is not set
# CONFIG_PACKAGE_gitlab-runner is not set
# CONFIG_PACKAGE_libtool-bin is not set
# CONFIG_PACKAGE_lpc21isp is not set
# CONFIG_PACKAGE_lttng-tools is not set
# CONFIG_PACKAGE_m4 is not set
# CONFIG_PACKAGE_make is not set
# CONFIG_PACKAGE_mt76-test is not set
# CONFIG_PACKAGE_objdump is not set
# CONFIG_PACKAGE_packr is not set
# CONFIG_PACKAGE_patch is not set
# CONFIG_PACKAGE_pkg-config is not set
# CONFIG_PACKAGE_pkgconf is not set
# CONFIG_PACKAGE_trace-cmd is not set
# CONFIG_PACKAGE_trace-cmd-extra is not set
# CONFIG_PACKAGE_valgrind is not set
# end of Development

#
# Extra packages
#
# CONFIG_PACKAGE_jose is not set
CONFIG_PACKAGE_libiwinfo-data=y
CONFIG_PACKAGE_nginx=m
# CONFIG_PACKAGE_nginx-mod-luci-ssl is not set
CONFIG_PACKAGE_nginx-util=m
# CONFIG_PACKAGE_tang is not set
# end of Extra packages

#
# Firmware
#

#
# ath10k Board-Specific Overrides
#
# end of ath10k Board-Specific Overrides

# CONFIG_PACKAGE_aircard-pcmcia-firmware is not set
# CONFIG_PACKAGE_amdgpu-firmware is not set
# CONFIG_PACKAGE_ar3k-firmware is not set
# CONFIG_PACKAGE_ath10k-board-qca4019 is not set
# CONFIG_PACKAGE_ath10k-board-qca9377 is not set
# CONFIG_PACKAGE_ath10k-board-qca9887 is not set
# CONFIG_PACKAGE_ath10k-board-qca9888 is not set
# CONFIG_PACKAGE_ath10k-board-qca988x is not set
# CONFIG_PACKAGE_ath10k-board-qca9984 is not set
# CONFIG_PACKAGE_ath10k-board-qca99x0 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca4019 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca4019-ct is not set
# CONFIG_PACKAGE_ath10k-firmware-qca4019-ct-full-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca4019-ct-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca6174 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9377 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9887 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9887-ct is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9887-ct-full-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9888 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9888-ct is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9888-ct-full-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9888-ct-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca988x is not set
# CONFIG_PACKAGE_ath10k-firmware-qca988x-ct is not set
# CONFIG_PACKAGE_ath10k-firmware-qca988x-ct-full-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9984 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9984-ct is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9984-ct-full-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca9984-ct-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca99x0 is not set
# CONFIG_PACKAGE_ath10k-firmware-qca99x0-ct is not set
# CONFIG_PACKAGE_ath10k-firmware-qca99x0-ct-full-htt is not set
# CONFIG_PACKAGE_ath10k-firmware-qca99x0-ct-htt is not set
# CONFIG_PACKAGE_ath6k-firmware is not set
# CONFIG_PACKAGE_ath9k-htc-firmware is not set
# CONFIG_PACKAGE_b43legacy-firmware is not set
# CONFIG_PACKAGE_bnx2-firmware is not set
# CONFIG_PACKAGE_bnx2x-firmware is not set
# CONFIG_PACKAGE_brcmfmac-firmware-4329-sdio is not set
# CONFIG_PACKAGE_brcmfmac-firmware-43430-sdio-rpi-3b is not set
# CONFIG_PACKAGE_brcmfmac-firmware-43430-sdio-rpi-zero-w is not set
# CONFIG_PACKAGE_brcmfmac-firmware-43430a0-sdio is not set
# CONFIG_PACKAGE_brcmfmac-firmware-43455-sdio-rpi-3b-plus is not set
# CONFIG_PACKAGE_brcmfmac-firmware-43455-sdio-rpi-4b is not set
# CONFIG_PACKAGE_brcmfmac-firmware-43602a1-pcie is not set
# CONFIG_PACKAGE_brcmfmac-firmware-4366b1-pcie is not set
# CONFIG_PACKAGE_brcmfmac-firmware-4366c0-pcie is not set
# CONFIG_PACKAGE_brcmfmac-firmware-usb is not set
# CONFIG_PACKAGE_brcmsmac-firmware is not set
# CONFIG_PACKAGE_carl9170-firmware is not set
# CONFIG_PACKAGE_cypress-firmware-43012-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-43340-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-43362-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-4339-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-43430-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-43455-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-4354-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-4356-pcie is not set
# CONFIG_PACKAGE_cypress-firmware-4356-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-43570-pcie is not set
# CONFIG_PACKAGE_cypress-firmware-4373-sdio is not set
# CONFIG_PACKAGE_cypress-firmware-4373-usb is not set
# CONFIG_PACKAGE_cypress-firmware-54591-pcie is not set
# CONFIG_PACKAGE_e100-firmware is not set
# CONFIG_PACKAGE_edgeport-firmware is not set
# CONFIG_PACKAGE_eip197-mini-firmware is not set
# CONFIG_PACKAGE_ibt-firmware is not set
# CONFIG_PACKAGE_iwl3945-firmware is not set
# CONFIG_PACKAGE_iwl4965-firmware is not set
# CONFIG_PACKAGE_iwlwifi-firmware-ax200 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-ax210 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl100 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl1000 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl105 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl135 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl2000 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl2030 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl3160 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl3168 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl5000 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl5150 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl6000g2 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl6000g2a is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl6000g2b is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl6050 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl7260 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl7265 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl7265d is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl8260c is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl8265 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl9000 is not set
# CONFIG_PACKAGE_iwlwifi-firmware-iwl9260 is not set
# CONFIG_PACKAGE_jboot-tools is not set
# CONFIG_PACKAGE_libertas-sdio-firmware is not set
# CONFIG_PACKAGE_libertas-spi-firmware is not set
# CONFIG_PACKAGE_libertas-usb-firmware is not set
# CONFIG_PACKAGE_mt7601u-firmware is not set
# CONFIG_PACKAGE_mt7622bt-firmware is not set
# CONFIG_PACKAGE_mwifiex-pcie-firmware is not set
# CONFIG_PACKAGE_mwifiex-sdio-firmware is not set
# CONFIG_PACKAGE_mwl8k-firmware is not set
# CONFIG_PACKAGE_p54-pci-firmware is not set
# CONFIG_PACKAGE_p54-spi-firmware is not set
# CONFIG_PACKAGE_p54-usb-firmware is not set
# CONFIG_PACKAGE_r8152-firmware is not set
# CONFIG_PACKAGE_r8169-firmware is not set
# CONFIG_PACKAGE_radeon-firmware is not set
# CONFIG_PACKAGE_rs9113-firmware is not set
# CONFIG_PACKAGE_rt2800-pci-firmware is not set
# CONFIG_PACKAGE_rt2800-usb-firmware is not set
# CONFIG_PACKAGE_rt61-pci-firmware is not set
# CONFIG_PACKAGE_rt73-usb-firmware is not set
# CONFIG_PACKAGE_rtl8188eu-firmware is not set
# CONFIG_PACKAGE_rtl8192ce-firmware is not set
# CONFIG_PACKAGE_rtl8192cu-firmware is not set
# CONFIG_PACKAGE_rtl8192de-firmware is not set
# CONFIG_PACKAGE_rtl8192eu-firmware is not set
# CONFIG_PACKAGE_rtl8192se-firmware is not set
# CONFIG_PACKAGE_rtl8192su-firmware is not set
# CONFIG_PACKAGE_rtl8723au-firmware is not set
# CONFIG_PACKAGE_rtl8723bu-firmware is not set
# CONFIG_PACKAGE_rtl8821ae-firmware is not set
# CONFIG_PACKAGE_rtl8822be-firmware is not set
# CONFIG_PACKAGE_rtl8822ce-firmware is not set
# CONFIG_PACKAGE_ti-3410-firmware is not set
# CONFIG_PACKAGE_ti-5052-firmware is not set
# CONFIG_PACKAGE_wil6210-firmware is not set
CONFIG_PACKAGE_wireless-regdb=y
# CONFIG_PACKAGE_wl12xx-firmware is not set
# CONFIG_PACKAGE_wl18xx-firmware is not set
# end of Firmware

#
# Fonts
#

#
# DejaVu
#
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuMathTeXGyre is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSans is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSans-Bold is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSans-BoldOblique is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSans-ExtraLight is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSans-Oblique is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansCondensed is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansCondensed-Bold is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansCondensed-BoldOblique is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansCondensed-Oblique is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansMono is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansMono-Bold is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansMono-BoldOblique is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSansMono-Oblique is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerif is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerif-Bold is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerif-BoldItalic is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerif-Italic is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerifCondensed is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerifCondensed-Bold is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerifCondensed-BoldItalic is not set
# CONFIG_PACKAGE_dejavu-fonts-ttf-DejaVuSerifCondensed-Italic is not set
# end of DejaVu
# end of Fonts

#
# Kernel
#

#
# Kernel modules
#

#
# Block Devices
#
# CONFIG_PACKAGE_kmod-aoe is not set
# CONFIG_PACKAGE_kmod-ata-ahci is not set
# CONFIG_PACKAGE_kmod-ata-artop is not set
# CONFIG_PACKAGE_kmod-ata-core is not set
# CONFIG_PACKAGE_kmod-ata-marvell-sata is not set
# CONFIG_PACKAGE_kmod-ata-nvidia-sata is not set
# CONFIG_PACKAGE_kmod-ata-pdc202xx-old is not set
# CONFIG_PACKAGE_kmod-ata-piix is not set
# CONFIG_PACKAGE_kmod-ata-sil is not set
# CONFIG_PACKAGE_kmod-ata-sil24 is not set
# CONFIG_PACKAGE_kmod-ata-via-sata is not set
# CONFIG_PACKAGE_kmod-block2mtd is not set
# CONFIG_PACKAGE_kmod-dax is not set
# CONFIG_PACKAGE_kmod-dm is not set
# CONFIG_PACKAGE_kmod-dm-raid is not set
# CONFIG_PACKAGE_kmod-iosched-bfq is not set
# CONFIG_PACKAGE_kmod-iscsi-initiator is not set
# CONFIG_PACKAGE_kmod-loop is not set
# CONFIG_PACKAGE_kmod-md-mod is not set
# CONFIG_PACKAGE_kmod-nbd is not set
# CONFIG_PACKAGE_kmod-scsi-cdrom is not set
# CONFIG_PACKAGE_kmod-scsi-core is not set
# CONFIG_PACKAGE_kmod-scsi-generic is not set
# CONFIG_PACKAGE_kmod-scsi-tape is not set
# end of Block Devices

#
# CAN Support
#
# CONFIG_PACKAGE_kmod-can is not set
# end of CAN Support

#
# Cryptographic API modules
#
CONFIG_PACKAGE_kmod-crypto-acompress=y
CONFIG_PACKAGE_kmod-crypto-aead=y
# CONFIG_PACKAGE_kmod-crypto-arc4 is not set
# CONFIG_PACKAGE_kmod-crypto-authenc is not set
# CONFIG_PACKAGE_kmod-crypto-cbc is not set
CONFIG_PACKAGE_kmod-crypto-ccm=y
# CONFIG_PACKAGE_kmod-crypto-chacha20poly1305 is not set
CONFIG_PACKAGE_kmod-crypto-cmac=y
CONFIG_PACKAGE_kmod-crypto-crc32c=y
CONFIG_PACKAGE_kmod-crypto-ctr=y
# CONFIG_PACKAGE_kmod-crypto-cts is not set
# CONFIG_PACKAGE_kmod-crypto-deflate is not set
# CONFIG_PACKAGE_kmod-crypto-des is not set
# CONFIG_PACKAGE_kmod-crypto-ecb is not set
# CONFIG_PACKAGE_kmod-crypto-ecdh is not set
# CONFIG_PACKAGE_kmod-crypto-echainiv is not set
# CONFIG_PACKAGE_kmod-crypto-fcrypt is not set
CONFIG_PACKAGE_kmod-crypto-gcm=y
CONFIG_PACKAGE_kmod-crypto-gf128=y
CONFIG_PACKAGE_kmod-crypto-ghash=y
CONFIG_PACKAGE_kmod-crypto-hash=y
CONFIG_PACKAGE_kmod-crypto-hmac=y
# CONFIG_PACKAGE_kmod-crypto-hw-hifn-795x is not set
# CONFIG_PACKAGE_kmod-crypto-hw-padlock is not set
# CONFIG_PACKAGE_kmod-crypto-kpp is not set
CONFIG_PACKAGE_kmod-crypto-manager=y
# CONFIG_PACKAGE_kmod-crypto-md4 is not set
# CONFIG_PACKAGE_kmod-crypto-md5 is not set
# CONFIG_PACKAGE_kmod-crypto-michael-mic is not set
# CONFIG_PACKAGE_kmod-crypto-misc is not set
CONFIG_PACKAGE_kmod-crypto-null=y
# CONFIG_PACKAGE_kmod-crypto-pcbc is not set
# CONFIG_PACKAGE_kmod-crypto-rmd160 is not set
CONFIG_PACKAGE_kmod-crypto-rng=y
CONFIG_PACKAGE_kmod-crypto-seqiv=y
# CONFIG_PACKAGE_kmod-crypto-sha1 is not set
CONFIG_PACKAGE_kmod-crypto-sha256=y
# CONFIG_PACKAGE_kmod-crypto-sha512 is not set
# CONFIG_PACKAGE_kmod-crypto-test is not set
# CONFIG_PACKAGE_kmod-crypto-user is not set
# CONFIG_PACKAGE_kmod-crypto-xcbc is not set
# CONFIG_PACKAGE_kmod-crypto-xts is not set
# CONFIG_PACKAGE_kmod-cryptodev is not set
# end of Cryptographic API modules

#
# Filesystems
#
# CONFIG_PACKAGE_kmod-fs-antfs is not set
# CONFIG_PACKAGE_kmod-fs-autofs4 is not set
# CONFIG_PACKAGE_kmod-fs-btrfs is not set
# CONFIG_PACKAGE_kmod-fs-cifs is not set
# CONFIG_PACKAGE_kmod-fs-configfs is not set
# CONFIG_PACKAGE_kmod-fs-cramfs is not set
# CONFIG_PACKAGE_kmod-fs-exfat is not set
# CONFIG_PACKAGE_kmod-fs-exportfs is not set
CONFIG_PACKAGE_kmod-fs-ext4=y
# CONFIG_PACKAGE_kmod-fs-f2fs is not set
# CONFIG_PACKAGE_kmod-fs-hfs is not set
# CONFIG_PACKAGE_kmod-fs-hfsplus is not set
# CONFIG_PACKAGE_kmod-fs-isofs is not set
# CONFIG_PACKAGE_kmod-fs-jfs is not set
# CONFIG_PACKAGE_kmod-fs-ksmbd is not set
# CONFIG_PACKAGE_kmod-fs-minix is not set
# CONFIG_PACKAGE_kmod-fs-msdos is not set
# CONFIG_PACKAGE_kmod-fs-nfs is not set
# CONFIG_PACKAGE_kmod-fs-nfs-common is not set
# CONFIG_PACKAGE_kmod-fs-nfs-common-rpcsec is not set
# CONFIG_PACKAGE_kmod-fs-nfs-v3 is not set
# CONFIG_PACKAGE_kmod-fs-nfs-v4 is not set
# CONFIG_PACKAGE_kmod-fs-nfsd is not set
# CONFIG_PACKAGE_kmod-fs-ntfs is not set
# CONFIG_PACKAGE_kmod-fs-ntfs3 is not set
# CONFIG_PACKAGE_kmod-fs-reiserfs is not set
# CONFIG_PACKAGE_kmod-fs-squashfs is not set
# CONFIG_PACKAGE_kmod-fs-udf is not set
# CONFIG_PACKAGE_kmod-fs-vfat is not set
# CONFIG_PACKAGE_kmod-fs-xfs is not set
# CONFIG_PACKAGE_kmod-fuse is not set
# CONFIG_PACKAGE_kmod-pstore is not set
# end of Filesystems

#
# FireWire support
#
# CONFIG_PACKAGE_kmod-firewire is not set
# end of FireWire support

#
# GPIO support
#
# CONFIG_PACKAGE_kmod-gpio-cascade is not set
# end of GPIO support

#
# Hardware Monitoring Support
#
# CONFIG_PACKAGE_kmod-gl-mifi-mcu is not set
# CONFIG_PACKAGE_kmod-hwmon-ad7418 is not set
# CONFIG_PACKAGE_kmod-hwmon-adcxx is not set
# CONFIG_PACKAGE_kmod-hwmon-adt7410 is not set
# CONFIG_PACKAGE_kmod-hwmon-adt7475 is not set
CONFIG_PACKAGE_kmod-hwmon-core=y
# CONFIG_PACKAGE_kmod-hwmon-dme1737 is not set
# CONFIG_PACKAGE_kmod-hwmon-drivetemp is not set
# CONFIG_PACKAGE_kmod-hwmon-g762 is not set
# CONFIG_PACKAGE_kmod-hwmon-gpiofan is not set
# CONFIG_PACKAGE_kmod-hwmon-ina209 is not set
# CONFIG_PACKAGE_kmod-hwmon-ina2xx is not set
# CONFIG_PACKAGE_kmod-hwmon-it87 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm63 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm70 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm75 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm77 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm85 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm90 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm92 is not set
# CONFIG_PACKAGE_kmod-hwmon-lm95241 is not set
# CONFIG_PACKAGE_kmod-hwmon-ltc4151 is not set
# CONFIG_PACKAGE_kmod-hwmon-mcp3021 is not set
# CONFIG_PACKAGE_kmod-hwmon-nct7802 is not set
# CONFIG_PACKAGE_kmod-hwmon-pwmfan is not set
# CONFIG_PACKAGE_kmod-hwmon-sch5627 is not set
# CONFIG_PACKAGE_kmod-hwmon-sht21 is not set
# CONFIG_PACKAGE_kmod-hwmon-tmp102 is not set
# CONFIG_PACKAGE_kmod-hwmon-tmp103 is not set
# CONFIG_PACKAGE_kmod-hwmon-tmp421 is not set
# CONFIG_PACKAGE_kmod-hwmon-vid is not set
# CONFIG_PACKAGE_kmod-hwmon-w83793 is not set
# CONFIG_PACKAGE_kmod-pmbus-core is not set
# CONFIG_PACKAGE_kmod-pmbus-zl6100 is not set
# end of Hardware Monitoring Support

#
# I2C support
#
# CONFIG_PACKAGE_kmod-i2c-algo-bit is not set
# CONFIG_PACKAGE_kmod-i2c-algo-pca is not set
# CONFIG_PACKAGE_kmod-i2c-algo-pcf is not set
# CONFIG_PACKAGE_kmod-i2c-core is not set
# CONFIG_PACKAGE_kmod-i2c-designware-pci is not set
# CONFIG_PACKAGE_kmod-i2c-gpio is not set
# CONFIG_PACKAGE_kmod-i2c-mux is not set
# CONFIG_PACKAGE_kmod-i2c-mux-gpio is not set
# CONFIG_PACKAGE_kmod-i2c-mux-pca9541 is not set
# CONFIG_PACKAGE_kmod-i2c-mux-pca954x is not set
# CONFIG_PACKAGE_kmod-i2c-pxa is not set
# CONFIG_PACKAGE_kmod-i2c-smbus is not set
# CONFIG_PACKAGE_kmod-i2c-tiny-usb is not set
# end of I2C support

#
# Industrial I/O Modules
#
# CONFIG_PACKAGE_kmod-iio-ad799x is not set
# CONFIG_PACKAGE_kmod-iio-ads1015 is not set
# CONFIG_PACKAGE_kmod-iio-am2315 is not set
# CONFIG_PACKAGE_kmod-iio-bh1750 is not set
# CONFIG_PACKAGE_kmod-iio-bme680 is not set
# CONFIG_PACKAGE_kmod-iio-bme680-i2c is not set
# CONFIG_PACKAGE_kmod-iio-bme680-spi is not set
# CONFIG_PACKAGE_kmod-iio-bmp280 is not set
# CONFIG_PACKAGE_kmod-iio-bmp280-i2c is not set
# CONFIG_PACKAGE_kmod-iio-bmp280-spi is not set
# CONFIG_PACKAGE_kmod-iio-ccs811 is not set
# CONFIG_PACKAGE_kmod-iio-core is not set
# CONFIG_PACKAGE_kmod-iio-dht11 is not set
# CONFIG_PACKAGE_kmod-iio-fxas21002c is not set
# CONFIG_PACKAGE_kmod-iio-fxas21002c-i2c is not set
# CONFIG_PACKAGE_kmod-iio-fxas21002c-spi is not set
# CONFIG_PACKAGE_kmod-iio-fxos8700 is not set
# CONFIG_PACKAGE_kmod-iio-fxos8700-i2c is not set
# CONFIG_PACKAGE_kmod-iio-fxos8700-spi is not set
# CONFIG_PACKAGE_kmod-iio-hmc5843 is not set
# CONFIG_PACKAGE_kmod-iio-htu21 is not set
# CONFIG_PACKAGE_kmod-iio-kfifo-buf is not set
# CONFIG_PACKAGE_kmod-iio-lsm6dsx is not set
# CONFIG_PACKAGE_kmod-iio-lsm6dsx-i2c is not set
# CONFIG_PACKAGE_kmod-iio-lsm6dsx-spi is not set
# CONFIG_PACKAGE_kmod-iio-si7020 is not set
# CONFIG_PACKAGE_kmod-iio-sps30 is not set
# CONFIG_PACKAGE_kmod-iio-st_accel is not set
# CONFIG_PACKAGE_kmod-iio-st_accel-i2c is not set
# CONFIG_PACKAGE_kmod-iio-st_accel-spi is not set
# CONFIG_PACKAGE_kmod-iio-tsl4531 is not set
# CONFIG_PACKAGE_kmod-industrialio-triggered-buffer is not set
# end of Industrial I/O Modules

#
# Input modules
#
# CONFIG_PACKAGE_kmod-hid is not set
# CONFIG_PACKAGE_kmod-hid-generic is not set
# CONFIG_PACKAGE_kmod-input-core is not set
# CONFIG_PACKAGE_kmod-input-evdev is not set
# CONFIG_PACKAGE_kmod-input-gpio-encoder is not set
# CONFIG_PACKAGE_kmod-input-gpio-keys is not set
# CONFIG_PACKAGE_kmod-input-gpio-keys-polled is not set
# CONFIG_PACKAGE_kmod-input-joydev is not set
# CONFIG_PACKAGE_kmod-input-matrixkmap is not set
# CONFIG_PACKAGE_kmod-input-polldev is not set
# CONFIG_PACKAGE_kmod-input-touchscreen-ads7846 is not set
# CONFIG_PACKAGE_kmod-input-touchscreen-edt-ft5x06 is not set
# CONFIG_PACKAGE_kmod-input-uinput is not set
# end of Input modules

#
# LED modules
#
# CONFIG_PACKAGE_kmod-input-leds is not set
CONFIG_PACKAGE_kmod-leds-gpio=y
# CONFIG_PACKAGE_kmod-leds-pca955x is not set
# CONFIG_PACKAGE_kmod-leds-pca963x is not set
# CONFIG_PACKAGE_kmod-leds-tlc591xx is not set
# CONFIG_PACKAGE_kmod-leds-uleds is not set
# CONFIG_PACKAGE_kmod-ledtrig-activity is not set
# CONFIG_PACKAGE_kmod-ledtrig-audio is not set
# CONFIG_PACKAGE_kmod-ledtrig-gpio is not set
# CONFIG_PACKAGE_kmod-ledtrig-oneshot is not set
# CONFIG_PACKAGE_kmod-ledtrig-pattern is not set
# CONFIG_PACKAGE_kmod-ledtrig-transient is not set
# end of LED modules

#
# Libraries
#
# CONFIG_PACKAGE_kmod-lib-cordic is not set
CONFIG_PACKAGE_kmod-lib-crc-ccitt=y
# CONFIG_PACKAGE_kmod-lib-crc-itu-t is not set
CONFIG_PACKAGE_kmod-lib-crc16=y
CONFIG_PACKAGE_kmod-lib-crc32c=y
# CONFIG_PACKAGE_kmod-lib-crc7 is not set
# CONFIG_PACKAGE_kmod-lib-crc8 is not set
# CONFIG_PACKAGE_kmod-lib-lz4 is not set
CONFIG_PACKAGE_kmod-lib-lzo=y
# CONFIG_PACKAGE_kmod-lib-textsearch is not set
# CONFIG_PACKAGE_kmod-lib-zstd is not set
# CONFIG_PACKAGE_kmod-oid-registry is not set
# end of Libraries

#
# Multiplexer Support
#
# CONFIG_PACKAGE_kmod-mux-core is not set
# end of Multiplexer Support

#
# Native Language Support
#
CONFIG_PACKAGE_kmod-nls-base=y
# CONFIG_PACKAGE_kmod-nls-cp1250 is not set
# CONFIG_PACKAGE_kmod-nls-cp1251 is not set
# CONFIG_PACKAGE_kmod-nls-cp437 is not set
# CONFIG_PACKAGE_kmod-nls-cp775 is not set
# CONFIG_PACKAGE_kmod-nls-cp850 is not set
# CONFIG_PACKAGE_kmod-nls-cp852 is not set
# CONFIG_PACKAGE_kmod-nls-cp862 is not set
# CONFIG_PACKAGE_kmod-nls-cp864 is not set
# CONFIG_PACKAGE_kmod-nls-cp866 is not set
# CONFIG_PACKAGE_kmod-nls-cp932 is not set
# CONFIG_PACKAGE_kmod-nls-cp936 is not set
# CONFIG_PACKAGE_kmod-nls-cp950 is not set
# CONFIG_PACKAGE_kmod-nls-iso8859-1 is not set
# CONFIG_PACKAGE_kmod-nls-iso8859-13 is not set
# CONFIG_PACKAGE_kmod-nls-iso8859-15 is not set
# CONFIG_PACKAGE_kmod-nls-iso8859-2 is not set
# CONFIG_PACKAGE_kmod-nls-iso8859-6 is not set
# CONFIG_PACKAGE_kmod-nls-iso8859-8 is not set
# CONFIG_PACKAGE_kmod-nls-koi8r is not set
# CONFIG_PACKAGE_kmod-nls-utf8 is not set
# end of Native Language Support

#
# Netfilter Extensions
#
# CONFIG_PACKAGE_kmod-arptables is not set
# CONFIG_PACKAGE_kmod-br-netfilter is not set
# CONFIG_PACKAGE_kmod-ebtables is not set
# CONFIG_PACKAGE_kmod-ebtables-ipv4 is not set
# CONFIG_PACKAGE_kmod-ebtables-ipv6 is not set
# CONFIG_PACKAGE_kmod-ebtables-watchers is not set
# CONFIG_PACKAGE_kmod-ip6tables is not set
# CONFIG_PACKAGE_kmod-ip6tables-extra is not set
# CONFIG_PACKAGE_kmod-ipt-account is not set
# CONFIG_PACKAGE_kmod-ipt-chaos is not set
# CONFIG_PACKAGE_kmod-ipt-checksum is not set
# CONFIG_PACKAGE_kmod-ipt-cluster is not set
# CONFIG_PACKAGE_kmod-ipt-clusterip is not set
# CONFIG_PACKAGE_kmod-ipt-compat-xtables is not set
# CONFIG_PACKAGE_kmod-ipt-condition is not set
CONFIG_PACKAGE_kmod-ipt-conntrack=y
CONFIG_PACKAGE_kmod-ipt-conntrack-extra=y
# CONFIG_PACKAGE_kmod-ipt-conntrack-label is not set
# CONFIG_PACKAGE_kmod-ipt-coova is not set
CONFIG_PACKAGE_kmod-ipt-core=y
# CONFIG_PACKAGE_kmod-ipt-debug is not set
# CONFIG_PACKAGE_kmod-ipt-delude is not set
# CONFIG_PACKAGE_kmod-ipt-dhcpmac is not set
# CONFIG_PACKAGE_kmod-ipt-dnetmap is not set
CONFIG_PACKAGE_kmod-ipt-extra=y
# CONFIG_PACKAGE_kmod-ipt-filter is not set
# CONFIG_PACKAGE_kmod-ipt-fuzzy is not set
# CONFIG_PACKAGE_kmod-ipt-geoip is not set
# CONFIG_PACKAGE_kmod-ipt-hashlimit is not set
# CONFIG_PACKAGE_kmod-ipt-iface is not set
# CONFIG_PACKAGE_kmod-ipt-ipmark is not set
CONFIG_PACKAGE_kmod-ipt-ipopt=y
# CONFIG_PACKAGE_kmod-ipt-ipp2p is not set
# CONFIG_PACKAGE_kmod-ipt-iprange is not set
# CONFIG_PACKAGE_kmod-ipt-ipsec is not set
CONFIG_PACKAGE_kmod-ipt-ipset=y
# CONFIG_PACKAGE_kmod-ipt-ipv4options is not set
# CONFIG_PACKAGE_kmod-ipt-led is not set
# CONFIG_PACKAGE_kmod-ipt-length2 is not set
# CONFIG_PACKAGE_kmod-ipt-logmark is not set
# CONFIG_PACKAGE_kmod-ipt-lscan is not set
# CONFIG_PACKAGE_kmod-ipt-lua is not set
CONFIG_PACKAGE_kmod-ipt-nat=y
# CONFIG_PACKAGE_kmod-ipt-nat-extra is not set
# CONFIG_PACKAGE_kmod-ipt-nat6 is not set
# CONFIG_PACKAGE_kmod-ipt-nathelper-rtsp is not set
# CONFIG_PACKAGE_kmod-ipt-nflog is not set
# CONFIG_PACKAGE_kmod-ipt-nfqueue is not set
# CONFIG_PACKAGE_kmod-ipt-offload is not set
# CONFIG_PACKAGE_kmod-ipt-physdev is not set
# CONFIG_PACKAGE_kmod-ipt-proto is not set
# CONFIG_PACKAGE_kmod-ipt-psd is not set
# CONFIG_PACKAGE_kmod-ipt-quota2 is not set
CONFIG_PACKAGE_kmod-ipt-raw=y
# CONFIG_PACKAGE_kmod-ipt-raw6 is not set
# CONFIG_PACKAGE_kmod-ipt-rpfilter is not set
# CONFIG_PACKAGE_kmod-ipt-rtpengine is not set
# CONFIG_PACKAGE_kmod-ipt-socket is not set
# CONFIG_PACKAGE_kmod-ipt-sysrq is not set
# CONFIG_PACKAGE_kmod-ipt-tarpit is not set
# CONFIG_PACKAGE_kmod-ipt-tee is not set
CONFIG_PACKAGE_kmod-ipt-tproxy=y
# CONFIG_PACKAGE_kmod-ipt-u32 is not set
# CONFIG_PACKAGE_kmod-ipt-ulog is not set
# CONFIG_PACKAGE_kmod-netatop is not set
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y
CONFIG_PACKAGE_kmod-nf-conntrack6=y
CONFIG_PACKAGE_kmod-nf-flow=y
CONFIG_PACKAGE_kmod-nf-ipt=y
# CONFIG_PACKAGE_kmod-nf-ipt6 is not set
# CONFIG_PACKAGE_kmod-nf-ipvs is not set
CONFIG_PACKAGE_kmod-nf-log=y
CONFIG_PACKAGE_kmod-nf-log6=y
CONFIG_PACKAGE_kmod-nf-nat=y
CONFIG_PACKAGE_kmod-nf-nat6=y
# CONFIG_PACKAGE_kmod-nf-nathelper is not set
# CONFIG_PACKAGE_kmod-nf-nathelper-extra is not set
CONFIG_PACKAGE_kmod-nf-reject=y
CONFIG_PACKAGE_kmod-nf-reject6=y
# CONFIG_PACKAGE_kmod-nf-socket is not set
CONFIG_PACKAGE_kmod-nf-tproxy=y
CONFIG_PACKAGE_kmod-nfnetlink=y
# CONFIG_PACKAGE_kmod-nfnetlink-log is not set
# CONFIG_PACKAGE_kmod-nfnetlink-queue is not set
# CONFIG_PACKAGE_kmod-nft-arp is not set
# CONFIG_PACKAGE_kmod-nft-bridge is not set
# CONFIG_PACKAGE_kmod-nft-compat is not set
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-fib=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-nat6=y
# CONFIG_PACKAGE_kmod-nft-netdev is not set
CONFIG_PACKAGE_kmod-nft-offload=y
# CONFIG_PACKAGE_kmod-nft-queue is not set
# CONFIG_PACKAGE_kmod-nft-socket is not set
# CONFIG_PACKAGE_kmod-nft-tproxy is not set
# CONFIG_PACKAGE_kmod-nft-xfrm is not set
# end of Netfilter Extensions

#
# Network Devices
#
# CONFIG_PACKAGE_kmod-3c59x is not set
# CONFIG_PACKAGE_kmod-8139cp is not set
# CONFIG_PACKAGE_kmod-8139too is not set
# CONFIG_PACKAGE_kmod-alx is not set
# CONFIG_PACKAGE_kmod-atl1 is not set
# CONFIG_PACKAGE_kmod-atl1c is not set
# CONFIG_PACKAGE_kmod-atl1e is not set
# CONFIG_PACKAGE_kmod-atl2 is not set
# CONFIG_PACKAGE_kmod-b44 is not set
# CONFIG_PACKAGE_kmod-be2net is not set
# CONFIG_PACKAGE_kmod-bnx2 is not set
# CONFIG_PACKAGE_kmod-bnx2x is not set
# CONFIG_PACKAGE_kmod-dm9000 is not set
# CONFIG_PACKAGE_kmod-dummy is not set
# CONFIG_PACKAGE_kmod-e100 is not set
# CONFIG_PACKAGE_kmod-e1000 is not set
# CONFIG_PACKAGE_kmod-et131x is not set
# CONFIG_PACKAGE_kmod-ethoc is not set
# CONFIG_PACKAGE_kmod-fixed-phy is not set
# CONFIG_PACKAGE_kmod-forcedeth is not set
# CONFIG_PACKAGE_kmod-hfcmulti is not set
# CONFIG_PACKAGE_kmod-hfcpci is not set
# CONFIG_PACKAGE_kmod-i40e is not set
# CONFIG_PACKAGE_kmod-iavf is not set
CONFIG_PACKAGE_kmod-ifb=y
# CONFIG_PACKAGE_kmod-igb is not set
# CONFIG_PACKAGE_kmod-igc is not set
# CONFIG_PACKAGE_kmod-ipvlan is not set
# CONFIG_PACKAGE_kmod-ixgbe is not set
# CONFIG_PACKAGE_kmod-ixgbevf is not set
# CONFIG_PACKAGE_kmod-libphy is not set
# CONFIG_PACKAGE_kmod-macvlan is not set
# CONFIG_PACKAGE_kmod-mdio-gpio is not set
# CONFIG_PACKAGE_kmod-mii is not set
# CONFIG_PACKAGE_kmod-mlx4-core is not set
# CONFIG_PACKAGE_kmod-mlx5-core is not set
# CONFIG_PACKAGE_kmod-natsemi is not set
# CONFIG_PACKAGE_kmod-ne2k-pci is not set
# CONFIG_PACKAGE_kmod-net-selftests is not set
# CONFIG_PACKAGE_kmod-niu is not set
# CONFIG_PACKAGE_kmod-of-mdio is not set
# CONFIG_PACKAGE_kmod-pcnet32 is not set
# CONFIG_PACKAGE_kmod-phy-bcm84881 is not set
# CONFIG_PACKAGE_kmod-phy-broadcom is not set
# CONFIG_PACKAGE_kmod-phy-microchip is not set
# CONFIG_PACKAGE_kmod-phy-realtek is not set
# CONFIG_PACKAGE_kmod-phylink is not set
# CONFIG_PACKAGE_kmod-qlcnic is not set
# CONFIG_PACKAGE_kmod-r6040 is not set
# CONFIG_PACKAGE_kmod-r8169 is not set
# CONFIG_PACKAGE_kmod-sfc is not set
# CONFIG_PACKAGE_kmod-sfc-falcon is not set
# CONFIG_PACKAGE_kmod-sfp is not set
# CONFIG_PACKAGE_kmod-siit is not set
# CONFIG_PACKAGE_kmod-sis190 is not set
# CONFIG_PACKAGE_kmod-sis900 is not set
# CONFIG_PACKAGE_kmod-skge is not set
# CONFIG_PACKAGE_kmod-sky2 is not set
# CONFIG_PACKAGE_kmod-solos-pci is not set
# CONFIG_PACKAGE_kmod-spi-ks8995 is not set
# CONFIG_PACKAGE_kmod-swconfig is not set
# CONFIG_PACKAGE_kmod-switch-ar8xxx is not set
# CONFIG_PACKAGE_kmod-switch-bcm53xx is not set
# CONFIG_PACKAGE_kmod-switch-bcm53xx-mdio is not set
# CONFIG_PACKAGE_kmod-switch-ip17xx is not set
# CONFIG_PACKAGE_kmod-switch-rtl8306 is not set
# CONFIG_PACKAGE_kmod-switch-rtl8366-smi is not set
# CONFIG_PACKAGE_kmod-switch-rtl8366rb is not set
# CONFIG_PACKAGE_kmod-switch-rtl8366s is not set
# CONFIG_PACKAGE_kmod-switch-rtl8367 is not set
# CONFIG_PACKAGE_kmod-switch-rtl8367b is not set
# CONFIG_PACKAGE_kmod-tg3 is not set
# CONFIG_PACKAGE_kmod-tulip is not set
# CONFIG_PACKAGE_kmod-via-rhine is not set
# CONFIG_PACKAGE_kmod-via-velocity is not set
# CONFIG_PACKAGE_kmod-vmxnet3 is not set
# end of Network Devices

#
# Network Support
#
# CONFIG_PACKAGE_kmod-atm is not set
# CONFIG_PACKAGE_kmod-ax25 is not set
# CONFIG_PACKAGE_kmod-batman-adv is not set
# CONFIG_PACKAGE_kmod-bonding is not set
# CONFIG_PACKAGE_kmod-bpf-test is not set
# CONFIG_PACKAGE_kmod-dnsresolver is not set
# CONFIG_PACKAGE_kmod-fou is not set
# CONFIG_PACKAGE_kmod-fou6 is not set
# CONFIG_PACKAGE_kmod-geneve is not set
# CONFIG_PACKAGE_kmod-gre is not set
# CONFIG_PACKAGE_kmod-gre6 is not set
CONFIG_PACKAGE_kmod-inet-diag=y
# CONFIG_PACKAGE_kmod-ip6-tunnel is not set
CONFIG_PACKAGE_kmod-ipip=y
# CONFIG_PACKAGE_kmod-ipsec is not set
CONFIG_PACKAGE_kmod-iptunnel=y
CONFIG_PACKAGE_kmod-iptunnel4=y
# CONFIG_PACKAGE_kmod-iptunnel6 is not set
# CONFIG_PACKAGE_kmod-isdn4linux is not set
# CONFIG_PACKAGE_kmod-jool-netfilter is not set
# CONFIG_PACKAGE_kmod-l2tp is not set
# CONFIG_PACKAGE_kmod-l2tp-eth is not set
# CONFIG_PACKAGE_kmod-l2tp-ip is not set
# CONFIG_PACKAGE_kmod-macremapper is not set
# CONFIG_PACKAGE_kmod-macsec is not set
# CONFIG_PACKAGE_kmod-mdio-netlink is not set
# CONFIG_PACKAGE_kmod-misdn is not set
# CONFIG_PACKAGE_kmod-mpls is not set
# CONFIG_PACKAGE_kmod-nat46 is not set
# CONFIG_PACKAGE_kmod-netconsole is not set
# CONFIG_PACKAGE_kmod-netem is not set
# CONFIG_PACKAGE_kmod-netlink-diag is not set
# CONFIG_PACKAGE_kmod-nlmon is not set
# CONFIG_PACKAGE_kmod-nsh is not set
# CONFIG_PACKAGE_kmod-openvswitch is not set
# CONFIG_PACKAGE_kmod-openvswitch-geneve is not set
# CONFIG_PACKAGE_kmod-openvswitch-gre is not set
# CONFIG_PACKAGE_kmod-openvswitch-vxlan is not set
# CONFIG_PACKAGE_kmod-ovpn-dco is not set
# CONFIG_PACKAGE_kmod-pf-ring is not set
# CONFIG_PACKAGE_kmod-pktgen is not set
CONFIG_PACKAGE_kmod-ppp=y
# CONFIG_PACKAGE_kmod-mppe is not set
# CONFIG_PACKAGE_kmod-ppp-synctty is not set
# CONFIG_PACKAGE_kmod-pppoa is not set
CONFIG_PACKAGE_kmod-pppoe=y
# CONFIG_PACKAGE_kmod-pppol2tp is not set
CONFIG_PACKAGE_kmod-pppox=y
# CONFIG_PACKAGE_kmod-pptp is not set
# CONFIG_PACKAGE_kmod-sched is not set
# CONFIG_PACKAGE_kmod-sched-act-vlan is not set
# CONFIG_PACKAGE_kmod-sched-bpf is not set
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-sched-connmark=y
CONFIG_PACKAGE_kmod-sched-core=y
# CONFIG_PACKAGE_kmod-sched-ctinfo is not set
# CONFIG_PACKAGE_kmod-sched-flower is not set
# CONFIG_PACKAGE_kmod-sched-ipset is not set
# CONFIG_PACKAGE_kmod-sched-mqprio is not set
# CONFIG_PACKAGE_kmod-sctp is not set
# CONFIG_PACKAGE_kmod-sit is not set
CONFIG_PACKAGE_kmod-slhc=y
# CONFIG_PACKAGE_kmod-slip is not set
# CONFIG_PACKAGE_kmod-tcp-bbr is not set
# CONFIG_PACKAGE_kmod-tcp-hybla is not set
# CONFIG_PACKAGE_kmod-tcp-scalable is not set
# CONFIG_PACKAGE_kmod-trelay is not set
CONFIG_PACKAGE_kmod-tun=y
# CONFIG_PACKAGE_kmod-veth is not set
# CONFIG_PACKAGE_kmod-vxlan is not set
# CONFIG_PACKAGE_kmod-wireguard is not set
# end of Network Support

#
# Other modules
#
# CONFIG_PACKAGE_kmod-6lowpan is not set
# CONFIG_PACKAGE_kmod-ath3k is not set
# CONFIG_PACKAGE_kmod-bcma is not set
# CONFIG_PACKAGE_kmod-bluetooth is not set
# CONFIG_PACKAGE_kmod-bluetooth-6lowpan is not set
# CONFIG_PACKAGE_kmod-btmrvl is not set
# CONFIG_PACKAGE_kmod-btsdio is not set
# CONFIG_PACKAGE_kmod-button-hotplug is not set
# CONFIG_PACKAGE_kmod-dma-ralink is not set
# CONFIG_PACKAGE_kmod-echo is not set
# CONFIG_PACKAGE_kmod-eeprom-93cx6 is not set
# CONFIG_PACKAGE_kmod-eeprom-at24 is not set
# CONFIG_PACKAGE_kmod-eeprom-at25 is not set
# CONFIG_PACKAGE_kmod-google-firmware is not set
# CONFIG_PACKAGE_kmod-gpio-beeper is not set
CONFIG_PACKAGE_kmod-gpio-button-hotplug=y
# CONFIG_PACKAGE_kmod-gpio-mcp23s08 is not set
# CONFIG_PACKAGE_kmod-gpio-nxp-74hc164 is not set
# CONFIG_PACKAGE_kmod-gpio-pca953x is not set
# CONFIG_PACKAGE_kmod-gpio-pcf857x is not set
# CONFIG_PACKAGE_kmod-hsdma-mtk is not set
# CONFIG_PACKAGE_kmod-i6300esb-wdt is not set
# CONFIG_PACKAGE_kmod-ikconfig is not set
# CONFIG_PACKAGE_kmod-keys-encrypted is not set
# CONFIG_PACKAGE_kmod-keys-trusted is not set
# CONFIG_PACKAGE_kmod-lp is not set
CONFIG_PACKAGE_kmod-mmc=y
# CONFIG_PACKAGE_kmod-mtd-rw is not set
# CONFIG_PACKAGE_kmod-mtdoops is not set
# CONFIG_PACKAGE_kmod-mtdram is not set
# CONFIG_PACKAGE_kmod-mtdtests is not set
# CONFIG_PACKAGE_kmod-parport-pc is not set
# CONFIG_PACKAGE_kmod-ppdev is not set
# CONFIG_PACKAGE_kmod-pps is not set
# CONFIG_PACKAGE_kmod-pps-gpio is not set
# CONFIG_PACKAGE_kmod-pps-ldisc is not set
# CONFIG_PACKAGE_kmod-ptp is not set
# CONFIG_PACKAGE_kmod-ramoops is not set
# CONFIG_PACKAGE_kmod-random-core is not set
# CONFIG_PACKAGE_kmod-reed-solomon is not set
# CONFIG_PACKAGE_kmod-rtc-ds1307 is not set
# CONFIG_PACKAGE_kmod-rtc-ds1374 is not set
# CONFIG_PACKAGE_kmod-rtc-ds1672 is not set
# CONFIG_PACKAGE_kmod-rtc-em3027 is not set
# CONFIG_PACKAGE_kmod-rtc-isl1208 is not set
# CONFIG_PACKAGE_kmod-rtc-pcf2123 is not set
# CONFIG_PACKAGE_kmod-rtc-pcf2127 is not set
# CONFIG_PACKAGE_kmod-rtc-pcf8563 is not set
# CONFIG_PACKAGE_kmod-rtc-pt7c4338 is not set
# CONFIG_PACKAGE_kmod-rtc-rs5c372a is not set
# CONFIG_PACKAGE_kmod-rtc-rx8025 is not set
# CONFIG_PACKAGE_kmod-rtc-s35390a is not set
# CONFIG_PACKAGE_kmod-sdhci is not set
CONFIG_PACKAGE_kmod-sdhci-mt7620=y
# CONFIG_PACKAGE_kmod-serial-8250 is not set
# CONFIG_PACKAGE_kmod-serial-8250-exar is not set
# CONFIG_PACKAGE_kmod-softdog is not set
# CONFIG_PACKAGE_kmod-ssb is not set
# CONFIG_PACKAGE_kmod-tpm is not set
# CONFIG_PACKAGE_kmod-tpm-i2c-atmel is not set
# CONFIG_PACKAGE_kmod-tpm-i2c-infineon is not set
# CONFIG_PACKAGE_kmod-zram is not set
CONFIG_ZRAM_DEF_COMP_LZORLE=y
# CONFIG_ZRAM_DEF_COMP_LZO is not set
# CONFIG_ZRAM_DEF_COMP_LZ4 is not set
# CONFIG_ZRAM_DEF_COMP_ZSTD is not set
# end of Other modules

#
# PCMCIA support
#
# end of PCMCIA support

#
# SPI Support
#
# CONFIG_PACKAGE_kmod-mmc-spi is not set
# CONFIG_PACKAGE_kmod-spi-bitbang is not set
# CONFIG_PACKAGE_kmod-spi-dev is not set
# CONFIG_PACKAGE_kmod-spi-gpio is not set
# end of SPI Support

#
# Sound Support
#
# CONFIG_PACKAGE_kmod-sound-core is not set
# end of Sound Support

#
# USB Support
#
# CONFIG_PACKAGE_kmod-chaoskey is not set
# CONFIG_PACKAGE_kmod-usb-acm is not set
# CONFIG_PACKAGE_kmod-usb-atm is not set
# CONFIG_PACKAGE_kmod-usb-cm109 is not set
CONFIG_PACKAGE_kmod-usb-core=y
# CONFIG_PACKAGE_kmod-usb-dwc2 is not set
# CONFIG_PACKAGE_kmod-usb-dwc3 is not set
# CONFIG_PACKAGE_kmod-usb-hid is not set
# CONFIG_PACKAGE_kmod-usb-hid-cp2112 is not set
# CONFIG_PACKAGE_kmod-usb-ledtrig-usbport is not set
# CONFIG_PACKAGE_kmod-usb-net is not set
# CONFIG_PACKAGE_kmod-usb-net-aqc111 is not set
# CONFIG_PACKAGE_kmod-usb-net-asix is not set
# CONFIG_PACKAGE_kmod-usb-net-asix-ax88179 is not set
# CONFIG_PACKAGE_kmod-usb-net-cdc-eem is not set
# CONFIG_PACKAGE_kmod-usb-net-cdc-ether is not set
# CONFIG_PACKAGE_kmod-usb-net-cdc-mbim is not set
# CONFIG_PACKAGE_kmod-usb-net-cdc-ncm is not set
# CONFIG_PACKAGE_kmod-usb-net-cdc-subset is not set
# CONFIG_PACKAGE_kmod-usb-net-dm9601-ether is not set
# CONFIG_PACKAGE_kmod-usb-net-hso is not set
# CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm is not set
# CONFIG_PACKAGE_kmod-usb-net-ipheth is not set
# CONFIG_PACKAGE_kmod-usb-net-kalmia is not set
# CONFIG_PACKAGE_kmod-usb-net-kaweth is not set
# CONFIG_PACKAGE_kmod-usb-net-lan78xx is not set
# CONFIG_PACKAGE_kmod-usb-net-mcs7830 is not set
# CONFIG_PACKAGE_kmod-usb-net-pegasus is not set
# CONFIG_PACKAGE_kmod-usb-net-pl is not set
# CONFIG_PACKAGE_kmod-usb-net-qmi-wwan is not set
# CONFIG_PACKAGE_kmod-usb-net-rndis is not set
# CONFIG_PACKAGE_kmod-usb-net-rtl8150 is not set
# CONFIG_PACKAGE_kmod-usb-net-rtl8152 is not set
# CONFIG_PACKAGE_kmod-usb-net-sierrawireless is not set
# CONFIG_PACKAGE_kmod-usb-net-smsc75xx is not set
# CONFIG_PACKAGE_kmod-usb-net-smsc95xx is not set
# CONFIG_PACKAGE_kmod-usb-net-sr9700 is not set
# CONFIG_PACKAGE_kmod-usb-ohci is not set
# CONFIG_PACKAGE_kmod-usb-ohci-pci is not set
# CONFIG_PACKAGE_kmod-usb-printer is not set
# CONFIG_PACKAGE_kmod-usb-serial is not set
# CONFIG_PACKAGE_kmod-usb-serial-ark3116 is not set
# CONFIG_PACKAGE_kmod-usb-serial-belkin is not set
# CONFIG_PACKAGE_kmod-usb-serial-ch341 is not set
# CONFIG_PACKAGE_kmod-usb-serial-cp210x is not set
# CONFIG_PACKAGE_kmod-usb-serial-cypress-m8 is not set
# CONFIG_PACKAGE_kmod-usb-serial-edgeport is not set
# CONFIG_PACKAGE_kmod-usb-serial-ftdi is not set
# CONFIG_PACKAGE_kmod-usb-serial-garmin is not set
# CONFIG_PACKAGE_kmod-usb-serial-ipw is not set
# CONFIG_PACKAGE_kmod-usb-serial-keyspan is not set
# CONFIG_PACKAGE_kmod-usb-serial-mct is not set
# CONFIG_PACKAGE_kmod-usb-serial-mos7720 is not set
# CONFIG_PACKAGE_kmod-usb-serial-mos7840 is not set
# CONFIG_PACKAGE_kmod-usb-serial-option is not set
# CONFIG_PACKAGE_kmod-usb-serial-oti6858 is not set
# CONFIG_PACKAGE_kmod-usb-serial-pl2303 is not set
# CONFIG_PACKAGE_kmod-usb-serial-qualcomm is not set
# CONFIG_PACKAGE_kmod-usb-serial-sierrawireless is not set
# CONFIG_PACKAGE_kmod-usb-serial-simple is not set
# CONFIG_PACKAGE_kmod-usb-serial-ti-usb is not set
# CONFIG_PACKAGE_kmod-usb-serial-visor is not set
# CONFIG_PACKAGE_kmod-usb-storage is not set
# CONFIG_PACKAGE_kmod-usb-storage-extras is not set
# CONFIG_PACKAGE_kmod-usb-storage-uas is not set
# CONFIG_PACKAGE_kmod-usb-uhci is not set
# CONFIG_PACKAGE_kmod-usb-wdm is not set
CONFIG_PACKAGE_kmod-usb-xhci-hcd=y
CONFIG_PACKAGE_kmod-usb-xhci-mtk=y
# CONFIG_PACKAGE_kmod-usb-yealink is not set
# CONFIG_PACKAGE_kmod-usb2 is not set
# CONFIG_PACKAGE_kmod-usb2-pci is not set
CONFIG_PACKAGE_kmod-usb3=y
# CONFIG_PACKAGE_kmod-usbip is not set
# CONFIG_PACKAGE_kmod-usbip-client is not set
# CONFIG_PACKAGE_kmod-usbip-server is not set
# CONFIG_PACKAGE_kmod-usbmon is not set
# end of USB Support

#
# Video Support
#
# CONFIG_PACKAGE_kmod-v4l2loopback is not set
# CONFIG_PACKAGE_kmod-video-core is not set
# end of Video Support

#
# Virtualization
#
# end of Virtualization

#
# Voice over IP
#
# CONFIG_PACKAGE_kmod-dahdi is not set
# end of Voice over IP

#
# W1 support
#
# CONFIG_PACKAGE_kmod-w1 is not set
# end of W1 support

#
# WPAN 802.15.4 Support
#
# CONFIG_PACKAGE_kmod-at86rf230 is not set
# CONFIG_PACKAGE_kmod-atusb is not set
# CONFIG_PACKAGE_kmod-ca8210 is not set
# CONFIG_PACKAGE_kmod-cc2520 is not set
# CONFIG_PACKAGE_kmod-fakelb is not set
# CONFIG_PACKAGE_kmod-ieee802154 is not set
# CONFIG_PACKAGE_kmod-ieee802154-6lowpan is not set
# CONFIG_PACKAGE_kmod-mac802154 is not set
# CONFIG_PACKAGE_kmod-mrf24j40 is not set
# end of WPAN 802.15.4 Support

#
# Wireless Drivers
#
# CONFIG_PACKAGE_kmod-acx-mac80211 is not set
# CONFIG_PACKAGE_kmod-adm8211 is not set
# CONFIG_PACKAGE_kmod-ar5523 is not set
# CONFIG_PACKAGE_kmod-ath is not set
# CONFIG_PACKAGE_kmod-ath10k is not set
# CONFIG_PACKAGE_kmod-ath10k-ct is not set
# CONFIG_PACKAGE_kmod-ath10k-ct-smallbuffers is not set
# CONFIG_PACKAGE_kmod-ath10k-smallbuffers is not set
# CONFIG_PACKAGE_kmod-ath5k is not set
# CONFIG_PACKAGE_kmod-ath6kl-sdio is not set
# CONFIG_PACKAGE_kmod-ath6kl-usb is not set
# CONFIG_PACKAGE_kmod-ath9k is not set
# CONFIG_PACKAGE_kmod-ath9k-htc is not set
# CONFIG_PACKAGE_kmod-b43 is not set
# CONFIG_PACKAGE_kmod-b43legacy is not set
# CONFIG_PACKAGE_kmod-brcmfmac is not set
# CONFIG_PACKAGE_kmod-brcmsmac is not set
# CONFIG_PACKAGE_kmod-brcmutil is not set
# CONFIG_PACKAGE_kmod-carl9170 is not set
CONFIG_PACKAGE_kmod-cfg80211=y
# CONFIG_PACKAGE_CFG80211_TESTMODE is not set
# CONFIG_PACKAGE_kmod-hermes is not set
# CONFIG_PACKAGE_kmod-hermes-pci is not set
# CONFIG_PACKAGE_kmod-hermes-plx is not set
# CONFIG_PACKAGE_kmod-ipw2100 is not set
# CONFIG_PACKAGE_kmod-ipw2200 is not set
# CONFIG_PACKAGE_kmod-iwl-legacy is not set
# CONFIG_PACKAGE_kmod-iwl3945 is not set
# CONFIG_PACKAGE_kmod-iwl4965 is not set
# CONFIG_PACKAGE_kmod-iwlwifi is not set
# CONFIG_PACKAGE_kmod-lib80211 is not set
# CONFIG_PACKAGE_kmod-libertas-sdio is not set
# CONFIG_PACKAGE_kmod-libertas-spi is not set
# CONFIG_PACKAGE_kmod-libertas-usb is not set
# CONFIG_PACKAGE_kmod-libipw is not set
CONFIG_PACKAGE_kmod-mac80211=y
CONFIG_PACKAGE_MAC80211_DEBUGFS=y
# CONFIG_PACKAGE_MAC80211_TRACING is not set
CONFIG_PACKAGE_MAC80211_MESH=y
# CONFIG_PACKAGE_kmod-mac80211-hwsim is not set
# CONFIG_PACKAGE_kmod-mt76 is not set
CONFIG_PACKAGE_kmod-mt76-connac=y
CONFIG_PACKAGE_kmod-mt76-core=y
# CONFIG_PACKAGE_kmod-mt7601u is not set
CONFIG_PACKAGE_kmod-mt7603=y
CONFIG_PACKAGE_kmod-mt7615-common=y
CONFIG_PACKAGE_kmod-mt7615-firmware=y
CONFIG_PACKAGE_kmod-mt7615e=y
# CONFIG_PACKAGE_kmod-mt7663-firmware-ap is not set
# CONFIG_PACKAGE_kmod-mt7663-firmware-sta is not set
# CONFIG_PACKAGE_kmod-mt7663s is not set
# CONFIG_PACKAGE_kmod-mt7663u is not set
# CONFIG_PACKAGE_kmod-mt76x0e is not set
# CONFIG_PACKAGE_kmod-mt76x0u is not set
# CONFIG_PACKAGE_kmod-mt76x2 is not set
# CONFIG_PACKAGE_kmod-mt76x2u is not set
# CONFIG_PACKAGE_kmod-mt7915e is not set
# CONFIG_PACKAGE_kmod-mt7921e is not set
# CONFIG_PACKAGE_kmod-mt7921s is not set
# CONFIG_PACKAGE_kmod-mt7921u is not set
# CONFIG_PACKAGE_kmod-mwifiex-pcie is not set
# CONFIG_PACKAGE_kmod-mwifiex-sdio is not set
# CONFIG_PACKAGE_kmod-mwl8k is not set
# CONFIG_PACKAGE_kmod-net-rtl8192su is not set
# CONFIG_PACKAGE_kmod-owl-loader is not set
# CONFIG_PACKAGE_kmod-p54-common is not set
# CONFIG_PACKAGE_kmod-p54-pci is not set
# CONFIG_PACKAGE_kmod-p54-usb is not set
# CONFIG_PACKAGE_kmod-rsi91x is not set
# CONFIG_PACKAGE_kmod-rsi91x-sdio is not set
# CONFIG_PACKAGE_kmod-rsi91x-usb is not set
# CONFIG_PACKAGE_kmod-rt2400-pci is not set
# CONFIG_PACKAGE_kmod-rt2500-pci is not set
# CONFIG_PACKAGE_kmod-rt2500-usb is not set
# CONFIG_PACKAGE_kmod-rt2800-pci is not set
# CONFIG_PACKAGE_kmod-rt2800-usb is not set
# CONFIG_PACKAGE_kmod-rt2x00-lib is not set
# CONFIG_PACKAGE_kmod-rt61-pci is not set
# CONFIG_PACKAGE_kmod-rt73-usb is not set
# CONFIG_PACKAGE_kmod-rtl8180 is not set
# CONFIG_PACKAGE_kmod-rtl8187 is not set
# CONFIG_PACKAGE_kmod-rtl8192ce is not set
# CONFIG_PACKAGE_kmod-rtl8192cu is not set
# CONFIG_PACKAGE_kmod-rtl8192de is not set
# CONFIG_PACKAGE_kmod-rtl8192se is not set
# CONFIG_PACKAGE_kmod-rtl8723bs is not set
# CONFIG_PACKAGE_kmod-rtl8812au-ct is not set
# CONFIG_PACKAGE_kmod-rtl8821ae is not set
# CONFIG_PACKAGE_kmod-rtl8xxxu is not set
# CONFIG_PACKAGE_kmod-rtw88 is not set
# CONFIG_PACKAGE_kmod-wil6210 is not set
# CONFIG_PACKAGE_kmod-wl12xx is not set
# CONFIG_PACKAGE_kmod-wl18xx is not set
# CONFIG_PACKAGE_kmod-wlcore is not set
# CONFIG_PACKAGE_kmod-zd1211rw is not set
# end of Wireless Drivers
# end of Kernel modules

#
# Languages
#

#
# Erlang
#
# CONFIG_PACKAGE_erlang is not set
# CONFIG_PACKAGE_erlang-asn1 is not set
# CONFIG_PACKAGE_erlang-compiler is not set
# CONFIG_PACKAGE_erlang-crypto is not set
# CONFIG_PACKAGE_erlang-erl-interface is not set
# CONFIG_PACKAGE_erlang-inets is not set
# CONFIG_PACKAGE_erlang-mnesia is not set
# CONFIG_PACKAGE_erlang-os_mon is not set
# CONFIG_PACKAGE_erlang-public-key is not set
# CONFIG_PACKAGE_erlang-reltool is not set
# CONFIG_PACKAGE_erlang-runtime-tools is not set
# CONFIG_PACKAGE_erlang-snmp is not set
# CONFIG_PACKAGE_erlang-ssh is not set
# CONFIG_PACKAGE_erlang-ssl is not set
# CONFIG_PACKAGE_erlang-syntax-tools is not set
# CONFIG_PACKAGE_erlang-tools is not set
# CONFIG_PACKAGE_erlang-xmerl is not set
# end of Erlang

#
# Go
#
# CONFIG_PACKAGE_golang is not set

#
# Configuration
#
CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=""
CONFIG_GOLANG_BUILD_CACHE_DIR=""
# CONFIG_GOLANG_MOD_CACHE_WORLD_READABLE is not set
# end of Configuration

# CONFIG_PACKAGE_golang-doc is not set
# CONFIG_PACKAGE_golang-github-jedisct1-dnscrypt-proxy2-dev is not set
# CONFIG_PACKAGE_golang-github-nextdns-nextdns-dev is not set
# CONFIG_PACKAGE_golang-gitlab-yawning-obfs4-dev is not set
# CONFIG_PACKAGE_golang-src is not set
# CONFIG_PACKAGE_golang-torproject-tor-fw-helper-dev is not set
# end of Go

#
# Lua
#
# CONFIG_PACKAGE_cqueues is not set
# CONFIG_PACKAGE_dkjson is not set
# CONFIG_PACKAGE_json4lua is not set
# CONFIG_PACKAGE_ldbus is not set
CONFIG_PACKAGE_libiwinfo-lua=y
# CONFIG_PACKAGE_linotify is not set
# CONFIG_PACKAGE_lpeg is not set
# CONFIG_PACKAGE_lsqlite3 is not set
CONFIG_PACKAGE_lua=y
# CONFIG_PACKAGE_lua-argparse is not set
# CONFIG_PACKAGE_lua-bencode is not set
# CONFIG_PACKAGE_lua-bit32 is not set
# CONFIG_PACKAGE_lua-cjson is not set
# CONFIG_PACKAGE_lua-copas is not set
# CONFIG_PACKAGE_lua-coxpcall is not set
# CONFIG_PACKAGE_lua-cs-bouncer is not set
# CONFIG_PACKAGE_lua-curl-v3 is not set
# CONFIG_PACKAGE_lua-eco is not set
# CONFIG_PACKAGE_lua-eco-dns is not set
# CONFIG_PACKAGE_lua-eco-file is not set
# CONFIG_PACKAGE_lua-eco-ip is not set
# CONFIG_PACKAGE_lua-eco-iw is not set
# CONFIG_PACKAGE_lua-eco-log is not set
# CONFIG_PACKAGE_lua-eco-socket is not set
# CONFIG_PACKAGE_lua-eco-ssl is not set
# CONFIG_PACKAGE_lua-eco-sys is not set
# CONFIG_PACKAGE_lua-eco-ubus is not set
# CONFIG_PACKAGE_lua-ev is not set
# CONFIG_PACKAGE_lua-examples is not set
# CONFIG_PACKAGE_lua-libmodbus is not set
# CONFIG_PACKAGE_lua-lzlib is not set
# CONFIG_PACKAGE_lua-maxminddb is not set
# CONFIG_PACKAGE_lua-md5 is not set
# CONFIG_PACKAGE_lua-mobdebug is not set
# CONFIG_PACKAGE_lua-mosquitto is not set
# CONFIG_PACKAGE_lua-openssl is not set
# CONFIG_PACKAGE_lua-penlight is not set
# CONFIG_PACKAGE_lua-rings is not set
# CONFIG_PACKAGE_lua-rs232 is not set
# CONFIG_PACKAGE_lua-sha2 is not set
# CONFIG_PACKAGE_lua-wsapi-base is not set
# CONFIG_PACKAGE_lua-wsapi-xavante is not set
# CONFIG_PACKAGE_lua-xavante is not set
# CONFIG_PACKAGE_lua5.3 is not set
# CONFIG_PACKAGE_luabitop is not set
# CONFIG_PACKAGE_luac is not set
# CONFIG_PACKAGE_luac5.3 is not set
# CONFIG_PACKAGE_luaexpat is not set
# CONFIG_PACKAGE_luafilesystem is not set
# CONFIG_PACKAGE_luajit is not set
# CONFIG_PACKAGE_lualanes is not set
# CONFIG_PACKAGE_luaossl is not set
# CONFIG_PACKAGE_luaposix is not set
# CONFIG_PACKAGE_luarocks is not set
# CONFIG_PACKAGE_luasec is not set
# CONFIG_PACKAGE_luasoap is not set
# CONFIG_PACKAGE_luasocket is not set
# CONFIG_PACKAGE_luasocket5.3 is not set
# CONFIG_PACKAGE_luasql-mysql is not set
# CONFIG_PACKAGE_luasql-pgsql is not set
# CONFIG_PACKAGE_luasql-sqlite3 is not set
# CONFIG_PACKAGE_luasrcdiet is not set
# CONFIG_PACKAGE_luv is not set
# CONFIG_PACKAGE_lyaml is not set
# CONFIG_PACKAGE_lzmq is not set
# CONFIG_PACKAGE_uuid is not set
# end of Lua

#
# Node.js
#
# end of Node.js

#
# PHP8
#
# CONFIG_PACKAGE_php8 is not set
# end of PHP8

#
# Perl
#
# CONFIG_PACKAGE_perl is not set
# end of Perl

#
# Python
#
# CONFIG_PACKAGE_libpython3 is not set
# CONFIG_PACKAGE_micropython-lib is not set
# CONFIG_PACKAGE_micropython-mbedtls is not set
# CONFIG_PACKAGE_micropython-nossl is not set
# CONFIG_PACKAGE_python-pip-conf is not set
# CONFIG_PACKAGE_python3 is not set
# CONFIG_PACKAGE_python3-aiohttp is not set
# CONFIG_PACKAGE_python3-aiohttp-cors is not set
# CONFIG_PACKAGE_python3-apipkg is not set
# CONFIG_PACKAGE_python3-apparmor is not set
# CONFIG_PACKAGE_python3-appdirs is not set
# CONFIG_PACKAGE_python3-asgiref is not set
# CONFIG_PACKAGE_python3-astral is not set
# CONFIG_PACKAGE_python3-async-timeout is not set
# CONFIG_PACKAGE_python3-asyncio is not set
# CONFIG_PACKAGE_python3-atomicwrites is not set
# CONFIG_PACKAGE_python3-attrs is not set
# CONFIG_PACKAGE_python3-augeas is not set
# CONFIG_PACKAGE_python3-automat is not set
# CONFIG_PACKAGE_python3-awesomeversion is not set
# CONFIG_PACKAGE_python3-awscli is not set
# CONFIG_PACKAGE_python3-babel is not set
# CONFIG_PACKAGE_python3-base is not set
# CONFIG_PACKAGE_python3-bcrypt is not set
# CONFIG_PACKAGE_python3-bidict is not set
# CONFIG_PACKAGE_python3-boto3 is not set
# CONFIG_PACKAGE_python3-botocore is not set
# CONFIG_PACKAGE_python3-bottle is not set
# CONFIG_PACKAGE_python3-cached-property is not set
# CONFIG_PACKAGE_python3-cachelib is not set
# CONFIG_PACKAGE_python3-cachetools is not set
# CONFIG_PACKAGE_python3-certifi is not set
# CONFIG_PACKAGE_python3-cffi is not set
# CONFIG_PACKAGE_python3-cgi is not set
# CONFIG_PACKAGE_python3-cgitb is not set
# CONFIG_PACKAGE_python3-chardet is not set
# CONFIG_PACKAGE_python3-ciso8601 is not set
# CONFIG_PACKAGE_python3-click is not set
# CONFIG_PACKAGE_python3-click-log is not set
# CONFIG_PACKAGE_python3-codecs is not set
# CONFIG_PACKAGE_python3-colorama is not set
# CONFIG_PACKAGE_python3-constantly is not set
# CONFIG_PACKAGE_python3-contextlib2 is not set
# CONFIG_PACKAGE_python3-cryptodome is not set
# CONFIG_PACKAGE_python3-cryptodomex is not set
# CONFIG_PACKAGE_python3-cryptography is not set
# CONFIG_PACKAGE_python3-ctypes is not set
# CONFIG_PACKAGE_python3-curl is not set
# CONFIG_PACKAGE_python3-dateutil is not set
# CONFIG_PACKAGE_python3-dbm is not set
# CONFIG_PACKAGE_python3-decimal is not set
# CONFIG_PACKAGE_python3-decorator is not set
# CONFIG_PACKAGE_python3-defusedxml is not set
# CONFIG_PACKAGE_python3-dev is not set
# CONFIG_PACKAGE_python3-distro is not set
# CONFIG_PACKAGE_python3-distutils is not set
# CONFIG_PACKAGE_python3-django is not set
# CONFIG_PACKAGE_python3-django-cors-headers is not set
# CONFIG_PACKAGE_python3-django-etesync-journal is not set
# CONFIG_PACKAGE_python3-django-restframework is not set
# CONFIG_PACKAGE_python3-dns is not set
# CONFIG_PACKAGE_python3-docker is not set
# CONFIG_PACKAGE_python3-dockerpty is not set
# CONFIG_PACKAGE_python3-docopt is not set
# CONFIG_PACKAGE_python3-docutils is not set
# CONFIG_PACKAGE_python3-dotenv is not set
# CONFIG_PACKAGE_python3-drf-nested-routers is not set
# CONFIG_PACKAGE_python3-email is not set
# CONFIG_PACKAGE_python3-engineio is not set
# CONFIG_PACKAGE_python3-et_xmlfile is not set
# CONFIG_PACKAGE_python3-evdev is not set
# CONFIG_PACKAGE_python3-eventlet is not set
# CONFIG_PACKAGE_python3-execnet is not set
# CONFIG_PACKAGE_python3-flask is not set
# CONFIG_PACKAGE_python3-flask-babel is not set
# CONFIG_PACKAGE_python3-flask-httpauth is not set
# CONFIG_PACKAGE_python3-flask-login is not set
# CONFIG_PACKAGE_python3-flask-seasurf is not set
# CONFIG_PACKAGE_python3-flask-session is not set
# CONFIG_PACKAGE_python3-flask-socketio is not set
# CONFIG_PACKAGE_python3-flup is not set
# CONFIG_PACKAGE_python3-gmpy2 is not set
# CONFIG_PACKAGE_python3-gnupg is not set
# CONFIG_PACKAGE_python3-gpiod is not set
# CONFIG_PACKAGE_python3-greenlet is not set
# CONFIG_PACKAGE_python3-hyperlink is not set
# CONFIG_PACKAGE_python3-idna is not set
# CONFIG_PACKAGE_python3-ifaddr is not set
# CONFIG_PACKAGE_python3-incremental is not set
# CONFIG_PACKAGE_python3-influxdb is not set
# CONFIG_PACKAGE_python3-iniconfig is not set
# CONFIG_PACKAGE_python3-intelhex is not set
# CONFIG_PACKAGE_python3-itsdangerous is not set
# CONFIG_PACKAGE_python3-jdcal is not set
# CONFIG_PACKAGE_python3-jinja2 is not set
# CONFIG_PACKAGE_python3-jmespath is not set
# CONFIG_PACKAGE_python3-jsonpath-ng is not set
# CONFIG_PACKAGE_python3-jsonschema is not set
# CONFIG_PACKAGE_python3-lib2to3 is not set
# CONFIG_PACKAGE_python3-libmodbus is not set
# CONFIG_PACKAGE_python3-libselinux is not set
# CONFIG_PACKAGE_python3-libsemanage is not set
# CONFIG_PACKAGE_python3-light is not set

#
# Configuration
#
# CONFIG_PYTHON3_HOST_PIP_CACHE_WORLD_READABLE is not set
# end of Configuration

# CONFIG_PACKAGE_python3-logging is not set
# CONFIG_PACKAGE_python3-lxml is not set
# CONFIG_PACKAGE_python3-lzma is not set
# CONFIG_PACKAGE_python3-markdown is not set
# CONFIG_PACKAGE_python3-markupsafe is not set
# CONFIG_PACKAGE_python3-maxminddb is not set
# CONFIG_PACKAGE_python3-more-itertools is not set
# CONFIG_PACKAGE_python3-msgpack is not set
# CONFIG_PACKAGE_python3-multidict is not set
# CONFIG_PACKAGE_python3-multiprocessing is not set
# CONFIG_PACKAGE_python3-ncurses is not set
# CONFIG_PACKAGE_python3-netdisco is not set
# CONFIG_PACKAGE_python3-netifaces is not set
# CONFIG_PACKAGE_python3-networkx is not set
# CONFIG_PACKAGE_python3-newt is not set

#
# Configuration
#
# CONFIG_NUMPY_OPENBLAS_SUPPORT is not set
# end of Configuration

# CONFIG_PACKAGE_python3-openpyxl is not set
# CONFIG_PACKAGE_python3-openssl is not set
# CONFIG_PACKAGE_python3-packaging is not set
# CONFIG_PACKAGE_python3-paho-mqtt is not set
# CONFIG_PACKAGE_python3-paramiko is not set
# CONFIG_PACKAGE_python3-parsley is not set
# CONFIG_PACKAGE_python3-passlib is not set
# CONFIG_PACKAGE_python3-pillow is not set
# CONFIG_PACKAGE_python3-pip is not set
# CONFIG_PACKAGE_python3-pkg-resources is not set
# CONFIG_PACKAGE_python3-pluggy is not set
# CONFIG_PACKAGE_python3-ply is not set
# CONFIG_PACKAGE_python3-psutil is not set
# CONFIG_PACKAGE_python3-psycopg2 is not set
# CONFIG_PACKAGE_python3-py is not set
# CONFIG_PACKAGE_python3-pyasn1 is not set
# CONFIG_PACKAGE_python3-pyasn1-modules is not set
# CONFIG_PACKAGE_python3-pycparser is not set
# CONFIG_PACKAGE_python3-pydoc is not set
# CONFIG_PACKAGE_python3-pyinotify is not set
# CONFIG_PACKAGE_python3-pymysql is not set
# CONFIG_PACKAGE_python3-pynacl is not set
# CONFIG_PACKAGE_python3-pyodbc is not set
# CONFIG_PACKAGE_python3-pyopenssl is not set
# CONFIG_PACKAGE_python3-pyotp is not set
# CONFIG_PACKAGE_python3-pyparsing is not set
# CONFIG_PACKAGE_python3-pyroute2 is not set
# CONFIG_PACKAGE_python3-pyrsistent is not set
# CONFIG_PACKAGE_python3-pyserial is not set
# CONFIG_PACKAGE_python3-pysocks is not set
# CONFIG_PACKAGE_python3-pytest is not set
# CONFIG_PACKAGE_python3-pytest-forked is not set
# CONFIG_PACKAGE_python3-pytest-xdist is not set
# CONFIG_PACKAGE_python3-pytz is not set
# CONFIG_PACKAGE_python3-readline is not set
# CONFIG_PACKAGE_python3-requests is not set
# CONFIG_PACKAGE_python3-rsa is not set
# CONFIG_PACKAGE_python3-ruamel-yaml is not set
# CONFIG_PACKAGE_python3-s3transfer is not set
# CONFIG_PACKAGE_python3-schedule is not set
# CONFIG_PACKAGE_python3-schema is not set
# CONFIG_PACKAGE_python3-sentry-sdk is not set
# CONFIG_PACKAGE_python3-sepolgen is not set
# CONFIG_PACKAGE_python3-sepolicy is not set
# CONFIG_PACKAGE_python3-service-identity is not set
# CONFIG_PACKAGE_python3-setuptools is not set
# CONFIG_PACKAGE_python3-simplejson is not set
# CONFIG_PACKAGE_python3-six is not set
# CONFIG_PACKAGE_python3-slugify is not set
# CONFIG_PACKAGE_python3-smbus is not set
# CONFIG_PACKAGE_python3-socketio is not set
# CONFIG_PACKAGE_python3-speedtest-cli is not set
# CONFIG_PACKAGE_python3-sqlalchemy is not set
# CONFIG_PACKAGE_python3-sqlite3 is not set
# CONFIG_PACKAGE_python3-sqlparse is not set
# CONFIG_PACKAGE_python3-stem is not set
# CONFIG_PACKAGE_python3-text-unidecode is not set
# CONFIG_PACKAGE_python3-texttable is not set
# CONFIG_PACKAGE_python3-toml is not set
# CONFIG_PACKAGE_python3-tornado is not set
# CONFIG_PACKAGE_python3-twisted is not set
# CONFIG_PACKAGE_python3-typing-extensions is not set
# CONFIG_PACKAGE_python3-ubus is not set
# CONFIG_PACKAGE_python3-uci is not set
# CONFIG_PACKAGE_python3-unidecode is not set
# CONFIG_PACKAGE_python3-unittest is not set
# CONFIG_PACKAGE_python3-urllib is not set
# CONFIG_PACKAGE_python3-urllib3 is not set
# CONFIG_PACKAGE_python3-uuid is not set
# CONFIG_PACKAGE_python3-vobject is not set
# CONFIG_PACKAGE_python3-voluptuous is not set
# CONFIG_PACKAGE_python3-voluptuous-serialize is not set
# CONFIG_PACKAGE_python3-wcwidth is not set
# CONFIG_PACKAGE_python3-websocket-client is not set
# CONFIG_PACKAGE_python3-websockets is not set
# CONFIG_PACKAGE_python3-werkzeug is not set
# CONFIG_PACKAGE_python3-xml is not set
# CONFIG_PACKAGE_python3-xmltodict is not set
# CONFIG_PACKAGE_python3-yaml is not set
# CONFIG_PACKAGE_python3-yarl is not set
# CONFIG_PACKAGE_python3-zeroconf is not set
# CONFIG_PACKAGE_python3-zipp is not set
# CONFIG_PACKAGE_python3-zope-interface is not set
# end of Python

#
# Ruby
#
CONFIG_PACKAGE_ruby=y

#
# Standard Library
#
# CONFIG_PACKAGE_ruby-stdlib is not set
# CONFIG_PACKAGE_ruby-abbrev is not set
# CONFIG_PACKAGE_ruby-base64 is not set
# CONFIG_PACKAGE_ruby-benchmark is not set
CONFIG_PACKAGE_ruby-bigdecimal=y
# CONFIG_PACKAGE_ruby-bundler is not set
# CONFIG_PACKAGE_ruby-cgi is not set
# CONFIG_PACKAGE_ruby-continuation is not set
# CONFIG_PACKAGE_ruby-coverage is not set
# CONFIG_PACKAGE_ruby-csv is not set
CONFIG_PACKAGE_ruby-date=y
# CONFIG_PACKAGE_ruby-debug is not set
# CONFIG_PACKAGE_ruby-delegate is not set
# CONFIG_PACKAGE_ruby-dev is not set
# CONFIG_PACKAGE_ruby-did-you-mean is not set
CONFIG_PACKAGE_ruby-digest=y
# CONFIG_RUBY_DIGEST_USE_OPENSSL is not set
# CONFIG_PACKAGE_ruby-drb is not set
CONFIG_PACKAGE_ruby-enc=y
# CONFIG_PACKAGE_ruby-enc-extra is not set
# CONFIG_PACKAGE_ruby-english is not set
# CONFIG_PACKAGE_ruby-erb is not set
# CONFIG_PACKAGE_ruby-error_highlight is not set
# CONFIG_PACKAGE_ruby-etc is not set
# CONFIG_PACKAGE_ruby-expect is not set
# CONFIG_PACKAGE_ruby-fcntl is not set
# CONFIG_PACKAGE_ruby-fiddle is not set
# CONFIG_PACKAGE_ruby-fileutils is not set
# CONFIG_PACKAGE_ruby-find is not set
CONFIG_PACKAGE_ruby-forwardable=y
# CONFIG_PACKAGE_ruby-gems is not set
# CONFIG_PACKAGE_ruby-getoptlong is not set
# CONFIG_PACKAGE_ruby-io-console is not set
# CONFIG_PACKAGE_ruby-io-nonblock is not set
# CONFIG_PACKAGE_ruby-io-wait is not set
# CONFIG_PACKAGE_ruby-ipaddr is not set
# CONFIG_PACKAGE_ruby-irb is not set
# CONFIG_PACKAGE_ruby-json is not set
# CONFIG_PACKAGE_ruby-logger is not set
# CONFIG_PACKAGE_ruby-matrix is not set
# CONFIG_PACKAGE_ruby-minitest is not set
# CONFIG_PACKAGE_ruby-mkmf is not set
# CONFIG_PACKAGE_ruby-monitor is not set
# CONFIG_PACKAGE_ruby-mutex_m is not set
# CONFIG_PACKAGE_ruby-net-ftp is not set
# CONFIG_PACKAGE_ruby-net-http is not set
# CONFIG_PACKAGE_ruby-net-imap is not set
# CONFIG_PACKAGE_ruby-net-pop is not set
# CONFIG_PACKAGE_ruby-net-protocol is not set
# CONFIG_PACKAGE_ruby-net-smtp is not set
# CONFIG_PACKAGE_ruby-nkf is not set
# CONFIG_PACKAGE_ruby-objspace is not set
# CONFIG_PACKAGE_ruby-observer is not set
# CONFIG_PACKAGE_ruby-open-uri is not set
# CONFIG_PACKAGE_ruby-open3 is not set
# CONFIG_PACKAGE_ruby-openssl is not set
# CONFIG_PACKAGE_ruby-optparse is not set
# CONFIG_PACKAGE_ruby-ostruct is not set
# CONFIG_PACKAGE_ruby-pathname is not set
# CONFIG_PACKAGE_ruby-powerassert is not set
# CONFIG_PACKAGE_ruby-pp is not set
# CONFIG_PACKAGE_ruby-prettyprint is not set
# CONFIG_PACKAGE_ruby-prime is not set
CONFIG_PACKAGE_ruby-pstore=y
CONFIG_PACKAGE_ruby-psych=y
# CONFIG_PACKAGE_ruby-pty is not set
# CONFIG_PACKAGE_ruby-racc is not set
# CONFIG_PACKAGE_ruby-rake is not set
# CONFIG_PACKAGE_ruby-random_formatter is not set
# CONFIG_PACKAGE_ruby-rbconfig is not set
# CONFIG_PACKAGE_ruby-rbs is not set
# CONFIG_PACKAGE_ruby-rdoc is not set
# CONFIG_PACKAGE_ruby-readline is not set
# CONFIG_PACKAGE_ruby-readline-ext is not set
# CONFIG_PACKAGE_ruby-reline is not set
# CONFIG_PACKAGE_ruby-resolv is not set
# CONFIG_PACKAGE_ruby-resolv-replace is not set
# CONFIG_PACKAGE_ruby-rexml is not set
# CONFIG_PACKAGE_ruby-rinda is not set
# CONFIG_PACKAGE_ruby-ripper is not set
# CONFIG_PACKAGE_ruby-rss is not set
# CONFIG_PACKAGE_ruby-ruby2_keywords is not set
# CONFIG_PACKAGE_ruby-securerandom is not set
# CONFIG_PACKAGE_ruby-set is not set
# CONFIG_PACKAGE_ruby-shellwords is not set
# CONFIG_PACKAGE_ruby-singleton is not set
# CONFIG_PACKAGE_ruby-socket is not set
CONFIG_PACKAGE_ruby-stringio=y
CONFIG_PACKAGE_ruby-strscan=y
# CONFIG_PACKAGE_ruby-syslog is not set
# CONFIG_PACKAGE_ruby-tempfile is not set
# CONFIG_PACKAGE_ruby-testunit is not set
# CONFIG_PACKAGE_ruby-time is not set
# CONFIG_PACKAGE_ruby-timeout is not set
# CONFIG_PACKAGE_ruby-tmpdir is not set
# CONFIG_PACKAGE_ruby-tsort is not set
# CONFIG_PACKAGE_ruby-typeprof is not set
# CONFIG_PACKAGE_ruby-un is not set
# CONFIG_PACKAGE_ruby-unicodenormalize is not set
# CONFIG_PACKAGE_ruby-uri is not set
# CONFIG_PACKAGE_ruby-weakref is not set
CONFIG_PACKAGE_ruby-yaml=y
# CONFIG_PACKAGE_ruby-zlib is not set
# end of Ruby

#
# Tcl
#
# CONFIG_PACKAGE_tcl is not set
# end of Tcl

# CONFIG_PACKAGE_chicken-scheme-full is not set
# CONFIG_PACKAGE_chicken-scheme-interpreter is not set
# CONFIG_PACKAGE_python3-gensio is not set
# CONFIG_PACKAGE_slsh is not set
# end of Languages

#
# Libraries
#

#
# Compression
#
# CONFIG_PACKAGE_libbz2 is not set
# CONFIG_PACKAGE_liblz4 is not set
# CONFIG_PACKAGE_liblzma is not set
# CONFIG_PACKAGE_libunrar is not set
# CONFIG_PACKAGE_libzip-gnutls is not set
# CONFIG_PACKAGE_libzip-mbedtls is not set
# CONFIG_PACKAGE_libzip-nossl is not set
# CONFIG_PACKAGE_libzip-openssl is not set
# CONFIG_PACKAGE_libzstd is not set
# end of Compression

#
# Database
#
# CONFIG_PACKAGE_libmariadb is not set
# CONFIG_PACKAGE_libpq is not set
# CONFIG_PACKAGE_libpqxx is not set
# CONFIG_PACKAGE_libsqlite3 is not set
# CONFIG_PACKAGE_pgsqlodbc is not set
# CONFIG_PACKAGE_psqlodbca is not set
# CONFIG_PACKAGE_psqlodbcw is not set
# CONFIG_PACKAGE_redis-cli is not set
# CONFIG_PACKAGE_redis-server is not set
# CONFIG_PACKAGE_redis-utils is not set
# CONFIG_PACKAGE_tdb is not set
# CONFIG_PACKAGE_unixodbc is not set
# end of Database

#
# Filesystem
#
# CONFIG_PACKAGE_libacl is not set
# CONFIG_PACKAGE_libattr is not set
# CONFIG_PACKAGE_libfuse is not set
# CONFIG_PACKAGE_libfuse3 is not set
# CONFIG_PACKAGE_libow is not set
# CONFIG_PACKAGE_libow-capi is not set
# CONFIG_PACKAGE_libsysfs is not set
# end of Filesystem

#
# Firewall
#
# CONFIG_PACKAGE_libfko is not set
CONFIG_PACKAGE_libip4tc=y
CONFIG_PACKAGE_libip6tc=y
CONFIG_PACKAGE_libiptext=y
# CONFIG_PACKAGE_libiptext-nft is not set
CONFIG_PACKAGE_libiptext6=y
CONFIG_PACKAGE_libxtables=y
# CONFIG_IPTABLES_CONNLABEL is not set
# end of Firewall

#
# Instant Messaging
#
# CONFIG_PACKAGE_quasselc is not set
# end of Instant Messaging

#
# IoT
#
# CONFIG_PACKAGE_libmraa is not set
# CONFIG_PACKAGE_libmraa-python3 is not set
# CONFIG_PACKAGE_libupm is not set
# CONFIG_PACKAGE_libupm-a110x is not set
# CONFIG_PACKAGE_libupm-a110x-python3 is not set
# CONFIG_PACKAGE_libupm-abp is not set
# CONFIG_PACKAGE_libupm-abp-python3 is not set
# CONFIG_PACKAGE_libupm-ad8232 is not set
# CONFIG_PACKAGE_libupm-ad8232-python3 is not set
# CONFIG_PACKAGE_libupm-adafruitms1438 is not set
# CONFIG_PACKAGE_libupm-adafruitms1438-python3 is not set
# CONFIG_PACKAGE_libupm-adafruitss is not set
# CONFIG_PACKAGE_libupm-adafruitss-python3 is not set
# CONFIG_PACKAGE_libupm-adc121c021 is not set
# CONFIG_PACKAGE_libupm-adc121c021-python3 is not set
# CONFIG_PACKAGE_libupm-adis16448 is not set
# CONFIG_PACKAGE_libupm-adis16448-python3 is not set
# CONFIG_PACKAGE_libupm-ads1x15 is not set
# CONFIG_PACKAGE_libupm-ads1x15-python3 is not set
# CONFIG_PACKAGE_libupm-adxl335 is not set
# CONFIG_PACKAGE_libupm-adxl335-python3 is not set
# CONFIG_PACKAGE_libupm-adxl345 is not set
# CONFIG_PACKAGE_libupm-adxl345-python3 is not set
# CONFIG_PACKAGE_libupm-adxrs610 is not set
# CONFIG_PACKAGE_libupm-adxrs610-python3 is not set
# CONFIG_PACKAGE_libupm-am2315 is not set
# CONFIG_PACKAGE_libupm-am2315-python3 is not set
# CONFIG_PACKAGE_libupm-apa102 is not set
# CONFIG_PACKAGE_libupm-apa102-python3 is not set
# CONFIG_PACKAGE_libupm-apds9002 is not set
# CONFIG_PACKAGE_libupm-apds9002-python3 is not set
# CONFIG_PACKAGE_libupm-apds9930 is not set
# CONFIG_PACKAGE_libupm-apds9930-python3 is not set
# CONFIG_PACKAGE_libupm-at42qt1070 is not set
# CONFIG_PACKAGE_libupm-at42qt1070-python3 is not set
# CONFIG_PACKAGE_libupm-bh1749 is not set
# CONFIG_PACKAGE_libupm-bh1749-python3 is not set
# CONFIG_PACKAGE_libupm-bh1750 is not set
# CONFIG_PACKAGE_libupm-bh1750-python3 is not set
# CONFIG_PACKAGE_libupm-bh1792 is not set
# CONFIG_PACKAGE_libupm-bh1792-python3 is not set
# CONFIG_PACKAGE_libupm-biss0001 is not set
# CONFIG_PACKAGE_libupm-biss0001-python3 is not set
# CONFIG_PACKAGE_libupm-bma220 is not set
# CONFIG_PACKAGE_libupm-bma220-python3 is not set
# CONFIG_PACKAGE_libupm-bma250e is not set
# CONFIG_PACKAGE_libupm-bma250e-python3 is not set
# CONFIG_PACKAGE_libupm-bmg160 is not set
# CONFIG_PACKAGE_libupm-bmg160-python3 is not set
# CONFIG_PACKAGE_libupm-bmi160 is not set
# CONFIG_PACKAGE_libupm-bmi160-python3 is not set
# CONFIG_PACKAGE_libupm-bmm150 is not set
# CONFIG_PACKAGE_libupm-bmm150-python3 is not set
# CONFIG_PACKAGE_libupm-bmp280 is not set
# CONFIG_PACKAGE_libupm-bmp280-python3 is not set
# CONFIG_PACKAGE_libupm-bmpx8x is not set
# CONFIG_PACKAGE_libupm-bmpx8x-python3 is not set
# CONFIG_PACKAGE_libupm-bmx055 is not set
# CONFIG_PACKAGE_libupm-bmx055-python3 is not set
# CONFIG_PACKAGE_libupm-bno055 is not set
# CONFIG_PACKAGE_libupm-bno055-python3 is not set
# CONFIG_PACKAGE_libupm-button is not set
# CONFIG_PACKAGE_libupm-button-python3 is not set
# CONFIG_PACKAGE_libupm-buzzer is not set
# CONFIG_PACKAGE_libupm-buzzer-python3 is not set
# CONFIG_PACKAGE_libupm-cjq4435 is not set
# CONFIG_PACKAGE_libupm-cjq4435-python3 is not set
# CONFIG_PACKAGE_libupm-collision is not set
# CONFIG_PACKAGE_libupm-collision-python3 is not set
# CONFIG_PACKAGE_libupm-curieimu is not set
# CONFIG_PACKAGE_libupm-curieimu-python3 is not set
# CONFIG_PACKAGE_libupm-cwlsxxa is not set
# CONFIG_PACKAGE_libupm-cwlsxxa-python3 is not set
# CONFIG_PACKAGE_libupm-dfrec is not set
# CONFIG_PACKAGE_libupm-dfrec-python3 is not set
# CONFIG_PACKAGE_libupm-dfrorp is not set
# CONFIG_PACKAGE_libupm-dfrorp-python3 is not set
# CONFIG_PACKAGE_libupm-dfrph is not set
# CONFIG_PACKAGE_libupm-dfrph-python3 is not set
# CONFIG_PACKAGE_libupm-ds1307 is not set
# CONFIG_PACKAGE_libupm-ds1307-python3 is not set
# CONFIG_PACKAGE_libupm-ds1808lc is not set
# CONFIG_PACKAGE_libupm-ds1808lc-python3 is not set
# CONFIG_PACKAGE_libupm-ds18b20 is not set
# CONFIG_PACKAGE_libupm-ds18b20-python3 is not set
# CONFIG_PACKAGE_libupm-ds2413 is not set
# CONFIG_PACKAGE_libupm-ds2413-python3 is not set
# CONFIG_PACKAGE_libupm-ecezo is not set
# CONFIG_PACKAGE_libupm-ecezo-python3 is not set
# CONFIG_PACKAGE_libupm-ecs1030 is not set
# CONFIG_PACKAGE_libupm-ecs1030-python3 is not set
# CONFIG_PACKAGE_libupm-ehr is not set
# CONFIG_PACKAGE_libupm-ehr-python3 is not set
# CONFIG_PACKAGE_libupm-eldriver is not set
# CONFIG_PACKAGE_libupm-eldriver-python3 is not set
# CONFIG_PACKAGE_libupm-electromagnet is not set
# CONFIG_PACKAGE_libupm-electromagnet-python3 is not set
# CONFIG_PACKAGE_libupm-emg is not set
# CONFIG_PACKAGE_libupm-emg-python3 is not set
# CONFIG_PACKAGE_libupm-enc03r is not set
# CONFIG_PACKAGE_libupm-enc03r-python3 is not set
# CONFIG_PACKAGE_libupm-flex is not set
# CONFIG_PACKAGE_libupm-flex-python3 is not set
# CONFIG_PACKAGE_libupm-gas is not set
# CONFIG_PACKAGE_libupm-gas-python3 is not set
# CONFIG_PACKAGE_libupm-gp2y0a is not set
# CONFIG_PACKAGE_libupm-gp2y0a-python3 is not set
# CONFIG_PACKAGE_libupm-gprs is not set
# CONFIG_PACKAGE_libupm-gprs-python3 is not set
# CONFIG_PACKAGE_libupm-gsr is not set
# CONFIG_PACKAGE_libupm-gsr-python3 is not set
# CONFIG_PACKAGE_libupm-guvas12d is not set
# CONFIG_PACKAGE_libupm-guvas12d-python3 is not set
# CONFIG_PACKAGE_libupm-h3lis331dl is not set
# CONFIG_PACKAGE_libupm-h3lis331dl-python3 is not set
# CONFIG_PACKAGE_libupm-h803x is not set
# CONFIG_PACKAGE_libupm-h803x-python3 is not set
# CONFIG_PACKAGE_libupm-hcsr04 is not set
# CONFIG_PACKAGE_libupm-hcsr04-python3 is not set
# CONFIG_PACKAGE_libupm-hdc1000 is not set
# CONFIG_PACKAGE_libupm-hdc1000-python3 is not set
# CONFIG_PACKAGE_libupm-hdxxvxta is not set
# CONFIG_PACKAGE_libupm-hdxxvxta-python3 is not set
# CONFIG_PACKAGE_libupm-hka5 is not set
# CONFIG_PACKAGE_libupm-hka5-python3 is not set
# CONFIG_PACKAGE_libupm-hlg150h is not set
# CONFIG_PACKAGE_libupm-hlg150h-python3 is not set
# CONFIG_PACKAGE_libupm-hm11 is not set
# CONFIG_PACKAGE_libupm-hm11-python3 is not set
# CONFIG_PACKAGE_libupm-hmc5883l is not set
# CONFIG_PACKAGE_libupm-hmc5883l-python3 is not set
# CONFIG_PACKAGE_libupm-hmtrp is not set
# CONFIG_PACKAGE_libupm-hmtrp-python3 is not set
# CONFIG_PACKAGE_libupm-hp20x is not set
# CONFIG_PACKAGE_libupm-hp20x-python3 is not set
# CONFIG_PACKAGE_libupm-ht9170 is not set
# CONFIG_PACKAGE_libupm-ht9170-python3 is not set
# CONFIG_PACKAGE_libupm-htu21d is not set
# CONFIG_PACKAGE_libupm-htu21d-python3 is not set
# CONFIG_PACKAGE_libupm-hwxpxx is not set
# CONFIG_PACKAGE_libupm-hwxpxx-python3 is not set
# CONFIG_PACKAGE_libupm-hx711 is not set
# CONFIG_PACKAGE_libupm-hx711-python3 is not set
# CONFIG_PACKAGE_libupm-ili9341 is not set
# CONFIG_PACKAGE_libupm-ili9341-python3 is not set
# CONFIG_PACKAGE_libupm-ims is not set
# CONFIG_PACKAGE_libupm-ims-python3 is not set
# CONFIG_PACKAGE_libupm-ina132 is not set
# CONFIG_PACKAGE_libupm-ina132-python3 is not set
# CONFIG_PACKAGE_libupm-interfaces is not set
# CONFIG_PACKAGE_libupm-interfaces-python3 is not set
# CONFIG_PACKAGE_libupm-isd1820 is not set
# CONFIG_PACKAGE_libupm-isd1820-python3 is not set
# CONFIG_PACKAGE_libupm-itg3200 is not set
# CONFIG_PACKAGE_libupm-itg3200-python3 is not set
# CONFIG_PACKAGE_libupm-jhd1313m1 is not set
# CONFIG_PACKAGE_libupm-jhd1313m1-python3 is not set
# CONFIG_PACKAGE_libupm-joystick12 is not set
# CONFIG_PACKAGE_libupm-joystick12-python3 is not set
# CONFIG_PACKAGE_libupm-kx122 is not set
# CONFIG_PACKAGE_libupm-kx122-python3 is not set
# CONFIG_PACKAGE_libupm-kxcjk1013 is not set
# CONFIG_PACKAGE_libupm-kxcjk1013-python3 is not set
# CONFIG_PACKAGE_libupm-kxtj3 is not set
# CONFIG_PACKAGE_libupm-kxtj3-python3 is not set
# CONFIG_PACKAGE_libupm-l298 is not set
# CONFIG_PACKAGE_libupm-l298-python3 is not set
# CONFIG_PACKAGE_libupm-l3gd20 is not set
# CONFIG_PACKAGE_libupm-l3gd20-python3 is not set
# CONFIG_PACKAGE_libupm-lcd is not set
# CONFIG_PACKAGE_libupm-lcd-python3 is not set
# CONFIG_PACKAGE_libupm-lcdks is not set
# CONFIG_PACKAGE_libupm-lcdks-python3 is not set
# CONFIG_PACKAGE_libupm-lcm1602 is not set
# CONFIG_PACKAGE_libupm-lcm1602-python3 is not set
# CONFIG_PACKAGE_libupm-ldt0028 is not set
# CONFIG_PACKAGE_libupm-ldt0028-python3 is not set
# CONFIG_PACKAGE_libupm-led is not set
# CONFIG_PACKAGE_libupm-led-python3 is not set
# CONFIG_PACKAGE_libupm-lidarlitev3 is not set
# CONFIG_PACKAGE_libupm-lidarlitev3-python3 is not set
# CONFIG_PACKAGE_libupm-light is not set
# CONFIG_PACKAGE_libupm-light-python3 is not set
# CONFIG_PACKAGE_libupm-linefinder is not set
# CONFIG_PACKAGE_libupm-linefinder-python3 is not set
# CONFIG_PACKAGE_libupm-lis2ds12 is not set
# CONFIG_PACKAGE_libupm-lis2ds12-python3 is not set
# CONFIG_PACKAGE_libupm-lis3dh is not set
# CONFIG_PACKAGE_libupm-lis3dh-python3 is not set
# CONFIG_PACKAGE_libupm-lm35 is not set
# CONFIG_PACKAGE_libupm-lm35-python3 is not set
# CONFIG_PACKAGE_libupm-lol is not set
# CONFIG_PACKAGE_libupm-lol-python3 is not set
# CONFIG_PACKAGE_libupm-loudness is not set
# CONFIG_PACKAGE_libupm-loudness-python3 is not set
# CONFIG_PACKAGE_libupm-lp8860 is not set
# CONFIG_PACKAGE_libupm-lp8860-python3 is not set
# CONFIG_PACKAGE_libupm-lpd8806 is not set
# CONFIG_PACKAGE_libupm-lpd8806-python3 is not set
# CONFIG_PACKAGE_libupm-lsm303agr is not set
# CONFIG_PACKAGE_libupm-lsm303agr-python3 is not set
# CONFIG_PACKAGE_libupm-lsm303d is not set
# CONFIG_PACKAGE_libupm-lsm303d-python3 is not set
# CONFIG_PACKAGE_libupm-lsm303dlh is not set
# CONFIG_PACKAGE_libupm-lsm303dlh-python3 is not set
# CONFIG_PACKAGE_libupm-lsm6ds3h is not set
# CONFIG_PACKAGE_libupm-lsm6ds3h-python3 is not set
# CONFIG_PACKAGE_libupm-lsm6dsl is not set
# CONFIG_PACKAGE_libupm-lsm6dsl-python3 is not set
# CONFIG_PACKAGE_libupm-lsm9ds0 is not set
# CONFIG_PACKAGE_libupm-lsm9ds0-python3 is not set
# CONFIG_PACKAGE_libupm-m24lr64e is not set
# CONFIG_PACKAGE_libupm-m24lr64e-python3 is not set
# CONFIG_PACKAGE_libupm-mag3110 is not set
# CONFIG_PACKAGE_libupm-mag3110-python3 is not set
# CONFIG_PACKAGE_libupm-max30100 is not set
# CONFIG_PACKAGE_libupm-max30100-python3 is not set
# CONFIG_PACKAGE_libupm-max31723 is not set
# CONFIG_PACKAGE_libupm-max31723-python3 is not set
# CONFIG_PACKAGE_libupm-max31855 is not set
# CONFIG_PACKAGE_libupm-max31855-python3 is not set
# CONFIG_PACKAGE_libupm-max44000 is not set
# CONFIG_PACKAGE_libupm-max44000-python3 is not set
# CONFIG_PACKAGE_libupm-max44009 is not set
# CONFIG_PACKAGE_libupm-max44009-python3 is not set
# CONFIG_PACKAGE_libupm-max5487 is not set
# CONFIG_PACKAGE_libupm-max5487-python3 is not set
# CONFIG_PACKAGE_libupm-maxds3231m is not set
# CONFIG_PACKAGE_libupm-maxds3231m-python3 is not set
# CONFIG_PACKAGE_libupm-maxsonarez is not set
# CONFIG_PACKAGE_libupm-maxsonarez-python3 is not set
# CONFIG_PACKAGE_libupm-mb704x is not set
# CONFIG_PACKAGE_libupm-mb704x-python3 is not set
# CONFIG_PACKAGE_libupm-mcp2515 is not set
# CONFIG_PACKAGE_libupm-mcp2515-python3 is not set
# CONFIG_PACKAGE_libupm-mcp9808 is not set
# CONFIG_PACKAGE_libupm-mcp9808-python3 is not set
# CONFIG_PACKAGE_libupm-md is not set
# CONFIG_PACKAGE_libupm-md-python3 is not set
# CONFIG_PACKAGE_libupm-mg811 is not set
# CONFIG_PACKAGE_libupm-mg811-python3 is not set
# CONFIG_PACKAGE_libupm-mhz16 is not set
# CONFIG_PACKAGE_libupm-mhz16-python3 is not set
# CONFIG_PACKAGE_libupm-mic is not set
# CONFIG_PACKAGE_libupm-mic-python3 is not set
# CONFIG_PACKAGE_libupm-micsv89 is not set
# CONFIG_PACKAGE_libupm-micsv89-python3 is not set
# CONFIG_PACKAGE_libupm-mlx90614 is not set
# CONFIG_PACKAGE_libupm-mlx90614-python3 is not set
# CONFIG_PACKAGE_libupm-mma7361 is not set
# CONFIG_PACKAGE_libupm-mma7361-python3 is not set
# CONFIG_PACKAGE_libupm-mma7455 is not set
# CONFIG_PACKAGE_libupm-mma7455-python3 is not set
# CONFIG_PACKAGE_libupm-mma7660 is not set
# CONFIG_PACKAGE_libupm-mma7660-python3 is not set
# CONFIG_PACKAGE_libupm-mma8x5x is not set
# CONFIG_PACKAGE_libupm-mma8x5x-python3 is not set
# CONFIG_PACKAGE_libupm-mmc35240 is not set
# CONFIG_PACKAGE_libupm-mmc35240-python3 is not set
# CONFIG_PACKAGE_libupm-moisture is not set
# CONFIG_PACKAGE_libupm-moisture-python3 is not set
# CONFIG_PACKAGE_libupm-mpl3115a2 is not set
# CONFIG_PACKAGE_libupm-mpl3115a2-python3 is not set
# CONFIG_PACKAGE_libupm-mpr121 is not set
# CONFIG_PACKAGE_libupm-mpr121-python3 is not set
# CONFIG_PACKAGE_libupm-mpu9150 is not set
# CONFIG_PACKAGE_libupm-mpu9150-python3 is not set
# CONFIG_PACKAGE_libupm-mq303a is not set
# CONFIG_PACKAGE_libupm-mq303a-python3 is not set
# CONFIG_PACKAGE_libupm-ms5611 is not set
# CONFIG_PACKAGE_libupm-ms5611-python3 is not set
# CONFIG_PACKAGE_libupm-ms5803 is not set
# CONFIG_PACKAGE_libupm-ms5803-python3 is not set
# CONFIG_PACKAGE_libupm-my9221 is not set
# CONFIG_PACKAGE_libupm-my9221-python3 is not set
# CONFIG_PACKAGE_libupm-nlgpio16 is not set
# CONFIG_PACKAGE_libupm-nlgpio16-python3 is not set
# CONFIG_PACKAGE_libupm-nmea_gps is not set
# CONFIG_PACKAGE_libupm-nmea_gps-python3 is not set
# CONFIG_PACKAGE_libupm-nrf24l01 is not set
# CONFIG_PACKAGE_libupm-nrf24l01-python3 is not set
# CONFIG_PACKAGE_libupm-nrf8001 is not set
# CONFIG_PACKAGE_libupm-nrf8001-python3 is not set
# CONFIG_PACKAGE_libupm-nunchuck is not set
# CONFIG_PACKAGE_libupm-nunchuck-python3 is not set
# CONFIG_PACKAGE_libupm-o2 is not set
# CONFIG_PACKAGE_libupm-o2-python3 is not set
# CONFIG_PACKAGE_libupm-otp538u is not set
# CONFIG_PACKAGE_libupm-otp538u-python3 is not set
# CONFIG_PACKAGE_libupm-ozw is not set
# CONFIG_PACKAGE_libupm-ozw-python3 is not set
# CONFIG_PACKAGE_libupm-p9813 is not set
# CONFIG_PACKAGE_libupm-p9813-python3 is not set
# CONFIG_PACKAGE_libupm-pca9685 is not set
# CONFIG_PACKAGE_libupm-pca9685-python3 is not set
# CONFIG_PACKAGE_libupm-pn532 is not set
# CONFIG_PACKAGE_libupm-pn532-python3 is not set
# CONFIG_PACKAGE_libupm-ppd42ns is not set
# CONFIG_PACKAGE_libupm-ppd42ns-python3 is not set
# CONFIG_PACKAGE_libupm-pulsensor is not set
# CONFIG_PACKAGE_libupm-pulsensor-python3 is not set
# CONFIG_PACKAGE_libupm-relay is not set
# CONFIG_PACKAGE_libupm-relay-python3 is not set
# CONFIG_PACKAGE_libupm-rf22 is not set
# CONFIG_PACKAGE_libupm-rf22-python3 is not set
# CONFIG_PACKAGE_libupm-rfr359f is not set
# CONFIG_PACKAGE_libupm-rfr359f-python3 is not set
# CONFIG_PACKAGE_libupm-rgbringcoder is not set
# CONFIG_PACKAGE_libupm-rgbringcoder-python3 is not set
# CONFIG_PACKAGE_libupm-rhusb is not set
# CONFIG_PACKAGE_libupm-rhusb-python3 is not set
# CONFIG_PACKAGE_libupm-rn2903 is not set
# CONFIG_PACKAGE_libupm-rn2903-python3 is not set
# CONFIG_PACKAGE_libupm-rotary is not set
# CONFIG_PACKAGE_libupm-rotary-python3 is not set
# CONFIG_PACKAGE_libupm-rotaryencoder is not set
# CONFIG_PACKAGE_libupm-rotaryencoder-python3 is not set
# CONFIG_PACKAGE_libupm-rpr220 is not set
# CONFIG_PACKAGE_libupm-rpr220-python3 is not set
# CONFIG_PACKAGE_libupm-rsc is not set
# CONFIG_PACKAGE_libupm-rsc-python3 is not set
# CONFIG_PACKAGE_libupm-scam is not set
# CONFIG_PACKAGE_libupm-scam-python3 is not set
# CONFIG_PACKAGE_libupm-sensortemplate is not set
# CONFIG_PACKAGE_libupm-sensortemplate-python3 is not set
# CONFIG_PACKAGE_libupm-servo is not set
# CONFIG_PACKAGE_libupm-servo-python3 is not set
# CONFIG_PACKAGE_libupm-sht1x is not set
# CONFIG_PACKAGE_libupm-sht1x-python3 is not set
# CONFIG_PACKAGE_libupm-si1132 is not set
# CONFIG_PACKAGE_libupm-si1132-python3 is not set
# CONFIG_PACKAGE_libupm-si114x is not set
# CONFIG_PACKAGE_libupm-si114x-python3 is not set
# CONFIG_PACKAGE_libupm-si7005 is not set
# CONFIG_PACKAGE_libupm-si7005-python3 is not set
# CONFIG_PACKAGE_libupm-slide is not set
# CONFIG_PACKAGE_libupm-slide-python3 is not set
# CONFIG_PACKAGE_libupm-sm130 is not set
# CONFIG_PACKAGE_libupm-sm130-python3 is not set
# CONFIG_PACKAGE_libupm-smartdrive is not set
# CONFIG_PACKAGE_libupm-smartdrive-python3 is not set
# CONFIG_PACKAGE_libupm-speaker is not set
# CONFIG_PACKAGE_libupm-speaker-python3 is not set
# CONFIG_PACKAGE_libupm-ssd1351 is not set
# CONFIG_PACKAGE_libupm-ssd1351-python3 is not set
# CONFIG_PACKAGE_libupm-st7735 is not set
# CONFIG_PACKAGE_libupm-st7735-python3 is not set
# CONFIG_PACKAGE_libupm-stepmotor is not set
# CONFIG_PACKAGE_libupm-stepmotor-python3 is not set
# CONFIG_PACKAGE_libupm-sx1276 is not set
# CONFIG_PACKAGE_libupm-sx1276-python3 is not set
# CONFIG_PACKAGE_libupm-sx6119 is not set
# CONFIG_PACKAGE_libupm-sx6119-python3 is not set
# CONFIG_PACKAGE_libupm-t3311 is not set
# CONFIG_PACKAGE_libupm-t3311-python3 is not set
# CONFIG_PACKAGE_libupm-t6713 is not set
# CONFIG_PACKAGE_libupm-t6713-python3 is not set
# CONFIG_PACKAGE_libupm-ta12200 is not set
# CONFIG_PACKAGE_libupm-ta12200-python3 is not set
# CONFIG_PACKAGE_libupm-tca9548a is not set
# CONFIG_PACKAGE_libupm-tca9548a-python3 is not set
# CONFIG_PACKAGE_libupm-tcs3414cs is not set
# CONFIG_PACKAGE_libupm-tcs3414cs-python3 is not set
# CONFIG_PACKAGE_libupm-tcs37727 is not set
# CONFIG_PACKAGE_libupm-tcs37727-python3 is not set
# CONFIG_PACKAGE_libupm-teams is not set
# CONFIG_PACKAGE_libupm-teams-python3 is not set
# CONFIG_PACKAGE_libupm-temperature is not set
# CONFIG_PACKAGE_libupm-temperature-python3 is not set
# CONFIG_PACKAGE_libupm-tex00 is not set
# CONFIG_PACKAGE_libupm-tex00-python3 is not set
# CONFIG_PACKAGE_libupm-th02 is not set
# CONFIG_PACKAGE_libupm-th02-python3 is not set
# CONFIG_PACKAGE_libupm-tm1637 is not set
# CONFIG_PACKAGE_libupm-tm1637-python3 is not set
# CONFIG_PACKAGE_libupm-tmp006 is not set
# CONFIG_PACKAGE_libupm-tmp006-python3 is not set
# CONFIG_PACKAGE_libupm-tsl2561 is not set
# CONFIG_PACKAGE_libupm-tsl2561-python3 is not set
# CONFIG_PACKAGE_libupm-ttp223 is not set
# CONFIG_PACKAGE_libupm-ttp223-python3 is not set
# CONFIG_PACKAGE_libupm-uartat is not set
# CONFIG_PACKAGE_libupm-uartat-python3 is not set
# CONFIG_PACKAGE_libupm-uln200xa is not set
# CONFIG_PACKAGE_libupm-uln200xa-python3 is not set
# CONFIG_PACKAGE_libupm-ultrasonic is not set
# CONFIG_PACKAGE_libupm-ultrasonic-python3 is not set
# CONFIG_PACKAGE_libupm-urm37 is not set
# CONFIG_PACKAGE_libupm-urm37-python3 is not set
# CONFIG_PACKAGE_libupm-utilities is not set
# CONFIG_PACKAGE_libupm-utilities-python3 is not set
# CONFIG_PACKAGE_libupm-vcap is not set
# CONFIG_PACKAGE_libupm-vcap-python3 is not set
# CONFIG_PACKAGE_libupm-vdiv is not set
# CONFIG_PACKAGE_libupm-vdiv-python3 is not set
# CONFIG_PACKAGE_libupm-veml6070 is not set
# CONFIG_PACKAGE_libupm-veml6070-python3 is not set
# CONFIG_PACKAGE_libupm-water is not set
# CONFIG_PACKAGE_libupm-water-python3 is not set
# CONFIG_PACKAGE_libupm-waterlevel is not set
# CONFIG_PACKAGE_libupm-waterlevel-python3 is not set
# CONFIG_PACKAGE_libupm-wfs is not set
# CONFIG_PACKAGE_libupm-wfs-python3 is not set
# CONFIG_PACKAGE_libupm-wheelencoder is not set
# CONFIG_PACKAGE_libupm-wheelencoder-python3 is not set
# CONFIG_PACKAGE_libupm-wt5001 is not set
# CONFIG_PACKAGE_libupm-wt5001-python3 is not set
# CONFIG_PACKAGE_libupm-xbee is not set
# CONFIG_PACKAGE_libupm-xbee-python3 is not set
# CONFIG_PACKAGE_libupm-yg1006 is not set
# CONFIG_PACKAGE_libupm-yg1006-python3 is not set
# CONFIG_PACKAGE_libupm-zfm20 is not set
# CONFIG_PACKAGE_libupm-zfm20-python3 is not set
# end of IoT

#
# Languages
#
CONFIG_PACKAGE_libyaml=y
# end of Languages

#
# LibElektra
#
# CONFIG_PACKAGE_libelektra-core is not set
# CONFIG_PACKAGE_libelektra-cpp is not set
# CONFIG_PACKAGE_libelektra-crypto is not set
# CONFIG_PACKAGE_libelektra-curlget is not set
# CONFIG_PACKAGE_libelektra-dbus is not set
# CONFIG_PACKAGE_libelektra-ev is not set
# CONFIG_PACKAGE_libelektra-extra is not set
# CONFIG_PACKAGE_libelektra-lua is not set
# CONFIG_PACKAGE_libelektra-plugins is not set
# CONFIG_PACKAGE_libelektra-python3 is not set
# CONFIG_PACKAGE_libelektra-resolvers is not set
# CONFIG_PACKAGE_libelektra-uv is not set
# CONFIG_PACKAGE_libelektra-xerces is not set
# CONFIG_PACKAGE_libelektra-xml is not set
# CONFIG_PACKAGE_libelektra-yajl is not set
# CONFIG_PACKAGE_libelektra-yamlcpp is not set
# CONFIG_PACKAGE_libelektra-zmq is not set
# end of LibElektra

#
# Networking
#
# CONFIG_PACKAGE_libdcwproto is not set
# CONFIG_PACKAGE_libdcwsocket is not set
# CONFIG_PACKAGE_libsctp is not set
# CONFIG_PACKAGE_libslirp is not set
# CONFIG_PACKAGE_libuhttpd-mbedtls is not set
# CONFIG_PACKAGE_libuhttpd-nossl is not set
# CONFIG_PACKAGE_libuhttpd-openssl is not set
# CONFIG_PACKAGE_libuhttpd-wolfssl is not set
# CONFIG_PACKAGE_libulfius-gnutls is not set
# CONFIG_PACKAGE_libulfius-nossl is not set
# CONFIG_PACKAGE_libunbound is not set
# CONFIG_PACKAGE_libuwsc-mbedtls is not set
# CONFIG_PACKAGE_libuwsc-nossl is not set
# CONFIG_PACKAGE_libuwsc-openssl is not set
# CONFIG_PACKAGE_libuwsc-wolfssl is not set
# end of Networking

#
# SSL
#
CONFIG_PACKAGE_libgnutls=y

#
# Configuration
#
CONFIG_GNUTLS_DTLS_SRTP=y
CONFIG_GNUTLS_ALPN=y
CONFIG_GNUTLS_OCSP=y
# CONFIG_GNUTLS_CRYPTODEV is not set
CONFIG_GNUTLS_HEARTBEAT=y
# CONFIG_GNUTLS_SRP is not set
CONFIG_GNUTLS_PSK=y
CONFIG_GNUTLS_ANON=y
# CONFIG_GNUTLS_TPM is not set
# CONFIG_GNUTLS_PKCS11 is not set
# CONFIG_GNUTLS_EXT_LIBTASN1 is not set
# end of Configuration

# CONFIG_PACKAGE_libgnutls-dane is not set
CONFIG_PACKAGE_libmbedtls=y
# CONFIG_LIBMBEDTLS_DEBUG_C is not set
# CONFIG_LIBMBEDTLS_HKDF_C is not set
# CONFIG_PACKAGE_libnss is not set
CONFIG_PACKAGE_libopenssl=y

#
# Build Options
#
# CONFIG_OPENSSL_OPTIMIZE_SPEED is not set
CONFIG_OPENSSL_WITH_ASM=y
CONFIG_OPENSSL_WITH_DEPRECATED=y
# CONFIG_OPENSSL_NO_DEPRECATED is not set
CONFIG_OPENSSL_WITH_ERROR_MESSAGES=y

#
# Protocol Support
#
CONFIG_OPENSSL_WITH_TLS13=y
# CONFIG_OPENSSL_WITH_DTLS is not set
# CONFIG_OPENSSL_WITH_NPN is not set
CONFIG_OPENSSL_WITH_SRP=y
CONFIG_OPENSSL_WITH_CMS=y

#
# Algorithm Selection
#
# CONFIG_OPENSSL_WITH_EC2M is not set
CONFIG_OPENSSL_WITH_CHACHA_POLY1305=y
CONFIG_OPENSSL_PREFER_CHACHA_OVER_GCM=y
CONFIG_OPENSSL_WITH_PSK=y

#
# Less commonly used build options
#
# CONFIG_OPENSSL_WITH_ARIA is not set
# CONFIG_OPENSSL_WITH_CAMELLIA is not set
# CONFIG_OPENSSL_WITH_IDEA is not set
# CONFIG_OPENSSL_WITH_SEED is not set
# CONFIG_OPENSSL_WITH_SM234 is not set
# CONFIG_OPENSSL_WITH_BLAKE2 is not set
# CONFIG_OPENSSL_WITH_MDC2 is not set
# CONFIG_OPENSSL_WITH_WHIRLPOOL is not set
# CONFIG_OPENSSL_WITH_COMPRESSION is not set
# CONFIG_OPENSSL_WITH_RFC3779 is not set

#
# Engine/Hardware Support
#
CONFIG_OPENSSL_ENGINE=y
# CONFIG_OPENSSL_ENGINE_BUILTIN is not set
# CONFIG_PACKAGE_libopenssl-afalg is not set
# CONFIG_PACKAGE_libopenssl-afalg_sync is not set
CONFIG_PACKAGE_libopenssl-conf=y
# CONFIG_PACKAGE_libopenssl-devcrypto is not set
# CONFIG_PACKAGE_libopenssl-gost_engine is not set
CONFIG_PACKAGE_libwolfssl=y
CONFIG_WOLFSSL_HAS_AES_CCM=y
CONFIG_WOLFSSL_HAS_CHACHA_POLY=y
CONFIG_WOLFSSL_HAS_DH=y
CONFIG_WOLFSSL_HAS_ARC4=y
CONFIG_WOLFSSL_HAS_CERTGEN=y
CONFIG_WOLFSSL_HAS_TLSV10=y
CONFIG_WOLFSSL_HAS_TLSV13=y
CONFIG_WOLFSSL_HAS_SESSION_TICKET=y
# CONFIG_WOLFSSL_HAS_DTLS is not set
CONFIG_WOLFSSL_HAS_OCSP=y
CONFIG_WOLFSSL_HAS_WPAS=y
CONFIG_WOLFSSL_HAS_ECC25519=y
# CONFIG_WOLFSSL_HAS_ECC448 is not set
CONFIG_WOLFSSL_HAS_OPENVPN=y
CONFIG_WOLFSSL_ALT_NAMES=y
# CONFIG_WOLFSSL_ASM_CAPABLE is not set
CONFIG_WOLFSSL_HAS_NO_HW=y
# CONFIG_WOLFSSL_HAS_AFALG is not set
# CONFIG_WOLFSSL_HAS_DEVCRYPTO_CBC is not set
# CONFIG_WOLFSSL_HAS_DEVCRYPTO_AES is not set
# CONFIG_WOLFSSL_HAS_DEVCRYPTO_FULL is not set
# CONFIG_PACKAGE_libwolfssl-benchmark is not set
# end of SSL

#
# Sound
#
# CONFIG_PACKAGE_alsa-ucm-conf is not set
# CONFIG_PACKAGE_liblo is not set
# end of Sound

#
# Telephony
#
# CONFIG_PACKAGE_bcg729 is not set
# CONFIG_PACKAGE_dahdi-tools-libtonezone is not set
# CONFIG_PACKAGE_gsmlib is not set
# CONFIG_PACKAGE_libctb is not set
# CONFIG_PACKAGE_libfreetdm is not set
# CONFIG_PACKAGE_libiksemel is not set
# CONFIG_PACKAGE_libks is not set
# CONFIG_PACKAGE_libosip2 is not set
# CONFIG_PACKAGE_libpj is not set
# CONFIG_PACKAGE_libpjlib-util is not set
# CONFIG_PACKAGE_libpjmedia is not set
# CONFIG_PACKAGE_libpjnath is not set
# CONFIG_PACKAGE_libpjsip is not set
# CONFIG_PACKAGE_libpjsip-simple is not set
# CONFIG_PACKAGE_libpjsip-ua is not set
# CONFIG_PACKAGE_libpjsua is not set
# CONFIG_PACKAGE_libpjsua2 is not set
# CONFIG_PACKAGE_libre is not set
# CONFIG_PACKAGE_librem is not set
# CONFIG_PACKAGE_libspandsp is not set
# CONFIG_PACKAGE_libspandsp3 is not set
# CONFIG_PACKAGE_libsrtp2 is not set
# CONFIG_PACKAGE_signalwire-client-c is not set
# CONFIG_PACKAGE_sofia-sip is not set
# end of Telephony

#
# libimobiledevice
#
# CONFIG_PACKAGE_libimobiledevice is not set
# CONFIG_PACKAGE_libirecovery is not set
# CONFIG_PACKAGE_libplist is not set
# CONFIG_PACKAGE_libusbmuxd is not set
# end of libimobiledevice

# CONFIG_PACKAGE_acsccid is not set
# CONFIG_PACKAGE_alsa-lib is not set
# CONFIG_PACKAGE_argp-standalone is not set
# CONFIG_PACKAGE_bind-libs is not set
# CONFIG_PACKAGE_bluez-libs is not set
# CONFIG_PACKAGE_boost is not set
# CONFIG_boost-context-exclude is not set
# CONFIG_boost-coroutine-exclude is not set
# CONFIG_boost-fiber-exclude is not set
# CONFIG_PACKAGE_boringssl is not set
# CONFIG_PACKAGE_cJSON is not set
# CONFIG_PACKAGE_ccid is not set
# CONFIG_PACKAGE_check is not set
# CONFIG_PACKAGE_confuse is not set
# CONFIG_PACKAGE_czmq is not set
# CONFIG_PACKAGE_dtndht is not set
# CONFIG_PACKAGE_getdns is not set
# CONFIG_PACKAGE_giflib is not set
# CONFIG_PACKAGE_glib2 is not set
# CONFIG_PACKAGE_google-authenticator-libpam is not set
# CONFIG_PACKAGE_hidapi is not set
# CONFIG_PACKAGE_ibrcommon is not set
# CONFIG_PACKAGE_ibrdtn is not set
# CONFIG_PACKAGE_icu is not set
# CONFIG_PACKAGE_icu-data-tools is not set
# CONFIG_PACKAGE_icu-full-data is not set
CONFIG_PACKAGE_jansson=y
# CONFIG_PACKAGE_json-glib is not set
# CONFIG_PACKAGE_jsoncpp is not set
# CONFIG_PACKAGE_knot-libs is not set
# CONFIG_PACKAGE_knot-libzscanner is not set
# CONFIG_PACKAGE_libaio is not set
# CONFIG_PACKAGE_libantlr3c is not set
# CONFIG_PACKAGE_libao is not set
# CONFIG_PACKAGE_libapparmor is not set
# CONFIG_PACKAGE_libapr is not set
# CONFIG_PACKAGE_libaprutil is not set
# CONFIG_PACKAGE_libarchive is not set
# CONFIG_PACKAGE_libarchive-noopenssl is not set
# CONFIG_PACKAGE_libasm is not set
# CONFIG_PACKAGE_libassuan is not set
# CONFIG_PACKAGE_libatasmart is not set
# CONFIG_PACKAGE_libaudit is not set
# CONFIG_PACKAGE_libauparse is not set
# CONFIG_PACKAGE_libavahi-client is not set
# CONFIG_PACKAGE_libavahi-compat-libdnssd is not set
# CONFIG_PACKAGE_libavahi-dbus-support is not set
# CONFIG_PACKAGE_libavahi-nodbus-support is not set
# CONFIG_PACKAGE_libbfd is not set
CONFIG_PACKAGE_libblkid=y
CONFIG_PACKAGE_libblobmsg-json=y
CONFIG_PACKAGE_libbpf=y
# CONFIG_PACKAGE_libbsd is not set
CONFIG_PACKAGE_libcap=y
CONFIG_PACKAGE_libcap-bin=y
CONFIG_PACKAGE_libcap-bin-capsh-shell="/bin/sh"
# CONFIG_PACKAGE_libcap-ng is not set
# CONFIG_PACKAGE_libcares is not set
# CONFIG_PACKAGE_libcbor is not set
# CONFIG_PACKAGE_libcgroup is not set
# CONFIG_PACKAGE_libcharset is not set
# CONFIG_PACKAGE_libcoap is not set
CONFIG_PACKAGE_libcomerr=y
# CONFIG_PACKAGE_libconfig is not set
# CONFIG_PACKAGE_libcronet is not set
# CONFIG_PACKAGE_libctf is not set
CONFIG_PACKAGE_libcurl=y

#
# SSL support
#
CONFIG_LIBCURL_MBEDTLS=y
# CONFIG_LIBCURL_WOLFSSL is not set
# CONFIG_LIBCURL_OPENSSL is not set
# CONFIG_LIBCURL_GNUTLS is not set
# CONFIG_LIBCURL_NOSSL is not set

#
# Supported protocols
#
# CONFIG_LIBCURL_DICT is not set
CONFIG_LIBCURL_FILE=y
CONFIG_LIBCURL_FTP=y
# CONFIG_LIBCURL_GOPHER is not set
CONFIG_LIBCURL_HTTP=y
CONFIG_LIBCURL_COOKIES=y
# CONFIG_LIBCURL_IMAP is not set
# CONFIG_LIBCURL_LDAP is not set
# CONFIG_LIBCURL_POP3 is not set
# CONFIG_LIBCURL_RTSP is not set
# CONFIG_LIBCURL_SSH2 is not set
CONFIG_LIBCURL_NO_SMB="!"
# CONFIG_LIBCURL_SMTP is not set
# CONFIG_LIBCURL_TELNET is not set
# CONFIG_LIBCURL_TFTP is not set
CONFIG_LIBCURL_NGHTTP2=y

#
# Miscellaneous
#
CONFIG_LIBCURL_PROXY=y
# CONFIG_LIBCURL_CRYPTO_AUTH is not set
# CONFIG_LIBCURL_TLS_SRP is not set
# CONFIG_LIBCURL_LIBIDN2 is not set
# CONFIG_LIBCURL_THREADED_RESOLVER is not set
# CONFIG_LIBCURL_ZLIB is not set
# CONFIG_LIBCURL_ZSTD is not set
# CONFIG_LIBCURL_UNIX_SOCKETS is not set
# CONFIG_LIBCURL_LIBCURL_OPTION is not set
# CONFIG_LIBCURL_VERBOSE is not set
# CONFIG_PACKAGE_libdaemon is not set
# CONFIG_PACKAGE_libdaq is not set
# CONFIG_PACKAGE_libdaq3 is not set
# CONFIG_PACKAGE_libdb47 is not set
# CONFIG_PACKAGE_libdb47xx is not set
# CONFIG_PACKAGE_libdbi is not set
# CONFIG_PACKAGE_libdbus is not set
# CONFIG_PACKAGE_libdevmapper is not set
# CONFIG_PACKAGE_libdevmapper-selinux is not set
# CONFIG_PACKAGE_libdmapsharing is not set
# CONFIG_PACKAGE_libdnet is not set
# CONFIG_PACKAGE_libdrm is not set
# CONFIG_PACKAGE_libdw is not set
# CONFIG_PACKAGE_libecdsautil is not set
# CONFIG_PACKAGE_libedit is not set
CONFIG_PACKAGE_libelf=y
# CONFIG_PACKAGE_libesmtp is not set
# CONFIG_PACKAGE_libestr is not set
CONFIG_PACKAGE_libev=y
CONFIG_PACKAGE_libevdev=y
CONFIG_PACKAGE_libevent2=y
# CONFIG_PACKAGE_libevent2-core is not set
# CONFIG_PACKAGE_libevent2-extra is not set
# CONFIG_PACKAGE_libevent2-openssl is not set
# CONFIG_PACKAGE_libevent2-pthreads is not set
# CONFIG_PACKAGE_libexif is not set
# CONFIG_PACKAGE_libexpat is not set
# CONFIG_PACKAGE_libexslt is not set
CONFIG_PACKAGE_libext2fs=y
# CONFIG_PACKAGE_libextractor is not set
# CONFIG_PACKAGE_libf2fs is not set
# CONFIG_PACKAGE_libf2fs-selinux is not set
# CONFIG_PACKAGE_libfaad2 is not set
# CONFIG_PACKAGE_libfastjson is not set
CONFIG_PACKAGE_libfdisk=y
# CONFIG_PACKAGE_libfdt is not set
# CONFIG_PACKAGE_libffi is not set
# CONFIG_PACKAGE_libffmpeg-audio-dec is not set
# CONFIG_PACKAGE_libffmpeg-custom is not set
# CONFIG_PACKAGE_libffmpeg-full is not set
# CONFIG_PACKAGE_libffmpeg-mini is not set
# CONFIG_PACKAGE_libfido2 is not set
# CONFIG_PACKAGE_libflac is not set
# CONFIG_PACKAGE_libfmt is not set
# CONFIG_PACKAGE_libfreetype is not set
# CONFIG_PACKAGE_libfstrm is not set
# CONFIG_PACKAGE_libftdi is not set
# CONFIG_PACKAGE_libftdi1 is not set
# CONFIG_PACKAGE_libgabe is not set
CONFIG_PACKAGE_libgcrypt=y
# CONFIG_PACKAGE_libgd is not set
# CONFIG_PACKAGE_libgd-full is not set
# CONFIG_PACKAGE_libgdbm is not set
# CONFIG_PACKAGE_libgee is not set
# CONFIG_PACKAGE_libgensio is not set
# CONFIG_PACKAGE_libgensiocpp is not set
CONFIG_PACKAGE_libgmp=y
# CONFIG_PACKAGE_libgnurl is not set
CONFIG_PACKAGE_libgpg-error=y
# CONFIG_PACKAGE_libgpgme is not set
# CONFIG_PACKAGE_libgpgmepp is not set
# CONFIG_PACKAGE_libgphoto2 is not set
# CONFIG_PACKAGE_libgpiod is not set
# CONFIG_PACKAGE_libgps is not set
# CONFIG_PACKAGE_libh2o is not set
# CONFIG_PACKAGE_libh2o-evloop is not set
# CONFIG_PACKAGE_libhamlib is not set
# CONFIG_PACKAGE_libhavege is not set
# CONFIG_PACKAGE_libhiredis is not set
# CONFIG_PACKAGE_libhttp-parser is not set
# CONFIG_PACKAGE_libhwloc is not set
# CONFIG_PACKAGE_libi2c is not set
# CONFIG_PACKAGE_libical is not set
# CONFIG_PACKAGE_libiconv-full is not set
# CONFIG_PACKAGE_libid3tag is not set
# CONFIG_PACKAGE_libidn is not set
# CONFIG_PACKAGE_libidn2 is not set
# CONFIG_PACKAGE_libiio is not set
# CONFIG_PACKAGE_libinotifytools is not set
# CONFIG_PACKAGE_libinput is not set
# CONFIG_PACKAGE_libintl-full is not set
# CONFIG_PACKAGE_libipfs-http-client is not set
# CONFIG_PACKAGE_libiw is not set
CONFIG_PACKAGE_libiwinfo=y
# CONFIG_PACKAGE_libjpeg-turbo is not set
CONFIG_PACKAGE_libjson-c=y
# CONFIG_PACKAGE_libkeyutils is not set
# CONFIG_PACKAGE_libkmod is not set
# CONFIG_PACKAGE_libksba is not set
# CONFIG_PACKAGE_libldns is not set
# CONFIG_PACKAGE_libleptonica is not set
# CONFIG_PACKAGE_libloragw is not set
# CONFIG_PACKAGE_libltdl is not set
CONFIG_PACKAGE_liblua=y
# CONFIG_PACKAGE_liblua5.3 is not set
CONFIG_PACKAGE_liblucihttp=y
CONFIG_PACKAGE_liblucihttp-lua=y
# CONFIG_PACKAGE_liblucihttp-ucode is not set
# CONFIG_PACKAGE_liblzo is not set
# CONFIG_PACKAGE_libmad is not set
# CONFIG_PACKAGE_libmagic is not set
# CONFIG_PACKAGE_libmaxminddb is not set
# CONFIG_PACKAGE_libmbim is not set
# CONFIG_PACKAGE_libmcrypt is not set
# CONFIG_PACKAGE_libmicrohttpd-no-ssl is not set
# CONFIG_PACKAGE_libmicrohttpd-ssl is not set
# CONFIG_PACKAGE_libmilter-sendmail is not set
CONFIG_PACKAGE_libminiupnpc=y
# CONFIG_PACKAGE_libmms is not set
CONFIG_PACKAGE_libmnl=y
# CONFIG_PACKAGE_libmodbus is not set
# CONFIG_PACKAGE_libmosquitto-nossl is not set
# CONFIG_PACKAGE_libmosquitto-ssl is not set
CONFIG_PACKAGE_libmount=y
# CONFIG_PACKAGE_libmpdclient is not set
# CONFIG_PACKAGE_libmpeg2 is not set
# CONFIG_PACKAGE_libmpg123 is not set
CONFIG_PACKAGE_libnatpmp=y
CONFIG_PACKAGE_libncurses=y
# CONFIG_PACKAGE_libndpi is not set
# CONFIG_PACKAGE_libneon is not set
# CONFIG_PACKAGE_libnet-1.2.x is not set
# CONFIG_PACKAGE_libnetconf2 is not set
# CONFIG_PACKAGE_libnetfilter-acct is not set
CONFIG_PACKAGE_libnetfilter-conntrack=y
# CONFIG_PACKAGE_libnetfilter-cthelper is not set
# CONFIG_PACKAGE_libnetfilter-cttimeout is not set
# CONFIG_PACKAGE_libnetfilter-log is not set
# CONFIG_PACKAGE_libnetfilter-queue is not set
# CONFIG_PACKAGE_libnetsnmp is not set
CONFIG_PACKAGE_libnettle=y

#
# Configuration
#
# CONFIG_LIBNETTLE_MINI is not set
# end of Configuration

# CONFIG_PACKAGE_libnewt is not set
CONFIG_PACKAGE_libnfnetlink=y
CONFIG_PACKAGE_libnftnl=y
CONFIG_PACKAGE_libnghttp2=y
# CONFIG_PACKAGE_libnl is not set
# CONFIG_PACKAGE_libnl-core is not set
# CONFIG_PACKAGE_libnl-genl is not set
# CONFIG_PACKAGE_libnl-nf is not set
# CONFIG_PACKAGE_libnl-route is not set
CONFIG_PACKAGE_libnl-tiny=y
# CONFIG_PACKAGE_libnopoll is not set
# CONFIG_PACKAGE_libnpth is not set
# CONFIG_PACKAGE_libnpupnp is not set
# CONFIG_PACKAGE_libogg is not set
# CONFIG_PACKAGE_liboil is not set
# CONFIG_PACKAGE_libopcodes is not set
# CONFIG_PACKAGE_libopendkim is not set
# CONFIG_PACKAGE_libopenobex is not set
# CONFIG_PACKAGE_libopensc is not set
# CONFIG_PACKAGE_libopenzwave is not set
# CONFIG_PACKAGE_liboping is not set
# CONFIG_PACKAGE_libopus is not set
# CONFIG_PACKAGE_libopusenc is not set
# CONFIG_PACKAGE_libopusfile is not set
# CONFIG_PACKAGE_liborcania is not set
# CONFIG_PACKAGE_libout123 is not set
# CONFIG_PACKAGE_libowipcalc is not set
# CONFIG_PACKAGE_libp11 is not set
# CONFIG_PACKAGE_libpagekite is not set
# CONFIG_PACKAGE_libpam is not set
# CONFIG_PACKAGE_libparted is not set
# CONFIG_PACKAGE_libpbc is not set
# CONFIG_PACKAGE_libpcap is not set
# CONFIG_PACKAGE_libpci is not set
# CONFIG_PACKAGE_libpciaccess is not set
CONFIG_PACKAGE_libpcre=y
# CONFIG_PCRE_JIT_ENABLED is not set
# CONFIG_PACKAGE_libpcre16 is not set
# CONFIG_PACKAGE_libpcre2 is not set
# CONFIG_PACKAGE_libpcre2-16 is not set
# CONFIG_PACKAGE_libpcre2-32 is not set
# CONFIG_PACKAGE_libpcre32 is not set
# CONFIG_PACKAGE_libpcrecpp is not set
# CONFIG_PACKAGE_libpcsclite is not set
# CONFIG_PACKAGE_libpfring is not set
# CONFIG_PACKAGE_libpkcs11-spy is not set
# CONFIG_PACKAGE_libpkgconf is not set
# CONFIG_PACKAGE_libpng is not set
# CONFIG_PACKAGE_libpopt is not set
# CONFIG_PACKAGE_libpri is not set
# CONFIG_PACKAGE_libprotobuf-c is not set
# CONFIG_PACKAGE_libpsl is not set
# CONFIG_PACKAGE_libqmi is not set
# CONFIG_PACKAGE_libqrencode is not set
# CONFIG_PACKAGE_libqrtr-glib is not set
# CONFIG_PACKAGE_libradcli is not set
# CONFIG_PACKAGE_libradiotap is not set
CONFIG_PACKAGE_libreadline=y
# CONFIG_PACKAGE_libredblack is not set
# CONFIG_PACKAGE_librouteros is not set
# CONFIG_PACKAGE_libroxml is not set
# CONFIG_PACKAGE_librrd1 is not set
# CONFIG_PACKAGE_librtlsdr is not set
CONFIG_PACKAGE_libruby=y
# CONFIG_PACKAGE_libsamplerate is not set
# CONFIG_PACKAGE_libsane is not set
# CONFIG_PACKAGE_libsasl2 is not set
# CONFIG_PACKAGE_libsasl2-sasldb is not set
# CONFIG_PACKAGE_libseccomp is not set
# CONFIG_PACKAGE_libselinux is not set
# CONFIG_PACKAGE_libsemanage is not set
# CONFIG_PACKAGE_libsensors is not set
# CONFIG_PACKAGE_libsepol is not set
# CONFIG_PACKAGE_libshout is not set
# CONFIG_PACKAGE_libshout-full is not set
# CONFIG_PACKAGE_libshout-nossl is not set
# CONFIG_PACKAGE_libsispmctl is not set
# CONFIG_PACKAGE_libslang2 is not set
# CONFIG_PACKAGE_libslang2-mod-base64 is not set
# CONFIG_PACKAGE_libslang2-mod-chksum is not set
# CONFIG_PACKAGE_libslang2-mod-csv is not set
# CONFIG_PACKAGE_libslang2-mod-fcntl is not set
# CONFIG_PACKAGE_libslang2-mod-fork is not set
# CONFIG_PACKAGE_libslang2-mod-histogram is not set
# CONFIG_PACKAGE_libslang2-mod-iconv is not set
# CONFIG_PACKAGE_libslang2-mod-json is not set
# CONFIG_PACKAGE_libslang2-mod-onig is not set
# CONFIG_PACKAGE_libslang2-mod-pcre is not set
# CONFIG_PACKAGE_libslang2-mod-png is not set
# CONFIG_PACKAGE_libslang2-mod-rand is not set
# CONFIG_PACKAGE_libslang2-mod-select is not set
# CONFIG_PACKAGE_libslang2-mod-slsmg is not set
# CONFIG_PACKAGE_libslang2-mod-socket is not set
# CONFIG_PACKAGE_libslang2-mod-stats is not set
# CONFIG_PACKAGE_libslang2-mod-sysconf is not set
# CONFIG_PACKAGE_libslang2-mod-termios is not set
# CONFIG_PACKAGE_libslang2-mod-varray is not set
# CONFIG_PACKAGE_libslang2-mod-zlib is not set
# CONFIG_PACKAGE_libslang2-modules is not set
CONFIG_PACKAGE_libsmartcols=y
# CONFIG_PACKAGE_libsndfile is not set
# CONFIG_PACKAGE_libsoc is not set
# CONFIG_PACKAGE_libsocks is not set
CONFIG_PACKAGE_libsodium=y

#
# Configuration
#
CONFIG_LIBSODIUM_MINIMAL=y
# end of Configuration

# CONFIG_PACKAGE_libsoup is not set
# CONFIG_PACKAGE_libsoxr is not set
# CONFIG_PACKAGE_libspeex is not set
# CONFIG_PACKAGE_libspeexdsp is not set
# CONFIG_PACKAGE_libspice-server is not set
CONFIG_PACKAGE_libss=y
# CONFIG_PACKAGE_libssh is not set
# CONFIG_PACKAGE_libssh2 is not set
# CONFIG_PACKAGE_libstoken is not set
# CONFIG_PACKAGE_libstrophe is not set
# CONFIG_PACKAGE_libsyn123 is not set
# CONFIG_PACKAGE_libsysrepo is not set
# CONFIG_PACKAGE_libtalloc is not set
# CONFIG_PACKAGE_libtasn1 is not set
# CONFIG_PACKAGE_libtheora is not set
# CONFIG_PACKAGE_libtiff is not set
# CONFIG_PACKAGE_libtins is not set
# CONFIG_PACKAGE_libtirpc is not set
# CONFIG_PACKAGE_libtorrent-rasterbar is not set
CONFIG_PACKAGE_libubox=y
# CONFIG_PACKAGE_libubox-lua is not set
CONFIG_PACKAGE_libubus=y
CONFIG_PACKAGE_libubus-lua=y
CONFIG_PACKAGE_libuci=y
CONFIG_PACKAGE_libuci-lua=y
# CONFIG_PACKAGE_libuci2 is not set
CONFIG_PACKAGE_libuclient=y
CONFIG_PACKAGE_libudev-zero=y
CONFIG_PACKAGE_libudns=y
# CONFIG_PACKAGE_libuecc is not set
# CONFIG_PACKAGE_libugpio is not set
# CONFIG_PACKAGE_libunistring is not set
# CONFIG_PACKAGE_libunwind is not set
# CONFIG_PACKAGE_libupnp is not set
# CONFIG_PACKAGE_libupnpp is not set
# CONFIG_PACKAGE_liburcu is not set
# CONFIG_PACKAGE_liburing is not set
CONFIG_PACKAGE_libusb-1.0=y
# CONFIG_PACKAGE_libusb-compat is not set
# CONFIG_PACKAGE_libustream-mbedtls is not set
CONFIG_PACKAGE_libustream-openssl=y
CONFIG_PACKAGE_libustream-wolfssl=m
CONFIG_PACKAGE_libuuid=y
CONFIG_PACKAGE_libuv=y
# CONFIG_PACKAGE_libuwifi is not set
# CONFIG_PACKAGE_libv4l is not set
# CONFIG_PACKAGE_libvorbis is not set
# CONFIG_PACKAGE_libvorbisidec is not set
# CONFIG_PACKAGE_libvpx is not set
# CONFIG_PACKAGE_libwebp is not set
CONFIG_PACKAGE_libwebsockets-full=y
# CONFIG_PACKAGE_libwebsockets-mbedtls is not set
# CONFIG_PACKAGE_libwebsockets-openssl is not set
# CONFIG_PACKAGE_libwrap is not set
# CONFIG_PACKAGE_libxerces-c is not set
# CONFIG_PACKAGE_libxerces-c-samples is not set
# CONFIG_PACKAGE_libxml2 is not set
# CONFIG_PACKAGE_libxslt is not set
# CONFIG_PACKAGE_libyaml-cpp is not set
# CONFIG_PACKAGE_libyang is not set
# CONFIG_PACKAGE_libyubikey is not set
# CONFIG_PACKAGE_libzmq-curve is not set
# CONFIG_PACKAGE_libzmq-nc is not set
# CONFIG_PACKAGE_linux-atm is not set
# CONFIG_PACKAGE_lmdb is not set
# CONFIG_PACKAGE_log4cplus is not set
# CONFIG_PACKAGE_loudmouth is not set
# CONFIG_PACKAGE_lttng-ust is not set
# CONFIG_PACKAGE_minizip is not set
# CONFIG_PACKAGE_msgpack-c is not set
# CONFIG_PACKAGE_mtdev is not set
# CONFIG_PACKAGE_musl-fts is not set
# CONFIG_PACKAGE_mxml is not set
# CONFIG_PACKAGE_nspr is not set
# CONFIG_PACKAGE_oniguruma is not set
# CONFIG_PACKAGE_open-isns is not set
# CONFIG_PACKAGE_openblas is not set
# CONFIG_PACKAGE_openpgm is not set
# CONFIG_PACKAGE_p11-kit is not set
# CONFIG_PACKAGE_pixman is not set
# CONFIG_PACKAGE_poco is not set
# CONFIG_PACKAGE_poco-all is not set
# CONFIG_PACKAGE_protobuf is not set
# CONFIG_PACKAGE_protobuf-lite is not set
# CONFIG_PACKAGE_pthsem is not set
# CONFIG_PACKAGE_re2 is not set
CONFIG_PACKAGE_rpcd-mod-luci=y
# CONFIG_PACKAGE_rpcd-mod-rad2-enc is not set
CONFIG_PACKAGE_rpcd-mod-rrdns=y
# CONFIG_PACKAGE_sbc is not set
# CONFIG_PACKAGE_serdisplib is not set
# CONFIG_PACKAGE_taglib is not set
CONFIG_PACKAGE_terminfo=y
# CONFIG_PACKAGE_tinycdb is not set
# CONFIG_PACKAGE_totem-pl-parser is not set
# CONFIG_PACKAGE_uw-imap is not set
# CONFIG_PACKAGE_xmlrpc-c is not set
# CONFIG_PACKAGE_xmlrpc-c-client is not set
# CONFIG_PACKAGE_xmlrpc-c-server is not set
# CONFIG_PACKAGE_yajl is not set
# CONFIG_PACKAGE_yubico-pam is not set
CONFIG_PACKAGE_zlib=y

#
# Configuration
#
# CONFIG_ZLIB_OPTIMIZE_SPEED is not set
# end of Configuration

# CONFIG_PACKAGE_zlog is not set
# end of Libraries

#
# LuCI
#

#
# 1. Collections
#
CONFIG_PACKAGE_luci=y
# CONFIG_PACKAGE_luci-lib-docker is not set
CONFIG_PACKAGE_luci-nginx=m
CONFIG_PACKAGE_luci-ssl=m
# CONFIG_PACKAGE_luci-ssl-nginx is not set
CONFIG_PACKAGE_luci-ssl-openssl=y
# end of 1. Collections

#
# 2. Modules
#
CONFIG_PACKAGE_luci-base=y
# CONFIG_LUCI_SRCDIET is not set
CONFIG_LUCI_JSMIN=y
CONFIG_LUCI_CSSTIDY=y

#
# Translations
#
# CONFIG_LUCI_LANG_ar is not set
# CONFIG_LUCI_LANG_bg is not set
# CONFIG_LUCI_LANG_bn_BD is not set
# CONFIG_LUCI_LANG_ca is not set
# CONFIG_LUCI_LANG_cs is not set
# CONFIG_LUCI_LANG_da is not set
# CONFIG_LUCI_LANG_de is not set
# CONFIG_LUCI_LANG_el is not set
# CONFIG_LUCI_LANG_es is not set
# CONFIG_LUCI_LANG_fi is not set
# CONFIG_LUCI_LANG_fr is not set
# CONFIG_LUCI_LANG_he is not set
# CONFIG_LUCI_LANG_hi is not set
# CONFIG_LUCI_LANG_hu is not set
# CONFIG_LUCI_LANG_it is not set
# CONFIG_LUCI_LANG_ja is not set
# CONFIG_LUCI_LANG_ko is not set
# CONFIG_LUCI_LANG_mr is not set
# CONFIG_LUCI_LANG_ms is not set
# CONFIG_LUCI_LANG_nb_NO is not set
# CONFIG_LUCI_LANG_nl is not set
# CONFIG_LUCI_LANG_pl is not set
# CONFIG_LUCI_LANG_pt is not set
# CONFIG_LUCI_LANG_pt_BR is not set
# CONFIG_LUCI_LANG_ro is not set
# CONFIG_LUCI_LANG_ru is not set
# CONFIG_LUCI_LANG_sk is not set
# CONFIG_LUCI_LANG_sv is not set
# CONFIG_LUCI_LANG_tr is not set
# CONFIG_LUCI_LANG_uk is not set
# CONFIG_LUCI_LANG_vi is not set
# CONFIG_LUCI_LANG_zh_Hans is not set
# CONFIG_LUCI_LANG_zh_Hant is not set
# end of Translations

CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-mod-admin-full=y
# CONFIG_PACKAGE_luci-mod-battstatus is not set
# CONFIG_PACKAGE_luci-mod-dashboard is not set
CONFIG_PACKAGE_luci-mod-network=y
# CONFIG_PACKAGE_luci-mod-rpc is not set
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y
# end of 2. Modules

#
# 3. Applications
#
# CONFIG_PACKAGE_luci-app-acl is not set
# CONFIG_PACKAGE_luci-app-acme is not set
# CONFIG_PACKAGE_luci-app-adblock is not set
# CONFIG_PACKAGE_luci-app-adguardhome is not set
CONFIG_PACKAGE_luci-app-adguardhome_INCLUDE_binary=y
# CONFIG_PACKAGE_luci-app-advanced is not set
# CONFIG_PACKAGE_luci-app-advanced-reboot is not set
# CONFIG_PACKAGE_luci-app-ahcp is not set
# CONFIG_PACKAGE_luci-app-aliddns is not set
# CONFIG_PACKAGE_luci-app-aliyundrive-webdav is not set
# CONFIG_PACKAGE_luci-app-argon-config is not set
CONFIG_PACKAGE_luci-app-argonne-config=y
CONFIG_PACKAGE_luci-app-aria2=y
# CONFIG_PACKAGE_luci-app-attendedsysupgrade is not set
# CONFIG_PACKAGE_luci-app-babeld is not set
# CONFIG_PACKAGE_luci-app-bcp38 is not set
# CONFIG_PACKAGE_luci-app-bird1-ipv4 is not set
# CONFIG_PACKAGE_luci-app-bird1-ipv6 is not set
# CONFIG_PACKAGE_luci-app-bmx6 is not set
# CONFIG_PACKAGE_luci-app-bmx7 is not set
# CONFIG_PACKAGE_luci-app-bypass is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Shadowsocks_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Shadowsocks_Libev_Server is not set
CONFIG_PACKAGE_luci-app-bypass_INCLUDE_ShadowsocksR_Libev_Client=y
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_ShadowsocksR_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Simple_Obfs is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_V2ray_plugin is not set
CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Trojan=y
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_NaiveProxy is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Kcptun is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Socks5_Proxy is not set
CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Socks_Server=y
# CONFIG_PACKAGE_luci-app-cjdns is not set
# CONFIG_PACKAGE_luci-app-clamav is not set
# CONFIG_PACKAGE_luci-app-clash is not set
CONFIG_PACKAGE_luci-app-commands=y
# CONFIG_PACKAGE_luci-app-cshark is not set
# CONFIG_PACKAGE_luci-app-dawn is not set
# CONFIG_PACKAGE_luci-app-dcwapd is not set
# CONFIG_PACKAGE_luci-app-ddns is not set
# CONFIG_PACKAGE_luci-app-ddnsto is not set
# CONFIG_PACKAGE_luci-app-diag-core is not set
# CONFIG_PACKAGE_luci-app-diskman is not set
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_btrfs_progs is not set
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_lsblk=y
# CONFIG_PACKAGE_luci-app-diskman_INCLUDE_mdadm is not set
# CONFIG_PACKAGE_luci-app-dnscrypt-proxy is not set
# CONFIG_PACKAGE_luci-app-dnsfilter is not set
# CONFIG_PACKAGE_luci-app-dump1090 is not set
# CONFIG_PACKAGE_luci-app-dynapoint is not set
# CONFIG_PACKAGE_luci-app-easymesh is not set
# CONFIG_PACKAGE_luci-app-eoip is not set
CONFIG_PACKAGE_luci-app-eqos=y
# CONFIG_PACKAGE_luci-app-example is not set
# CONFIG_PACKAGE_luci-app-fileassistant is not set
# CONFIG_PACKAGE_luci-app-filebrowser is not set
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-frpc=y
# CONFIG_PACKAGE_luci-app-frps is not set
# CONFIG_PACKAGE_luci-app-fwknopd is not set
CONFIG_PACKAGE_luci-app-hd-idle=y
# CONFIG_PACKAGE_luci-app-hnet is not set
# CONFIG_PACKAGE_luci-app-https-dns-proxy is not set
# CONFIG_PACKAGE_luci-app-ikoolproxy is not set
# CONFIG_PACKAGE_luci-app-koolddns is not set
# CONFIG_PACKAGE_luci-app-koolproxyR is not set
# CONFIG_PACKAGE_luci-app-ksmbd is not set
# CONFIG_PACKAGE_luci-app-ledtrig-rssi is not set
# CONFIG_PACKAGE_luci-app-ledtrig-switch is not set
# CONFIG_PACKAGE_luci-app-ledtrig-usbport is not set
# CONFIG_PACKAGE_luci-app-lxc is not set
# CONFIG_PACKAGE_luci-app-minidlna is not set
# CONFIG_PACKAGE_luci-app-mjpg-streamer is not set
# CONFIG_PACKAGE_luci-app-mosdns is not set
# CONFIG_PACKAGE_luci-app-mwan3 is not set
# CONFIG_PACKAGE_luci-app-nextdns is not set
# CONFIG_PACKAGE_luci-app-nft-qos is not set
# CONFIG_PACKAGE_luci-app-nlbwmon is not set
# CONFIG_PACKAGE_luci-app-ntpc is not set
# CONFIG_PACKAGE_luci-app-nut is not set
# CONFIG_PACKAGE_luci-app-ocserv is not set
# CONFIG_PACKAGE_luci-app-olsr is not set
# CONFIG_PACKAGE_luci-app-olsr-services is not set
# CONFIG_PACKAGE_luci-app-olsr-viz is not set
# CONFIG_PACKAGE_luci-app-omcproxy is not set
CONFIG_PACKAGE_luci-app-openclash=y
# CONFIG_PACKAGE_luci-app-openvpn is not set
# CONFIG_PACKAGE_luci-app-openwisp is not set
CONFIG_PACKAGE_luci-app-opkg=y
# CONFIG_PACKAGE_luci-app-p910nd is not set
# CONFIG_PACKAGE_luci-app-pagekitec is not set
# CONFIG_PACKAGE_luci-app-passwall is not set

#
# Configuration
#
# CONFIG_PACKAGE_luci-app-passwall_Transparent_Proxy is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Brook is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ChinaDNS_NG=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_NaiveProxy is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_GO is not set
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_Plus=y
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray_Plugin is not set
# end of Configuration

# CONFIG_PACKAGE_luci-app-passwall2 is not set

#
# Configuration
#
# CONFIG_PACKAGE_luci-app-passwall2_Transparent_Proxy is not set
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Brook is not set
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_NaiveProxy is not set
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Libev_Client=y
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Client is not set
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Server is not set
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_ShadowsocksR_Libev_Client=y
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_ShadowsocksR_Libev_Server is not set
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Simple_Obfs=y
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_V2ray is not set
# CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_V2ray_Plugin is not set
# end of Configuration

# CONFIG_PACKAGE_luci-app-polipo is not set
# CONFIG_PACKAGE_luci-app-privoxy is not set
# CONFIG_PACKAGE_luci-app-pushbot is not set
CONFIG_PACKAGE_luci-app-qos=y
# CONFIG_PACKAGE_luci-app-radicale is not set
# CONFIG_PACKAGE_luci-app-radicale2 is not set
# CONFIG_PACKAGE_luci-app-rp-pppoe-server is not set
# CONFIG_PACKAGE_luci-app-samba4 is not set
# CONFIG_PACKAGE_luci-app-ser2net is not set
# CONFIG_PACKAGE_luci-app-serverchan is not set
# CONFIG_PACKAGE_luci-app-shadowsocks-libev is not set
# CONFIG_PACKAGE_luci-app-shairplay is not set
# CONFIG_PACKAGE_luci-app-siitwizard is not set
# CONFIG_PACKAGE_luci-app-simple-adblock is not set
# CONFIG_PACKAGE_luci-app-smartdns is not set
# CONFIG_PACKAGE_luci-app-snmpd is not set
# CONFIG_PACKAGE_luci-app-softether is not set
# CONFIG_PACKAGE_luci-app-splash is not set
CONFIG_PACKAGE_luci-app-sqm=y
# CONFIG_PACKAGE_luci-app-squid is not set
# CONFIG_PACKAGE_luci-app-ssr-mudb-server is not set
CONFIG_PACKAGE_luci-app-ssr-plus=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NONE_V2RAY is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_SagerNet_Core is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Hysteria is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_IPT2Socks is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NaiveProxy is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Redsocks2 is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust_Client is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust_Server is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Libev_Client=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Simple_Obfs is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan is not set
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray_Plugin is not set
# CONFIG_PACKAGE_luci-app-statistics is not set
# CONFIG_PACKAGE_luci-app-store is not set
# CONFIG_PACKAGE_luci-app-tinyproxy is not set
CONFIG_PACKAGE_luci-app-transmission=y
# CONFIG_PACKAGE_luci-app-travelmate is not set
CONFIG_PACKAGE_luci-app-ttyd=y
# CONFIG_PACKAGE_luci-app-udpxy is not set
# CONFIG_PACKAGE_luci-app-uhttpd is not set
# CONFIG_PACKAGE_luci-app-unbound is not set
# CONFIG_PACKAGE_luci-app-upnp is not set
# CONFIG_PACKAGE_luci-app-vnstat is not set
# CONFIG_PACKAGE_luci-app-vnstat2 is not set
# CONFIG_PACKAGE_luci-app-vpn-policy-routing is not set
# CONFIG_PACKAGE_luci-app-vpnbypass is not set
# CONFIG_PACKAGE_luci-app-vssr is not set
# CONFIG_PACKAGE_luci-app-vssr_INCLUDE_Xray is not set
CONFIG_PACKAGE_luci-app-vssr_INCLUDE_Trojan=y
# CONFIG_PACKAGE_luci-app-vssr_INCLUDE_Kcptun is not set
# CONFIG_PACKAGE_luci-app-vssr_INCLUDE_Xray_plugin is not set
# CONFIG_PACKAGE_luci-app-vssr_INCLUDE_ShadowsocksR_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-vssr_INCLUDE_Hysteria is not set
CONFIG_PACKAGE_luci-app-watchcat=y
# CONFIG_PACKAGE_luci-app-wifischedule is not set
# CONFIG_PACKAGE_luci-app-wireguard is not set
# CONFIG_PACKAGE_luci-app-wol is not set
# CONFIG_PACKAGE_luci-app-xfrpc is not set
# CONFIG_PACKAGE_luci-app-xinetd is not set
# CONFIG_PACKAGE_luci-app-yggdrasil is not set
# end of 3. Applications

#
# 4. Themes
#
# CONFIG_PACKAGE_luci-theme-argon is not set
CONFIG_PACKAGE_luci-theme-argonne=y
# CONFIG_PACKAGE_luci-theme-atmaterial_new is not set
CONFIG_PACKAGE_luci-theme-bootstrap=y
# CONFIG_PACKAGE_luci-theme-ifit is not set
# CONFIG_PACKAGE_luci-theme-material is not set
# CONFIG_PACKAGE_luci-theme-mcat is not set
# CONFIG_PACKAGE_luci-theme-neobird is not set
# CONFIG_PACKAGE_luci-theme-openwrt is not set
# CONFIG_PACKAGE_luci-theme-openwrt-2020 is not set
# CONFIG_PACKAGE_luci-theme-tomato is not set
# end of 4. Themes

#
# 5. Protocols
#
# CONFIG_PACKAGE_luci-proto-3g is not set
# CONFIG_PACKAGE_luci-proto-batman-adv is not set
# CONFIG_PACKAGE_luci-proto-bonding is not set
# CONFIG_PACKAGE_luci-proto-gre is not set
# CONFIG_PACKAGE_luci-proto-hnet is not set
CONFIG_PACKAGE_luci-proto-ipip=y
CONFIG_PACKAGE_luci-proto-ipv6=y
# CONFIG_PACKAGE_luci-proto-modemmanager is not set
# CONFIG_PACKAGE_luci-proto-ncm is not set
# CONFIG_PACKAGE_luci-proto-openconnect is not set
# CONFIG_PACKAGE_luci-proto-openfortivpn is not set
CONFIG_PACKAGE_luci-proto-ppp=y
# CONFIG_PACKAGE_luci-proto-pppossh is not set
# CONFIG_PACKAGE_luci-proto-qmi is not set
# CONFIG_PACKAGE_luci-proto-relay is not set
# CONFIG_PACKAGE_luci-proto-sstp is not set
CONFIG_PACKAGE_luci-proto-vpnc=y
# CONFIG_PACKAGE_luci-proto-vxlan is not set
# CONFIG_PACKAGE_luci-proto-wireguard is not set
# end of 5. Protocols

#
# 6. Libraries
#
CONFIG_PACKAGE_luci-lib-base=y
# CONFIG_PACKAGE_luci-lib-dracula is not set
# CONFIG_PACKAGE_luci-lib-httpclient is not set
# CONFIG_PACKAGE_luci-lib-httpprotoutils is not set
CONFIG_PACKAGE_luci-lib-ip=y
CONFIG_PACKAGE_luci-lib-ipkg=y
# CONFIG_PACKAGE_luci-lib-iptparser is not set
# CONFIG_PACKAGE_luci-lib-jquery-1-4 is not set
CONFIG_PACKAGE_luci-lib-json=m
CONFIG_PACKAGE_luci-lib-jsonc=y
CONFIG_PACKAGE_luci-lib-nixio=y
CONFIG_PACKAGE_luci-lib-nixio_notls=y
# CONFIG_PACKAGE_luci-lib-nixio_axtls is not set
# CONFIG_PACKAGE_luci-lib-nixio_cyassl is not set
# CONFIG_PACKAGE_luci-lib-nixio_openssl is not set
# CONFIG_PACKAGE_luci-lib-px5g is not set
# CONFIG_PACKAGE_luci-lib-taskd is not set
# CONFIG_PACKAGE_luci-lib-xterm is not set
# end of 6. Libraries

# CONFIG_PACKAGE_luci-i18n-argonne-config-es is not set
# CONFIG_PACKAGE_luci-i18n-argonne-config-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ar is not set
# CONFIG_PACKAGE_luci-i18n-aria2-bg is not set
# CONFIG_PACKAGE_luci-i18n-aria2-bn is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ca is not set
# CONFIG_PACKAGE_luci-i18n-aria2-cs is not set
# CONFIG_PACKAGE_luci-i18n-aria2-da is not set
# CONFIG_PACKAGE_luci-i18n-aria2-de is not set
# CONFIG_PACKAGE_luci-i18n-aria2-el is not set
# CONFIG_PACKAGE_luci-i18n-aria2-es is not set
# CONFIG_PACKAGE_luci-i18n-aria2-fi is not set
# CONFIG_PACKAGE_luci-i18n-aria2-fr is not set
# CONFIG_PACKAGE_luci-i18n-aria2-he is not set
# CONFIG_PACKAGE_luci-i18n-aria2-hi is not set
# CONFIG_PACKAGE_luci-i18n-aria2-hu is not set
# CONFIG_PACKAGE_luci-i18n-aria2-it is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ja is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ko is not set
# CONFIG_PACKAGE_luci-i18n-aria2-mr is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ms is not set
# CONFIG_PACKAGE_luci-i18n-aria2-nl is not set
# CONFIG_PACKAGE_luci-i18n-aria2-no is not set
# CONFIG_PACKAGE_luci-i18n-aria2-pl is not set
# CONFIG_PACKAGE_luci-i18n-aria2-pt is not set
# CONFIG_PACKAGE_luci-i18n-aria2-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ro is not set
# CONFIG_PACKAGE_luci-i18n-aria2-ru is not set
# CONFIG_PACKAGE_luci-i18n-aria2-sk is not set
# CONFIG_PACKAGE_luci-i18n-aria2-sv is not set
# CONFIG_PACKAGE_luci-i18n-aria2-tr is not set
# CONFIG_PACKAGE_luci-i18n-aria2-uk is not set
# CONFIG_PACKAGE_luci-i18n-aria2-vi is not set
# CONFIG_PACKAGE_luci-i18n-aria2-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-aria2-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-base-ar is not set
# CONFIG_PACKAGE_luci-i18n-base-bg is not set
# CONFIG_PACKAGE_luci-i18n-base-bn is not set
# CONFIG_PACKAGE_luci-i18n-base-ca is not set
# CONFIG_PACKAGE_luci-i18n-base-cs is not set
# CONFIG_PACKAGE_luci-i18n-base-da is not set
# CONFIG_PACKAGE_luci-i18n-base-de is not set
# CONFIG_PACKAGE_luci-i18n-base-el is not set
# CONFIG_PACKAGE_luci-i18n-base-es is not set
# CONFIG_PACKAGE_luci-i18n-base-fi is not set
# CONFIG_PACKAGE_luci-i18n-base-fr is not set
# CONFIG_PACKAGE_luci-i18n-base-he is not set
# CONFIG_PACKAGE_luci-i18n-base-hi is not set
# CONFIG_PACKAGE_luci-i18n-base-hu is not set
# CONFIG_PACKAGE_luci-i18n-base-it is not set
# CONFIG_PACKAGE_luci-i18n-base-ja is not set
# CONFIG_PACKAGE_luci-i18n-base-ko is not set
# CONFIG_PACKAGE_luci-i18n-base-mr is not set
# CONFIG_PACKAGE_luci-i18n-base-ms is not set
# CONFIG_PACKAGE_luci-i18n-base-nl is not set
# CONFIG_PACKAGE_luci-i18n-base-no is not set
# CONFIG_PACKAGE_luci-i18n-base-pl is not set
# CONFIG_PACKAGE_luci-i18n-base-pt is not set
# CONFIG_PACKAGE_luci-i18n-base-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-base-ro is not set
# CONFIG_PACKAGE_luci-i18n-base-ru is not set
# CONFIG_PACKAGE_luci-i18n-base-sk is not set
# CONFIG_PACKAGE_luci-i18n-base-sv is not set
# CONFIG_PACKAGE_luci-i18n-base-tr is not set
# CONFIG_PACKAGE_luci-i18n-base-uk is not set
# CONFIG_PACKAGE_luci-i18n-base-vi is not set
# CONFIG_PACKAGE_luci-i18n-base-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-base-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-commands-ar is not set
# CONFIG_PACKAGE_luci-i18n-commands-bg is not set
# CONFIG_PACKAGE_luci-i18n-commands-bn is not set
# CONFIG_PACKAGE_luci-i18n-commands-ca is not set
# CONFIG_PACKAGE_luci-i18n-commands-cs is not set
# CONFIG_PACKAGE_luci-i18n-commands-da is not set
# CONFIG_PACKAGE_luci-i18n-commands-de is not set
# CONFIG_PACKAGE_luci-i18n-commands-el is not set
# CONFIG_PACKAGE_luci-i18n-commands-es is not set
# CONFIG_PACKAGE_luci-i18n-commands-fi is not set
# CONFIG_PACKAGE_luci-i18n-commands-fr is not set
# CONFIG_PACKAGE_luci-i18n-commands-he is not set
# CONFIG_PACKAGE_luci-i18n-commands-hi is not set
# CONFIG_PACKAGE_luci-i18n-commands-hu is not set
# CONFIG_PACKAGE_luci-i18n-commands-it is not set
# CONFIG_PACKAGE_luci-i18n-commands-ja is not set
# CONFIG_PACKAGE_luci-i18n-commands-ko is not set
# CONFIG_PACKAGE_luci-i18n-commands-mr is not set
# CONFIG_PACKAGE_luci-i18n-commands-ms is not set
# CONFIG_PACKAGE_luci-i18n-commands-no is not set
# CONFIG_PACKAGE_luci-i18n-commands-pl is not set
# CONFIG_PACKAGE_luci-i18n-commands-pt is not set
# CONFIG_PACKAGE_luci-i18n-commands-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-commands-ro is not set
# CONFIG_PACKAGE_luci-i18n-commands-ru is not set
# CONFIG_PACKAGE_luci-i18n-commands-sk is not set
# CONFIG_PACKAGE_luci-i18n-commands-sv is not set
# CONFIG_PACKAGE_luci-i18n-commands-tr is not set
# CONFIG_PACKAGE_luci-i18n-commands-uk is not set
# CONFIG_PACKAGE_luci-i18n-commands-vi is not set
# CONFIG_PACKAGE_luci-i18n-commands-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-commands-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-eqos-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ar is not set
# CONFIG_PACKAGE_luci-i18n-firewall-bg is not set
# CONFIG_PACKAGE_luci-i18n-firewall-bn is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ca is not set
# CONFIG_PACKAGE_luci-i18n-firewall-cs is not set
# CONFIG_PACKAGE_luci-i18n-firewall-da is not set
# CONFIG_PACKAGE_luci-i18n-firewall-de is not set
# CONFIG_PACKAGE_luci-i18n-firewall-el is not set
# CONFIG_PACKAGE_luci-i18n-firewall-es is not set
# CONFIG_PACKAGE_luci-i18n-firewall-fi is not set
# CONFIG_PACKAGE_luci-i18n-firewall-fr is not set
# CONFIG_PACKAGE_luci-i18n-firewall-he is not set
# CONFIG_PACKAGE_luci-i18n-firewall-hi is not set
# CONFIG_PACKAGE_luci-i18n-firewall-hu is not set
# CONFIG_PACKAGE_luci-i18n-firewall-it is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ja is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ko is not set
# CONFIG_PACKAGE_luci-i18n-firewall-mr is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ms is not set
# CONFIG_PACKAGE_luci-i18n-firewall-nl is not set
# CONFIG_PACKAGE_luci-i18n-firewall-no is not set
# CONFIG_PACKAGE_luci-i18n-firewall-pl is not set
# CONFIG_PACKAGE_luci-i18n-firewall-pt is not set
# CONFIG_PACKAGE_luci-i18n-firewall-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ro is not set
# CONFIG_PACKAGE_luci-i18n-firewall-ru is not set
# CONFIG_PACKAGE_luci-i18n-firewall-sk is not set
# CONFIG_PACKAGE_luci-i18n-firewall-sv is not set
# CONFIG_PACKAGE_luci-i18n-firewall-tr is not set
# CONFIG_PACKAGE_luci-i18n-firewall-uk is not set
# CONFIG_PACKAGE_luci-i18n-firewall-vi is not set
# CONFIG_PACKAGE_luci-i18n-firewall-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-firewall-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ar is not set
# CONFIG_PACKAGE_luci-i18n-frpc-bg is not set
# CONFIG_PACKAGE_luci-i18n-frpc-bn is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ca is not set
# CONFIG_PACKAGE_luci-i18n-frpc-cs is not set
# CONFIG_PACKAGE_luci-i18n-frpc-da is not set
# CONFIG_PACKAGE_luci-i18n-frpc-de is not set
# CONFIG_PACKAGE_luci-i18n-frpc-el is not set
# CONFIG_PACKAGE_luci-i18n-frpc-es is not set
# CONFIG_PACKAGE_luci-i18n-frpc-fi is not set
# CONFIG_PACKAGE_luci-i18n-frpc-fr is not set
# CONFIG_PACKAGE_luci-i18n-frpc-he is not set
# CONFIG_PACKAGE_luci-i18n-frpc-hi is not set
# CONFIG_PACKAGE_luci-i18n-frpc-hu is not set
# CONFIG_PACKAGE_luci-i18n-frpc-it is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ja is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ko is not set
# CONFIG_PACKAGE_luci-i18n-frpc-mr is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ms is not set
# CONFIG_PACKAGE_luci-i18n-frpc-no is not set
# CONFIG_PACKAGE_luci-i18n-frpc-pl is not set
# CONFIG_PACKAGE_luci-i18n-frpc-pt is not set
# CONFIG_PACKAGE_luci-i18n-frpc-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ro is not set
# CONFIG_PACKAGE_luci-i18n-frpc-ru is not set
# CONFIG_PACKAGE_luci-i18n-frpc-sk is not set
# CONFIG_PACKAGE_luci-i18n-frpc-sv is not set
# CONFIG_PACKAGE_luci-i18n-frpc-tr is not set
# CONFIG_PACKAGE_luci-i18n-frpc-uk is not set
# CONFIG_PACKAGE_luci-i18n-frpc-vi is not set
# CONFIG_PACKAGE_luci-i18n-frpc-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-frpc-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-ca is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-cs is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-de is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-el is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-es is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-fr is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-he is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-hu is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-it is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-ja is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-ms is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-no is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-pl is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-pt is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-ro is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-ru is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-sk is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-sv is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-tr is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-uk is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-vi is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-hd-idle-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ar is not set
# CONFIG_PACKAGE_luci-i18n-opkg-bg is not set
# CONFIG_PACKAGE_luci-i18n-opkg-bn is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ca is not set
# CONFIG_PACKAGE_luci-i18n-opkg-cs is not set
# CONFIG_PACKAGE_luci-i18n-opkg-da is not set
# CONFIG_PACKAGE_luci-i18n-opkg-de is not set
# CONFIG_PACKAGE_luci-i18n-opkg-el is not set
# CONFIG_PACKAGE_luci-i18n-opkg-es is not set
# CONFIG_PACKAGE_luci-i18n-opkg-fi is not set
# CONFIG_PACKAGE_luci-i18n-opkg-fr is not set
# CONFIG_PACKAGE_luci-i18n-opkg-he is not set
# CONFIG_PACKAGE_luci-i18n-opkg-hi is not set
# CONFIG_PACKAGE_luci-i18n-opkg-hu is not set
# CONFIG_PACKAGE_luci-i18n-opkg-it is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ja is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ko is not set
# CONFIG_PACKAGE_luci-i18n-opkg-mr is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ms is not set
# CONFIG_PACKAGE_luci-i18n-opkg-no is not set
# CONFIG_PACKAGE_luci-i18n-opkg-pl is not set
# CONFIG_PACKAGE_luci-i18n-opkg-pt is not set
# CONFIG_PACKAGE_luci-i18n-opkg-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ro is not set
# CONFIG_PACKAGE_luci-i18n-opkg-ru is not set
# CONFIG_PACKAGE_luci-i18n-opkg-sk is not set
# CONFIG_PACKAGE_luci-i18n-opkg-sv is not set
# CONFIG_PACKAGE_luci-i18n-opkg-tr is not set
# CONFIG_PACKAGE_luci-i18n-opkg-uk is not set
# CONFIG_PACKAGE_luci-i18n-opkg-vi is not set
# CONFIG_PACKAGE_luci-i18n-opkg-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-opkg-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-qos-ar is not set
# CONFIG_PACKAGE_luci-i18n-qos-bg is not set
# CONFIG_PACKAGE_luci-i18n-qos-bn is not set
# CONFIG_PACKAGE_luci-i18n-qos-ca is not set
# CONFIG_PACKAGE_luci-i18n-qos-cs is not set
# CONFIG_PACKAGE_luci-i18n-qos-da is not set
# CONFIG_PACKAGE_luci-i18n-qos-de is not set
# CONFIG_PACKAGE_luci-i18n-qos-el is not set
# CONFIG_PACKAGE_luci-i18n-qos-es is not set
# CONFIG_PACKAGE_luci-i18n-qos-fi is not set
# CONFIG_PACKAGE_luci-i18n-qos-fr is not set
# CONFIG_PACKAGE_luci-i18n-qos-he is not set
# CONFIG_PACKAGE_luci-i18n-qos-hi is not set
# CONFIG_PACKAGE_luci-i18n-qos-hu is not set
# CONFIG_PACKAGE_luci-i18n-qos-it is not set
# CONFIG_PACKAGE_luci-i18n-qos-ja is not set
# CONFIG_PACKAGE_luci-i18n-qos-ko is not set
# CONFIG_PACKAGE_luci-i18n-qos-mr is not set
# CONFIG_PACKAGE_luci-i18n-qos-ms is not set
# CONFIG_PACKAGE_luci-i18n-qos-no is not set
# CONFIG_PACKAGE_luci-i18n-qos-pl is not set
# CONFIG_PACKAGE_luci-i18n-qos-pt is not set
# CONFIG_PACKAGE_luci-i18n-qos-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-qos-ro is not set
# CONFIG_PACKAGE_luci-i18n-qos-ru is not set
# CONFIG_PACKAGE_luci-i18n-qos-sk is not set
# CONFIG_PACKAGE_luci-i18n-qos-sv is not set
# CONFIG_PACKAGE_luci-i18n-qos-tr is not set
# CONFIG_PACKAGE_luci-i18n-qos-uk is not set
# CONFIG_PACKAGE_luci-i18n-qos-vi is not set
# CONFIG_PACKAGE_luci-i18n-qos-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-qos-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ar is not set
# CONFIG_PACKAGE_luci-i18n-sqm-bg is not set
# CONFIG_PACKAGE_luci-i18n-sqm-bn is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ca is not set
# CONFIG_PACKAGE_luci-i18n-sqm-cs is not set
# CONFIG_PACKAGE_luci-i18n-sqm-da is not set
# CONFIG_PACKAGE_luci-i18n-sqm-de is not set
# CONFIG_PACKAGE_luci-i18n-sqm-el is not set
# CONFIG_PACKAGE_luci-i18n-sqm-es is not set
# CONFIG_PACKAGE_luci-i18n-sqm-fi is not set
# CONFIG_PACKAGE_luci-i18n-sqm-fr is not set
# CONFIG_PACKAGE_luci-i18n-sqm-he is not set
# CONFIG_PACKAGE_luci-i18n-sqm-hi is not set
# CONFIG_PACKAGE_luci-i18n-sqm-hu is not set
# CONFIG_PACKAGE_luci-i18n-sqm-it is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ja is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ko is not set
# CONFIG_PACKAGE_luci-i18n-sqm-mr is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ms is not set
# CONFIG_PACKAGE_luci-i18n-sqm-no is not set
# CONFIG_PACKAGE_luci-i18n-sqm-pl is not set
# CONFIG_PACKAGE_luci-i18n-sqm-pt is not set
# CONFIG_PACKAGE_luci-i18n-sqm-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ro is not set
# CONFIG_PACKAGE_luci-i18n-sqm-ru is not set
# CONFIG_PACKAGE_luci-i18n-sqm-sk is not set
# CONFIG_PACKAGE_luci-i18n-sqm-sv is not set
# CONFIG_PACKAGE_luci-i18n-sqm-tr is not set
# CONFIG_PACKAGE_luci-i18n-sqm-uk is not set
# CONFIG_PACKAGE_luci-i18n-sqm-vi is not set
# CONFIG_PACKAGE_luci-i18n-sqm-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-sqm-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ar is not set
# CONFIG_PACKAGE_luci-i18n-transmission-bg is not set
# CONFIG_PACKAGE_luci-i18n-transmission-bn is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ca is not set
# CONFIG_PACKAGE_luci-i18n-transmission-cs is not set
# CONFIG_PACKAGE_luci-i18n-transmission-da is not set
# CONFIG_PACKAGE_luci-i18n-transmission-de is not set
# CONFIG_PACKAGE_luci-i18n-transmission-el is not set
# CONFIG_PACKAGE_luci-i18n-transmission-es is not set
# CONFIG_PACKAGE_luci-i18n-transmission-fi is not set
# CONFIG_PACKAGE_luci-i18n-transmission-fr is not set
# CONFIG_PACKAGE_luci-i18n-transmission-he is not set
# CONFIG_PACKAGE_luci-i18n-transmission-hi is not set
# CONFIG_PACKAGE_luci-i18n-transmission-hu is not set
# CONFIG_PACKAGE_luci-i18n-transmission-it is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ja is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ko is not set
# CONFIG_PACKAGE_luci-i18n-transmission-mr is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ms is not set
# CONFIG_PACKAGE_luci-i18n-transmission-no is not set
# CONFIG_PACKAGE_luci-i18n-transmission-pl is not set
# CONFIG_PACKAGE_luci-i18n-transmission-pt is not set
# CONFIG_PACKAGE_luci-i18n-transmission-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ro is not set
# CONFIG_PACKAGE_luci-i18n-transmission-ru is not set
# CONFIG_PACKAGE_luci-i18n-transmission-sk is not set
# CONFIG_PACKAGE_luci-i18n-transmission-sv is not set
# CONFIG_PACKAGE_luci-i18n-transmission-tr is not set
# CONFIG_PACKAGE_luci-i18n-transmission-uk is not set
# CONFIG_PACKAGE_luci-i18n-transmission-vi is not set
# CONFIG_PACKAGE_luci-i18n-transmission-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-transmission-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ar is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-bg is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-bn is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ca is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-cs is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-da is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-de is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-el is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-es is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-fi is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-fr is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-he is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-hi is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-hu is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-it is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ja is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ko is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-mr is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ms is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-no is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-pl is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-pt is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ro is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-ru is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-sk is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-sv is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-tr is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-uk is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-vi is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-ttyd-zh-tw is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ar is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-bg is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-bn is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ca is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-cs is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-da is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-de is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-el is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-es is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-fi is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-fr is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-he is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-hi is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-hu is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-it is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ja is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ko is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-mr is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ms is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-no is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-pl is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-pt is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-pt-br is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ro is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-ru is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-sk is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-sv is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-tr is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-uk is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-vi is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-zh-tw is not set
# end of LuCI

#
# Mail
#
# CONFIG_PACKAGE_alpine is not set
# CONFIG_PACKAGE_bogofilter is not set
# CONFIG_PACKAGE_dovecot is not set
# CONFIG_PACKAGE_dovecot-pigeonhole is not set
# CONFIG_PACKAGE_dovecot-utils is not set
# CONFIG_PACKAGE_emailrelay is not set
# CONFIG_PACKAGE_exim is not set
# CONFIG_PACKAGE_exim-gnutls is not set
# CONFIG_PACKAGE_exim-ldap is not set
# CONFIG_PACKAGE_exim-openssl is not set
# CONFIG_PACKAGE_fdm is not set
# CONFIG_PACKAGE_greyfix is not set
# CONFIG_PACKAGE_mailsend is not set
# CONFIG_PACKAGE_mailsend-nossl is not set
# CONFIG_PACKAGE_mblaze is not set
# CONFIG_PACKAGE_msmtp is not set
# CONFIG_PACKAGE_msmtp-mta is not set
# CONFIG_PACKAGE_msmtp-nossl is not set
# CONFIG_PACKAGE_msmtp-queue is not set
# CONFIG_PACKAGE_mutt is not set
# CONFIG_PACKAGE_nail is not set
# CONFIG_PACKAGE_opendkim is not set
# CONFIG_PACKAGE_opendkim-tools is not set
# CONFIG_PACKAGE_postfix is not set
# CONFIG_PACKAGE_spamc is not set
# CONFIG_PACKAGE_spamc-ssl is not set
# end of Mail

#
# MTK Properties
#

#
# Applications
#
# CONFIG_PACKAGE_flash is not set
# CONFIG_PACKAGE_uci2dat is not set
CONFIG_PACKAGE_wificonf=y
# CONFIG_SUPPORT_LSDK_NVRAM_CMD is not set
# end of Applications

#
# Drivers
#
# CONFIG_PACKAGE_mt7602 is not set
CONFIG_PACKAGE_mt7603=y
# CONFIG_PACKAGE_mt7610 is not set
# CONFIG_PACKAGE_mt7612 is not set
CONFIG_PACKAGE_mt7615=y
# CONFIG_PACKAGE_mt7620 is not set
# CONFIG_PACKAGE_mt7628 is not set
# end of Drivers

#
# Libraries
#
# CONFIG_PACKAGE_libnvram is not set
# end of Libraries

#
# Misc
#
CONFIG_PACKAGE_mtk-luci-plugin=y
CONFIG_LUCI_APP_MTKWIFI=y
CONFIG_LUCI_APP_WEBCONSOLE=y
# end of Misc
# end of MTK Properties

#
# Multimedia
#

#
# Streaming
#
# CONFIG_PACKAGE_oggfwd is not set
# end of Streaming

# CONFIG_PACKAGE_aliyundrive-webdav is not set
# CONFIG_PACKAGE_ffmpeg is not set
# CONFIG_PACKAGE_ffprobe is not set
# CONFIG_PACKAGE_fswebcam is not set
# CONFIG_PACKAGE_gerbera is not set
# CONFIG_PACKAGE_gphoto2 is not set
# CONFIG_PACKAGE_graphicsmagick is not set
# CONFIG_PACKAGE_grilo is not set
# CONFIG_PACKAGE_grilo-plugins is not set
# CONFIG_PACKAGE_gst1-libav is not set
# CONFIG_PACKAGE_gstreamer1-libs is not set
# CONFIG_PACKAGE_gstreamer1-plugins-bad is not set
# CONFIG_PACKAGE_gstreamer1-plugins-base is not set
# CONFIG_PACKAGE_gstreamer1-plugins-good is not set
# CONFIG_PACKAGE_gstreamer1-plugins-ugly is not set
# CONFIG_PACKAGE_gstreamer1-utils is not set
# CONFIG_PACKAGE_icecast is not set
# CONFIG_PACKAGE_imagemagick is not set
# CONFIG_PACKAGE_koolproxy is not set
# CONFIG_PACKAGE_lcdgrilo is not set
# CONFIG_PACKAGE_minidlna is not set
# CONFIG_PACKAGE_minisatip is not set
# CONFIG_PACKAGE_mjpg-streamer is not set
# CONFIG_PACKAGE_motion is not set
# CONFIG_PACKAGE_tvheadend is not set
# CONFIG_PACKAGE_v4l2rtspserver is not set
# CONFIG_PACKAGE_v4l2tools is not set
# CONFIG_PACKAGE_vips is not set
# CONFIG_PACKAGE_xupnpd is not set
# CONFIG_PACKAGE_yt-dlp is not set
# end of Multimedia

#
# Network
#

#
# BitTorrent
#
# CONFIG_PACKAGE_mktorrent is not set
# CONFIG_PACKAGE_opentracker is not set
# CONFIG_PACKAGE_opentracker6 is not set
# CONFIG_PACKAGE_rtorrent is not set
# CONFIG_PACKAGE_rtorrent-rpc is not set
# CONFIG_PACKAGE_transmission-cli is not set
CONFIG_PACKAGE_transmission-daemon=y
# CONFIG_PACKAGE_transmission-remote is not set
# CONFIG_PACKAGE_transmission-web is not set
# CONFIG_PACKAGE_transmission-web-control is not set
# end of BitTorrent

#
# Captive Portals
#
# CONFIG_PACKAGE_apfree-wifidog is not set
# CONFIG_PACKAGE_coova-chilli is not set
# CONFIG_PACKAGE_mesh11sd is not set
# CONFIG_PACKAGE_nodogsplash is not set
# CONFIG_PACKAGE_opennds is not set
# CONFIG_PACKAGE_wifidog is not set
# CONFIG_PACKAGE_wifidog-tls is not set
# end of Captive Portals

#
# Cloud Manager
#
# CONFIG_PACKAGE_cloudreve is not set
# CONFIG_PACKAGE_rclone-ng is not set
# CONFIG_PACKAGE_rclone-webui-react is not set
# end of Cloud Manager

#
# Dial-in/up
#
# CONFIG_PACKAGE_rp-pppoe-common is not set
# CONFIG_PACKAGE_rp-pppoe-relay is not set
# CONFIG_PACKAGE_rp-pppoe-server is not set
# end of Dial-in/up

#
# Download Manager
#
# CONFIG_PACKAGE_ariang is not set
# CONFIG_PACKAGE_ariang-nginx is not set
# CONFIG_PACKAGE_leech is not set
CONFIG_PACKAGE_webui-aria2=m
# end of Download Manager

#
# File Transfer
#
CONFIG_PACKAGE_aria2=y

#
# Aria2 Configuration
#
CONFIG_ARIA2_OPENSSL=y
# CONFIG_ARIA2_GNUTLS is not set
# CONFIG_ARIA2_NOSSL is not set
# CONFIG_ARIA2_LIBXML2 is not set
# CONFIG_ARIA2_EXPAT is not set
CONFIG_ARIA2_NOXML=y
CONFIG_ARIA2_BITTORRENT=y
# CONFIG_ARIA2_SFTP is not set
# CONFIG_ARIA2_ASYNC_DNS is not set
# CONFIG_ARIA2_COOKIE is not set
CONFIG_ARIA2_WEBSOCKET=y
# end of Aria2 Configuration

# CONFIG_PACKAGE_atftp is not set
# CONFIG_PACKAGE_atftpd is not set
CONFIG_PACKAGE_curl=y
# CONFIG_PACKAGE_gnurl is not set
# CONFIG_PACKAGE_lftp is not set
# CONFIG_PACKAGE_rclone is not set
# CONFIG_PACKAGE_rclone-config is not set
# CONFIG_PACKAGE_rsync is not set
# CONFIG_PACKAGE_rsyncd is not set
# CONFIG_PACKAGE_vsftpd is not set
# CONFIG_PACKAGE_vsftpd-tls is not set
# CONFIG_PACKAGE_wget-nossl is not set
# CONFIG_PACKAGE_wget-ssl is not set
# end of File Transfer

#
# Filesystem
#
# CONFIG_PACKAGE_davfs2 is not set
# CONFIG_PACKAGE_ksmbd-avahi-service is not set
# CONFIG_PACKAGE_ksmbd-server is not set
# CONFIG_PACKAGE_ksmbd-utils is not set
# CONFIG_PACKAGE_nfs-kernel-server is not set
# CONFIG_PACKAGE_owftpd is not set
# CONFIG_PACKAGE_owhttpd is not set
# CONFIG_PACKAGE_owserver is not set
# CONFIG_PACKAGE_sshfs is not set
# end of Filesystem

#
# Firewall
#
# CONFIG_PACKAGE_arptables-legacy is not set
# CONFIG_PACKAGE_arptables-nft is not set
# CONFIG_PACKAGE_conntrack is not set
# CONFIG_PACKAGE_conntrackd is not set
# CONFIG_PACKAGE_ebtables-legacy is not set
# CONFIG_PACKAGE_ebtables-nft is not set
# CONFIG_PACKAGE_fwknop is not set
# CONFIG_PACKAGE_fwknopd is not set
# CONFIG_PACKAGE_ip6tables-extra is not set
# CONFIG_PACKAGE_ip6tables-mod-nat is not set
# CONFIG_PACKAGE_ip6tables-nft is not set
# CONFIG_PACKAGE_ip6tables-zz-legacy is not set
# CONFIG_PACKAGE_iptables-mod-account is not set
# CONFIG_PACKAGE_iptables-mod-chaos is not set
# CONFIG_PACKAGE_iptables-mod-checksum is not set
# CONFIG_PACKAGE_iptables-mod-cluster is not set
# CONFIG_PACKAGE_iptables-mod-clusterip is not set
# CONFIG_PACKAGE_iptables-mod-condition is not set
CONFIG_PACKAGE_iptables-mod-conntrack-extra=y
# CONFIG_PACKAGE_iptables-mod-delude is not set
# CONFIG_PACKAGE_iptables-mod-dhcpmac is not set
# CONFIG_PACKAGE_iptables-mod-dnetmap is not set
CONFIG_PACKAGE_iptables-mod-extra=y
# CONFIG_PACKAGE_iptables-mod-filter is not set
# CONFIG_PACKAGE_iptables-mod-fuzzy is not set
# CONFIG_PACKAGE_iptables-mod-geoip is not set
# CONFIG_PACKAGE_iptables-mod-hashlimit is not set
# CONFIG_PACKAGE_iptables-mod-iface is not set
# CONFIG_PACKAGE_iptables-mod-ipmark is not set
CONFIG_PACKAGE_iptables-mod-ipopt=y
# CONFIG_PACKAGE_iptables-mod-ipp2p is not set
# CONFIG_PACKAGE_iptables-mod-iprange is not set
# CONFIG_PACKAGE_iptables-mod-ipsec is not set
# CONFIG_PACKAGE_iptables-mod-ipv4options is not set
# CONFIG_PACKAGE_iptables-mod-led is not set
# CONFIG_PACKAGE_iptables-mod-length2 is not set
# CONFIG_PACKAGE_iptables-mod-logmark is not set
# CONFIG_PACKAGE_iptables-mod-lscan is not set
# CONFIG_PACKAGE_iptables-mod-lua is not set
# CONFIG_PACKAGE_iptables-mod-nat-extra is not set
# CONFIG_PACKAGE_iptables-mod-nflog is not set
# CONFIG_PACKAGE_iptables-mod-nfqueue is not set
# CONFIG_PACKAGE_iptables-mod-physdev is not set
# CONFIG_PACKAGE_iptables-mod-proto is not set
# CONFIG_PACKAGE_iptables-mod-psd is not set
# CONFIG_PACKAGE_iptables-mod-quota2 is not set
# CONFIG_PACKAGE_iptables-mod-rpfilter is not set
# CONFIG_PACKAGE_iptables-mod-rtpengine is not set
# CONFIG_PACKAGE_iptables-mod-socket is not set
# CONFIG_PACKAGE_iptables-mod-sysrq is not set
# CONFIG_PACKAGE_iptables-mod-tarpit is not set
# CONFIG_PACKAGE_iptables-mod-tee is not set
CONFIG_PACKAGE_iptables-mod-tproxy=y
# CONFIG_PACKAGE_iptables-mod-trace is not set
# CONFIG_PACKAGE_iptables-mod-u32 is not set
# CONFIG_PACKAGE_iptables-mod-ulog is not set
# CONFIG_PACKAGE_iptables-nft is not set
CONFIG_PACKAGE_iptables-zz-legacy=y
# CONFIG_PACKAGE_iptaccount is not set
# CONFIG_PACKAGE_iptgeoip is not set

#
# Select iptgeoip options
#
# CONFIG_IPTGEOIP_PRESERVE is not set
# end of Select iptgeoip options

# CONFIG_PACKAGE_miniupnpc is not set
# CONFIG_PACKAGE_miniupnpd-iptables is not set
# CONFIG_PACKAGE_miniupnpd-nftables is not set
# CONFIG_PACKAGE_natpmpc is not set
CONFIG_PACKAGE_nftables-json=y
# CONFIG_PACKAGE_nftables-nojson is not set
# CONFIG_PACKAGE_shorewall is not set
# CONFIG_PACKAGE_shorewall-core is not set
# CONFIG_PACKAGE_shorewall-lite is not set
# CONFIG_PACKAGE_shorewall6 is not set
# CONFIG_PACKAGE_shorewall6-lite is not set
# CONFIG_PACKAGE_snort is not set
# CONFIG_PACKAGE_snort3 is not set
CONFIG_PACKAGE_xtables-legacy=y
# CONFIG_PACKAGE_xtables-nft is not set
# end of Firewall

#
# Firewall Tunnel
#
# CONFIG_PACKAGE_iodine is not set
# CONFIG_PACKAGE_iodined is not set
# end of Firewall Tunnel

#
# FreeRADIUS (version 3)
#
# CONFIG_PACKAGE_freeradius3 is not set
# CONFIG_PACKAGE_freeradius3-common is not set
# CONFIG_PACKAGE_freeradius3-utils is not set
# end of FreeRADIUS (version 3)

#
# IP Addresses and Names
#
# CONFIG_PACKAGE_aggregate is not set
# CONFIG_PACKAGE_announce is not set
# CONFIG_PACKAGE_avahi-autoipd is not set
# CONFIG_PACKAGE_avahi-daemon-service-http is not set
# CONFIG_PACKAGE_avahi-daemon-service-ssh is not set
# CONFIG_PACKAGE_avahi-dbus-daemon is not set
# CONFIG_PACKAGE_avahi-dnsconfd is not set
# CONFIG_PACKAGE_avahi-nodbus-daemon is not set
# CONFIG_PACKAGE_avahi-utils is not set
# CONFIG_PACKAGE_bind-check is not set
# CONFIG_PACKAGE_bind-client is not set
# CONFIG_PACKAGE_bind-ddns-confgen is not set
# CONFIG_PACKAGE_bind-dig is not set
# CONFIG_PACKAGE_bind-dnssec is not set
# CONFIG_PACKAGE_bind-host is not set
# CONFIG_PACKAGE_bind-nslookup is not set
# CONFIG_PACKAGE_bind-rndc is not set
# CONFIG_PACKAGE_bind-server is not set
# CONFIG_PACKAGE_bind-tools is not set
# CONFIG_PACKAGE_chinadns-ng is not set
# CONFIG_PACKAGE_ddns-scripts is not set
# CONFIG_PACKAGE_ddns-scripts-services is not set
# CONFIG_PACKAGE_dhcp-forwarder is not set
# CONFIG_PACKAGE_dns-over-https is not set
CONFIG_PACKAGE_dns2socks=y
CONFIG_PACKAGE_dns2tcp=y
# CONFIG_PACKAGE_dnscrypt-proxy is not set
# CONFIG_PACKAGE_dnscrypt-proxy-resolvers is not set
# CONFIG_PACKAGE_dnsdist is not set
# CONFIG_PACKAGE_dnslookup is not set
# CONFIG_PACKAGE_dnsproxy is not set
# CONFIG_PACKAGE_drill is not set
# CONFIG_PACKAGE_hostip is not set
# CONFIG_PACKAGE_idn is not set
# CONFIG_PACKAGE_idn2 is not set
# CONFIG_PACKAGE_inadyn is not set
# CONFIG_PACKAGE_isc-dhcp-client-ipv4 is not set
# CONFIG_PACKAGE_isc-dhcp-client-ipv6 is not set
# CONFIG_PACKAGE_isc-dhcp-omshell-ipv4 is not set
# CONFIG_PACKAGE_isc-dhcp-omshell-ipv6 is not set
# CONFIG_PACKAGE_isc-dhcp-relay-ipv4 is not set
# CONFIG_PACKAGE_isc-dhcp-relay-ipv6 is not set
# CONFIG_PACKAGE_isc-dhcp-server-ipv4 is not set
# CONFIG_PACKAGE_isc-dhcp-server-ipv6 is not set
# CONFIG_PACKAGE_kadnode is not set
# CONFIG_PACKAGE_kea-admin is not set
# CONFIG_PACKAGE_kea-ctrl is not set
# CONFIG_PACKAGE_kea-dhcp-ddns is not set
# CONFIG_PACKAGE_kea-dhcp4 is not set
# CONFIG_PACKAGE_kea-dhcp6 is not set
# CONFIG_PACKAGE_kea-hook-ha is not set
# CONFIG_PACKAGE_kea-hook-lease-cmds is not set
# CONFIG_PACKAGE_kea-lfc is not set
# CONFIG_PACKAGE_kea-libs is not set
# CONFIG_PACKAGE_kea-perfdhcp is not set
# CONFIG_PACKAGE_kea-shell is not set
# CONFIG_PACKAGE_knot is not set
# CONFIG_PACKAGE_knot-dig is not set
# CONFIG_PACKAGE_knot-host is not set
# CONFIG_PACKAGE_knot-keymgr is not set
# CONFIG_PACKAGE_knot-nsupdate is not set
# CONFIG_PACKAGE_knot-resolver is not set

#
# Configuration
#
# CONFIG_PACKAGE_knot-resolver_dnstap is not set
# end of Configuration

# CONFIG_PACKAGE_knot-tests is not set
# CONFIG_PACKAGE_knot-zonecheck is not set
# CONFIG_PACKAGE_ldns-examples is not set
# CONFIG_PACKAGE_mdns-utils is not set
# CONFIG_PACKAGE_mdnsd is not set
# CONFIG_PACKAGE_mdnsresponder is not set
# CONFIG_PACKAGE_mosdns is not set
# CONFIG_MOSDNS_COMPRESS_GOPROXY is not set
CONFIG_MOSDNS_COMPRESS_UPX=y
# CONFIG_PACKAGE_nsd is not set
# CONFIG_PACKAGE_nsd-control is not set
# CONFIG_PACKAGE_nsd-control-setup is not set
# CONFIG_PACKAGE_nsd-nossl is not set
# CONFIG_PACKAGE_ohybridproxy is not set
# CONFIG_PACKAGE_overture is not set
# CONFIG_PACKAGE_pdns is not set
# CONFIG_PACKAGE_pdns-ixfrdist is not set
# CONFIG_PACKAGE_pdns-recursor is not set
# CONFIG_PACKAGE_pdns-tools is not set
# CONFIG_PACKAGE_pdnsd-alt is not set
# CONFIG_PACKAGE_stubby is not set
# CONFIG_PACKAGE_tor-hs is not set
# CONFIG_PACKAGE_torsocks is not set
# CONFIG_PACKAGE_unbound-anchor is not set
# CONFIG_PACKAGE_unbound-checkconf is not set
# CONFIG_PACKAGE_unbound-control is not set
# CONFIG_PACKAGE_unbound-control-setup is not set
# CONFIG_PACKAGE_unbound-daemon is not set
# CONFIG_PACKAGE_unbound-host is not set
# CONFIG_PACKAGE_v2ray-geoip is not set
# CONFIG_PACKAGE_v2ray-geosite is not set
# CONFIG_PACKAGE_wsdd2 is not set
# CONFIG_PACKAGE_zonestitcher is not set
# end of IP Addresses and Names

#
# Instant Messaging
#
# CONFIG_PACKAGE_bitlbee is not set
# CONFIG_PACKAGE_irssi is not set
# CONFIG_PACKAGE_ngircd is not set
# CONFIG_PACKAGE_ngircd-nossl is not set
# CONFIG_PACKAGE_prosody is not set
# CONFIG_PACKAGE_quassel-irssi is not set
# CONFIG_PACKAGE_umurmur-mbedtls is not set
# CONFIG_PACKAGE_umurmur-openssl is not set
# CONFIG_PACKAGE_znc is not set
# end of Instant Messaging

#
# Linux ATM tools
#
# CONFIG_PACKAGE_atm-aread is not set
# CONFIG_PACKAGE_atm-atmaddr is not set
# CONFIG_PACKAGE_atm-atmdiag is not set
# CONFIG_PACKAGE_atm-atmdump is not set
# CONFIG_PACKAGE_atm-atmloop is not set
# CONFIG_PACKAGE_atm-atmsigd is not set
# CONFIG_PACKAGE_atm-atmswitch is not set
# CONFIG_PACKAGE_atm-atmtcp is not set
# CONFIG_PACKAGE_atm-awrite is not set
# CONFIG_PACKAGE_atm-bus is not set
# CONFIG_PACKAGE_atm-debug-tools is not set
# CONFIG_PACKAGE_atm-diagnostics is not set
# CONFIG_PACKAGE_atm-esi is not set
# CONFIG_PACKAGE_atm-ilmid is not set
# CONFIG_PACKAGE_atm-ilmidiag is not set
# CONFIG_PACKAGE_atm-lecs is not set
# CONFIG_PACKAGE_atm-les is not set
# CONFIG_PACKAGE_atm-mpcd is not set
# CONFIG_PACKAGE_atm-saaldump is not set
# CONFIG_PACKAGE_atm-sonetdiag is not set
# CONFIG_PACKAGE_atm-svc_recv is not set
# CONFIG_PACKAGE_atm-svc_send is not set
# CONFIG_PACKAGE_atm-tools is not set
# CONFIG_PACKAGE_atm-ttcp_atm is not set
# CONFIG_PACKAGE_atm-zeppelin is not set
# CONFIG_PACKAGE_br2684ctl is not set
# end of Linux ATM tools

#
# LoRaWAN
#
# CONFIG_PACKAGE_libloragw-tests is not set
# CONFIG_PACKAGE_libloragw-utils is not set
# end of LoRaWAN

#
# NMAP Suite
#
# CONFIG_PACKAGE_ncat is not set
# CONFIG_PACKAGE_ncat-full is not set
# CONFIG_PACKAGE_ncat-ssl is not set
# CONFIG_PACKAGE_ndiff is not set
# CONFIG_PACKAGE_nmap is not set
# CONFIG_PACKAGE_nmap-full is not set
# CONFIG_PACKAGE_nmap-ssl is not set
# CONFIG_PACKAGE_nping is not set
# CONFIG_PACKAGE_nping-ssl is not set
# end of NMAP Suite

#
# NTRIP
#
# CONFIG_PACKAGE_ntripcaster is not set
# CONFIG_PACKAGE_ntripclient is not set
# CONFIG_PACKAGE_ntripserver is not set
# end of NTRIP

#
# OLSR.org network framework
#
# CONFIG_PACKAGE_oonf-dlep-proxy is not set
# CONFIG_PACKAGE_oonf-dlep-radio is not set
# CONFIG_PACKAGE_oonf-init-scripts is not set
# CONFIG_PACKAGE_oonf-olsrd2 is not set
# end of OLSR.org network framework

#
# Open vSwitch
#
# CONFIG_PACKAGE_openvswitch is not set
# CONFIG_PACKAGE_openvswitch-ovn-host is not set
# CONFIG_PACKAGE_openvswitch-ovn-north is not set
# CONFIG_PACKAGE_openvswitch-python3 is not set
# CONFIG_PACKAGE_ovsd is not set
# end of Open vSwitch

#
# OpenLDAP
#
# CONFIG_PACKAGE_libopenldap is not set
# CONFIG_PACKAGE_openldap-server is not set
# CONFIG_PACKAGE_openldap-utils is not set
# end of OpenLDAP

#
# Printing
#
# CONFIG_PACKAGE_p910nd is not set
# end of Printing

#
# Routing and Redirection
#
# CONFIG_PACKAGE_babel-pinger is not set
# CONFIG_PACKAGE_babeld is not set
# CONFIG_PACKAGE_batmand is not set
# CONFIG_PACKAGE_bcp38 is not set
# CONFIG_PACKAGE_bfdd is not set
# CONFIG_PACKAGE_bird1-ipv4 is not set
# CONFIG_PACKAGE_bird1-ipv4-uci is not set
# CONFIG_PACKAGE_bird1-ipv6 is not set
# CONFIG_PACKAGE_bird1-ipv6-uci is not set
# CONFIG_PACKAGE_bird1c-ipv4 is not set
# CONFIG_PACKAGE_bird1c-ipv6 is not set
# CONFIG_PACKAGE_bird1cl-ipv4 is not set
# CONFIG_PACKAGE_bird1cl-ipv6 is not set
# CONFIG_PACKAGE_bird2 is not set
# CONFIG_PACKAGE_bird2c is not set
# CONFIG_PACKAGE_bird2cl is not set
# CONFIG_PACKAGE_bmx6 is not set
# CONFIG_PACKAGE_bmx7 is not set
# CONFIG_PACKAGE_cjdns is not set
# CONFIG_PACKAGE_cjdns-tests is not set
# CONFIG_PACKAGE_dcstad is not set
# CONFIG_PACKAGE_dcwapd is not set
# CONFIG_PACKAGE_devlink is not set
# CONFIG_PACKAGE_frr is not set
# CONFIG_PACKAGE_genl is not set
# CONFIG_PACKAGE_igmpproxy is not set
# CONFIG_PACKAGE_ip-bridge is not set
CONFIG_PACKAGE_ip-full=y
# CONFIG_PACKAGE_ip-tiny is not set
# CONFIG_PACKAGE_lldpd is not set
# CONFIG_PACKAGE_mcproxy is not set
# CONFIG_PACKAGE_mrmctl is not set
# CONFIG_PACKAGE_mwan3 is not set
# CONFIG_PACKAGE_nstat is not set
# CONFIG_PACKAGE_olsrd is not set
# CONFIG_PACKAGE_prince is not set
# CONFIG_PACKAGE_quagga is not set
# CONFIG_PACKAGE_rdma is not set
# CONFIG_PACKAGE_relayd is not set
# CONFIG_PACKAGE_smcroute is not set
# CONFIG_PACKAGE_ss is not set
# CONFIG_PACKAGE_sslh is not set
# CONFIG_PACKAGE_tc-bpf is not set
# CONFIG_PACKAGE_tc-full is not set
# CONFIG_PACKAGE_tc-mod-iptables is not set
CONFIG_PACKAGE_tc-tiny=y
# CONFIG_PACKAGE_tcpproxy is not set
# CONFIG_PACKAGE_udp-broadcast-relay-redux is not set
# CONFIG_PACKAGE_vis is not set
# CONFIG_PACKAGE_yggdrasil is not set
# end of Routing and Redirection

#
# SSH
#
# CONFIG_PACKAGE_autossh is not set
# CONFIG_PACKAGE_openssh-client is not set
# CONFIG_PACKAGE_openssh-client-utils is not set
# CONFIG_PACKAGE_openssh-keygen is not set
# CONFIG_PACKAGE_openssh-moduli is not set
# CONFIG_PACKAGE_openssh-server is not set
# CONFIG_PACKAGE_openssh-server-pam is not set
# CONFIG_PACKAGE_openssh-sftp-avahi-service is not set
# CONFIG_PACKAGE_openssh-sftp-client is not set
# CONFIG_PACKAGE_openssh-sftp-server is not set
# CONFIG_PACKAGE_sshtunnel is not set
# CONFIG_PACKAGE_tmate is not set
# end of SSH

#
# THC-IPv6 attack and analyzing toolkit
#
# CONFIG_PACKAGE_thc-ipv6-address6 is not set
# CONFIG_PACKAGE_thc-ipv6-alive6 is not set
# CONFIG_PACKAGE_thc-ipv6-covert-send6 is not set
# CONFIG_PACKAGE_thc-ipv6-covert-send6d is not set
# CONFIG_PACKAGE_thc-ipv6-denial6 is not set
# CONFIG_PACKAGE_thc-ipv6-detect-new-ip6 is not set
# CONFIG_PACKAGE_thc-ipv6-detect-sniffer6 is not set
# CONFIG_PACKAGE_thc-ipv6-dnsdict6 is not set
# CONFIG_PACKAGE_thc-ipv6-dnsrevenum6 is not set
# CONFIG_PACKAGE_thc-ipv6-dos-new-ip6 is not set
# CONFIG_PACKAGE_thc-ipv6-dump-router6 is not set
# CONFIG_PACKAGE_thc-ipv6-exploit6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-advertise6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-dhcps6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-dns6d is not set
# CONFIG_PACKAGE_thc-ipv6-fake-dnsupdate6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-mipv6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-mld26 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-mld6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-mldrouter6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-router26 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-router6 is not set
# CONFIG_PACKAGE_thc-ipv6-fake-solicitate6 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-advertise6 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-dhcpc6 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-mld26 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-mld6 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-mldrouter6 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-router26 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-router6 is not set
# CONFIG_PACKAGE_thc-ipv6-flood-solicitate6 is not set
# CONFIG_PACKAGE_thc-ipv6-fragmentation6 is not set
# CONFIG_PACKAGE_thc-ipv6-fuzz-dhcpc6 is not set
# CONFIG_PACKAGE_thc-ipv6-fuzz-dhcps6 is not set
# CONFIG_PACKAGE_thc-ipv6-fuzz-ip6 is not set
# CONFIG_PACKAGE_thc-ipv6-implementation6 is not set
# CONFIG_PACKAGE_thc-ipv6-implementation6d is not set
# CONFIG_PACKAGE_thc-ipv6-inverse-lookup6 is not set
# CONFIG_PACKAGE_thc-ipv6-kill-router6 is not set
# CONFIG_PACKAGE_thc-ipv6-ndpexhaust6 is not set
# CONFIG_PACKAGE_thc-ipv6-node-query6 is not set
# CONFIG_PACKAGE_thc-ipv6-parasite6 is not set
# CONFIG_PACKAGE_thc-ipv6-passive-discovery6 is not set
# CONFIG_PACKAGE_thc-ipv6-randicmp6 is not set
# CONFIG_PACKAGE_thc-ipv6-redir6 is not set
# CONFIG_PACKAGE_thc-ipv6-rsmurf6 is not set
# CONFIG_PACKAGE_thc-ipv6-sendpees6 is not set
# CONFIG_PACKAGE_thc-ipv6-sendpeesmp6 is not set
# CONFIG_PACKAGE_thc-ipv6-smurf6 is not set
# CONFIG_PACKAGE_thc-ipv6-thcping6 is not set
# CONFIG_PACKAGE_thc-ipv6-toobig6 is not set
# CONFIG_PACKAGE_thc-ipv6-trace6 is not set
# end of THC-IPv6 attack and analyzing toolkit

#
# Tcpreplay
#
# CONFIG_PACKAGE_tcpbridge is not set
# CONFIG_PACKAGE_tcpcapinfo is not set
# CONFIG_PACKAGE_tcpliveplay is not set
# CONFIG_PACKAGE_tcpprep is not set
# CONFIG_PACKAGE_tcpreplay is not set
# CONFIG_PACKAGE_tcpreplay-all is not set
# CONFIG_PACKAGE_tcpreplay-edit is not set
# CONFIG_PACKAGE_tcprewrite is not set
# end of Tcpreplay

#
# Telephony
#
# CONFIG_PACKAGE_asterisk is not set
# CONFIG_PACKAGE_baresip is not set
# CONFIG_PACKAGE_coturn is not set
# CONFIG_PACKAGE_freeswitch is not set
# CONFIG_PACKAGE_kamailio is not set
# CONFIG_PACKAGE_miax is not set
# CONFIG_PACKAGE_pcapsipdump is not set
# CONFIG_PACKAGE_rtpengine is not set
# CONFIG_PACKAGE_rtpengine-no-transcode is not set
# CONFIG_PACKAGE_rtpengine-recording is not set
# CONFIG_PACKAGE_rtpproxy is not set
# CONFIG_PACKAGE_sipp is not set
# CONFIG_PACKAGE_siproxd is not set
# CONFIG_PACKAGE_yate is not set
# end of Telephony

#
# Telephony Lantiq
#
# end of Telephony Lantiq

#
# Time Synchronization
#
# CONFIG_PACKAGE_chrony is not set
# CONFIG_PACKAGE_chrony-nts is not set
# CONFIG_PACKAGE_htpdate is not set
# CONFIG_PACKAGE_linuxptp is not set
# CONFIG_PACKAGE_ntp-keygen is not set
# CONFIG_PACKAGE_ntp-utils is not set
# CONFIG_PACKAGE_ntpclient is not set
# CONFIG_PACKAGE_ntpd is not set
# CONFIG_PACKAGE_ntpdate is not set
# end of Time Synchronization

#
# VPN
#
# CONFIG_PACKAGE_chaosvpn is not set
# CONFIG_PACKAGE_eoip is not set
# CONFIG_PACKAGE_fastd is not set
# CONFIG_PACKAGE_libreswan is not set
# CONFIG_PACKAGE_ocserv is not set
# CONFIG_PACKAGE_openconnect is not set
# CONFIG_PACKAGE_openfortivpn is not set
# CONFIG_PACKAGE_openvpn-easy-rsa is not set
# CONFIG_PACKAGE_openvpn-mbedtls is not set
# CONFIG_PACKAGE_openvpn-openssl is not set
# CONFIG_PACKAGE_openvpn-wolfssl is not set
# CONFIG_PACKAGE_pptpd is not set
# CONFIG_PACKAGE_softethervpn-base is not set
# CONFIG_PACKAGE_softethervpn-bridge is not set
# CONFIG_PACKAGE_softethervpn-client is not set
# CONFIG_PACKAGE_softethervpn-server is not set
# CONFIG_PACKAGE_softethervpn5-bridge is not set
# CONFIG_PACKAGE_softethervpn5-client is not set
# CONFIG_PACKAGE_softethervpn5-server is not set
# CONFIG_PACKAGE_sstp-client is not set
# CONFIG_PACKAGE_strongswan is not set
# CONFIG_PACKAGE_tailscale is not set
# CONFIG_PACKAGE_tailscaled is not set
# CONFIG_PACKAGE_tinc is not set
# CONFIG_PACKAGE_uanytun is not set
# CONFIG_PACKAGE_uanytun-nettle is not set
# CONFIG_PACKAGE_uanytun-nocrypt is not set
# CONFIG_PACKAGE_uanytun-sslcrypt is not set
CONFIG_PACKAGE_vpnc=y

#
# Configuration
#
CONFIG_VPNC_GNUTLS=y
# CONFIG_VPNC_OPENSSL is not set
# end of Configuration

CONFIG_PACKAGE_vpnc-scripts=y
# CONFIG_PACKAGE_wireguard-tools is not set
# CONFIG_PACKAGE_xl2tpd is not set
# CONFIG_PACKAGE_zerotier is not set
# end of VPN

#
# Version Control Systems
#
# CONFIG_PACKAGE_git is not set
# CONFIG_PACKAGE_git-http is not set
# CONFIG_PACKAGE_subversion-client is not set
# CONFIG_PACKAGE_subversion-libs is not set
# CONFIG_PACKAGE_subversion-server is not set
# end of Version Control Systems

#
# WWAN
#
# CONFIG_PACKAGE_adb-enablemodem is not set
# CONFIG_PACKAGE_comgt is not set
# CONFIG_PACKAGE_comgt-directip is not set
# CONFIG_PACKAGE_comgt-ncm is not set
# CONFIG_PACKAGE_umbim is not set
# CONFIG_PACKAGE_uqmi is not set
# end of WWAN

#
# Web Servers/Proxies
#
# CONFIG_PACKAGE_apache is not set
# CONFIG_PACKAGE_brook is not set
CONFIG_PACKAGE_cgi-io=y
# CONFIG_PACKAGE_clamav is not set
# CONFIG_PACKAGE_cloudflared is not set
# CONFIG_PACKAGE_ddnsto is not set
# CONFIG_PACKAGE_etebase is not set
# CONFIG_PACKAGE_freshclam is not set
CONFIG_PACKAGE_frpc=y
# CONFIG_PACKAGE_frps is not set
# CONFIG_PACKAGE_gateway-go is not set
# CONFIG_PACKAGE_haproxy is not set
# CONFIG_PACKAGE_haproxy-nossl is not set
# CONFIG_PACKAGE_kcptun-client is not set
# CONFIG_PACKAGE_kcptun-config is not set
# CONFIG_PACKAGE_kcptun-server is not set
# CONFIG_PACKAGE_lighttpd is not set
CONFIG_PACKAGE_microsocks=y
# CONFIG_PACKAGE_naiveproxy is not set
# CONFIG_PACKAGE_nginx-all-module is not set
CONFIG_PACKAGE_nginx-mod-luci=m
CONFIG_PACKAGE_nginx-ssl=m

#
# Configuration
#
# CONFIG_NGINX_DAV is not set
CONFIG_NGINX_UBUS=y
# CONFIG_NGINX_FLV is not set
# CONFIG_NGINX_STUB_STATUS is not set
CONFIG_NGINX_HTTP_CHARSET=y
CONFIG_NGINX_HTTP_GZIP=y
CONFIG_NGINX_HTTP_SSI=y
CONFIG_NGINX_HTTP_USERID=y
CONFIG_NGINX_HTTP_ACCESS=y
CONFIG_NGINX_HTTP_AUTH_BASIC=y
# CONFIG_NGINX_HTTP_AUTH_REQUEST is not set
CONFIG_NGINX_HTTP_AUTOINDEX=y
CONFIG_NGINX_HTTP_GEO=y
CONFIG_NGINX_HTTP_MAP=y
CONFIG_NGINX_HTTP_SPLIT_CLIENTS=y
CONFIG_NGINX_HTTP_REFERER=y
CONFIG_NGINX_HTTP_REWRITE=y
CONFIG_NGINX_HTTP_PROXY=y
CONFIG_NGINX_HTTP_FASTCGI=y
CONFIG_NGINX_HTTP_UWSGI=y
CONFIG_NGINX_HTTP_SCGI=y
CONFIG_NGINX_HTTP_MEMCACHED=y
CONFIG_NGINX_HTTP_LIMIT_CONN=y
CONFIG_NGINX_HTTP_LIMIT_REQ=y
CONFIG_NGINX_HTTP_EMPTY_GIF=y
CONFIG_NGINX_HTTP_BROWSER=y
CONFIG_NGINX_HTTP_UPSTREAM_HASH=y
CONFIG_NGINX_HTTP_UPSTREAM_IP_HASH=y
CONFIG_NGINX_HTTP_UPSTREAM_LEAST_CONN=y
CONFIG_NGINX_HTTP_UPSTREAM_KEEPALIVE=y
CONFIG_NGINX_HTTP_CACHE=y
CONFIG_NGINX_HTTP_V2=y
CONFIG_NGINX_PCRE=y
CONFIG_NGINX_NAXSI=y
# CONFIG_NGINX_LUA is not set
# CONFIG_NGINX_HTTP_REAL_IP is not set
# CONFIG_NGINX_HTTP_SECURE_LINK is not set
# CONFIG_NGINX_HTTP_SUB is not set
CONFIG_NGINX_HEADERS_MORE=y
# CONFIG_NGINX_HTTP_BROTLI is not set
# CONFIG_NGINX_STREAM_CORE_MODULE is not set
# CONFIG_NGINX_RTMP_MODULE is not set
# CONFIG_NGINX_TS_MODULE is not set
# end of Configuration

CONFIG_PACKAGE_nginx-ssl-util=m
# CONFIG_PACKAGE_nginx-ssl-util-nopcre is not set
# CONFIG_PACKAGE_polipo is not set
# CONFIG_PACKAGE_privoxy is not set
# CONFIG_PACKAGE_radicale is not set
# CONFIG_PACKAGE_radicale2 is not set
# CONFIG_PACKAGE_radicale2-examples is not set
# CONFIG_PACKAGE_redsocks2 is not set
# CONFIG_PACKAGE_shadowsocks-libev-config is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-local is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-redir is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-rules is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-server is not set
# CONFIG_PACKAGE_shadowsocks-libev-ss-tunnel is not set
# CONFIG_PACKAGE_shadowsocks-rust-sslocal is not set
# CONFIG_PACKAGE_shadowsocks-rust-ssmanager is not set
# CONFIG_PACKAGE_shadowsocks-rust-ssserver is not set
# CONFIG_PACKAGE_shadowsocks-rust-ssservice is not set
# CONFIG_PACKAGE_shadowsocks-rust-ssurl is not set
CONFIG_PACKAGE_shadowsocksr-libev-ssr-check=y
CONFIG_PACKAGE_shadowsocksr-libev-ssr-local=y
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-nat is not set
CONFIG_PACKAGE_shadowsocksr-libev-ssr-redir=y
# CONFIG_PACKAGE_shadowsocksr-libev-ssr-server is not set
# CONFIG_PACKAGE_sockd is not set
# CONFIG_PACKAGE_socksify is not set
# CONFIG_PACKAGE_spawn-fcgi is not set
# CONFIG_PACKAGE_squid is not set
# CONFIG_PACKAGE_tinyproxy is not set
# CONFIG_PACKAGE_trojan is not set
# CONFIG_PACKAGE_trojan-go is not set
CONFIG_PACKAGE_uhttpd=y
# CONFIG_PACKAGE_uhttpd-mod-lua is not set
CONFIG_PACKAGE_uhttpd-mod-ubus=y
# CONFIG_PACKAGE_uhttpd-mod-ucode is not set
CONFIG_PACKAGE_uwsgi=m
CONFIG_PACKAGE_uwsgi-cgi-plugin=m
# CONFIG_PACKAGE_uwsgi-logfile-plugin is not set
CONFIG_PACKAGE_uwsgi-luci-support=m
# CONFIG_PACKAGE_uwsgi-python3-plugin is not set
CONFIG_PACKAGE_uwsgi-syslog-plugin=m
# CONFIG_PACKAGE_v2ray-plugin is not set
# CONFIG_PACKAGE_v2raya is not set
# CONFIG_PACKAGE_xfrpc is not set
# CONFIG_PACKAGE_xray-plugin is not set
# end of Web Servers/Proxies

#
# Wireless
#
# CONFIG_PACKAGE_aircrack-ng is not set
# CONFIG_PACKAGE_airmon-ng is not set
# CONFIG_PACKAGE_dynapoint is not set
# CONFIG_PACKAGE_hcxdumptool is not set
# CONFIG_PACKAGE_hcxtools is not set
# CONFIG_PACKAGE_horst is not set
# CONFIG_PACKAGE_pixiewps is not set
# CONFIG_PACKAGE_reaver is not set
# CONFIG_PACKAGE_wavemon is not set
# CONFIG_PACKAGE_wifischedule is not set
# end of Wireless

#
# WirelessAPD
#
# CONFIG_PACKAGE_eapol-test is not set
# CONFIG_PACKAGE_eapol-test-openssl is not set
# CONFIG_PACKAGE_eapol-test-wolfssl is not set
# CONFIG_PACKAGE_hostapd is not set
# CONFIG_PACKAGE_hostapd-basic is not set
# CONFIG_PACKAGE_hostapd-basic-openssl is not set
# CONFIG_PACKAGE_hostapd-basic-wolfssl is not set
CONFIG_PACKAGE_hostapd-common=y
# CONFIG_PACKAGE_hostapd-mini is not set
# CONFIG_PACKAGE_hostapd-openssl is not set
# CONFIG_PACKAGE_hostapd-utils is not set
# CONFIG_PACKAGE_hostapd-wolfssl is not set
# CONFIG_PACKAGE_hs20-client is not set
# CONFIG_PACKAGE_hs20-common is not set
# CONFIG_PACKAGE_hs20-server is not set
# CONFIG_PACKAGE_wpa-cli is not set
# CONFIG_PACKAGE_wpa-supplicant is not set
# CONFIG_WPA_RFKILL_SUPPORT is not set
CONFIG_WPA_MSG_MIN_PRIORITY=3
CONFIG_WPA_WOLFSSL=y
# CONFIG_DRIVER_WEXT_SUPPORT is not set
CONFIG_DRIVER_11N_SUPPORT=y
CONFIG_DRIVER_11AC_SUPPORT=y
# CONFIG_DRIVER_11AX_SUPPORT is not set
# CONFIG_WPA_ENABLE_WEP is not set
CONFIG_WPA_MBO_SUPPORT=y
# CONFIG_PACKAGE_wpa-supplicant-basic is not set
# CONFIG_PACKAGE_wpa-supplicant-mesh-openssl is not set
# CONFIG_PACKAGE_wpa-supplicant-mesh-wolfssl is not set
# CONFIG_PACKAGE_wpa-supplicant-mini is not set
# CONFIG_PACKAGE_wpa-supplicant-openssl is not set
# CONFIG_PACKAGE_wpa-supplicant-p2p is not set
# CONFIG_PACKAGE_wpa-supplicant-wolfssl is not set
# CONFIG_PACKAGE_wpad is not set
# CONFIG_PACKAGE_wpad-basic is not set
# CONFIG_PACKAGE_wpad-basic-openssl is not set
CONFIG_PACKAGE_wpad-basic-wolfssl=y
# CONFIG_PACKAGE_wpad-mesh-openssl is not set
# CONFIG_PACKAGE_wpad-mesh-wolfssl is not set
# CONFIG_PACKAGE_wpad-mini is not set
CONFIG_PACKAGE_wpad-openssl=m
# CONFIG_PACKAGE_wpad-wolfssl is not set
# end of WirelessAPD

#
# arp-scan
#
# CONFIG_PACKAGE_arp-scan is not set
# CONFIG_PACKAGE_arp-scan-database is not set
# end of arp-scan

# CONFIG_PACKAGE_464xlat is not set
# CONFIG_PACKAGE_6in4 is not set
# CONFIG_PACKAGE_6rd is not set
# CONFIG_PACKAGE_6to4 is not set
# CONFIG_PACKAGE_UDPspeeder is not set
# CONFIG_PACKAGE_acme is not set
# CONFIG_PACKAGE_acme-dnsapi is not set
# CONFIG_PACKAGE_adblock is not set
# CONFIG_PACKAGE_addrwatch is not set
# CONFIG_PACKAGE_addrwatch-mysql is not set
# CONFIG_PACKAGE_addrwatch-stdout is not set
# CONFIG_PACKAGE_addrwatch-syslog is not set
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_ahcpd is not set
# CONFIG_PACKAGE_alfred is not set
# CONFIG_PACKAGE_apcupsd is not set
# CONFIG_PACKAGE_apcupsd-cgi is not set
# CONFIG_PACKAGE_apinger is not set
# CONFIG_PACKAGE_atlas-probe is not set
# CONFIG_PACKAGE_atlas-sw-probe is not set
# CONFIG_PACKAGE_atlas-sw-probe-rpc is not set
# CONFIG_PACKAGE_batctl-default is not set
# CONFIG_PACKAGE_batctl-full is not set
# CONFIG_PACKAGE_batctl-tiny is not set
# CONFIG_PACKAGE_beanstalkd is not set
# CONFIG_PACKAGE_bmon is not set
# CONFIG_PACKAGE_boinc is not set
# CONFIG_PACKAGE_bpftool-full is not set
# CONFIG_PACKAGE_bpftool-minimal is not set
# CONFIG_PACKAGE_bwm-ng is not set
# CONFIG_PACKAGE_bwping is not set
# CONFIG_PACKAGE_chat is not set
# CONFIG_PACKAGE_cifsmount is not set
# CONFIG_PACKAGE_cni-route-override is not set
# CONFIG_PACKAGE_coap-server is not set
# CONFIG_PACKAGE_conserver is not set
# CONFIG_PACKAGE_crowdsec is not set
# CONFIG_PACKAGE_cshark is not set
# CONFIG_PACKAGE_daemonlogger is not set
# CONFIG_PACKAGE_darkstat is not set
# CONFIG_PACKAGE_dawn is not set
# CONFIG_PACKAGE_dhcpcd is not set
# CONFIG_PACKAGE_dmapd is not set
# CONFIG_PACKAGE_dnscrypt-proxy2 is not set
# CONFIG_PACKAGE_dnstap is not set
# CONFIG_PACKAGE_dnstop is not set
# CONFIG_PACKAGE_ds-lite is not set
# CONFIG_PACKAGE_esniper is not set
# CONFIG_PACKAGE_etherwake is not set
# CONFIG_PACKAGE_etherwake-nfqueue is not set
# CONFIG_PACKAGE_ethtool is not set
# CONFIG_PACKAGE_ethtool-full is not set
# CONFIG_PACKAGE_fail2ban is not set
# CONFIG_PACKAGE_fakeidentd is not set
# CONFIG_PACKAGE_fakepop is not set
# CONFIG_PACKAGE_family-dns is not set
# CONFIG_PACKAGE_foolsm is not set
# CONFIG_PACKAGE_fping is not set
# CONFIG_PACKAGE_generate-ipv6-address is not set
# CONFIG_PACKAGE_gensio-bin is not set
# CONFIG_PACKAGE_geoipupdate is not set
# CONFIG_PACKAGE_geth is not set
# CONFIG_PACKAGE_git-lfs is not set
# CONFIG_PACKAGE_gnunet is not set
# CONFIG_PACKAGE_gost is not set
# CONFIG_PACKAGE_gre is not set
# CONFIG_PACKAGE_gsocket is not set
# CONFIG_PACKAGE_hnet-full is not set
# CONFIG_PACKAGE_hnet-full-l2tp is not set
# CONFIG_PACKAGE_hnet-full-secure is not set
# CONFIG_PACKAGE_hnetd-nossl is not set
# CONFIG_PACKAGE_hnetd-openssl is not set
# CONFIG_PACKAGE_httping is not set
# CONFIG_PACKAGE_httping-nossl is not set
# CONFIG_PACKAGE_https-dns-proxy is not set
# CONFIG_PACKAGE_httptunnel is not set
# CONFIG_PACKAGE_hysteria is not set
# CONFIG_PACKAGE_i2pd is not set
# CONFIG_PACKAGE_ibrdtn-tools is not set
# CONFIG_PACKAGE_ibrdtnd is not set
# CONFIG_PACKAGE_ifstat is not set
# CONFIG_PACKAGE_iftop is not set
# CONFIG_PACKAGE_iiod is not set
# CONFIG_PACKAGE_iperf is not set
# CONFIG_PACKAGE_iperf3 is not set
# CONFIG_PACKAGE_iperf3-ssl is not set
CONFIG_PACKAGE_ipip=y
CONFIG_PACKAGE_ipset=y
# CONFIG_PACKAGE_ipset-dns is not set
# CONFIG_PACKAGE_ipt2socks is not set
# CONFIG_PACKAGE_iptraf-ng is not set
# CONFIG_PACKAGE_iputils-arping is not set
# CONFIG_PACKAGE_iputils-clockdiff is not set
# CONFIG_PACKAGE_iputils-ping is not set
# CONFIG_PACKAGE_iputils-tracepath is not set
# CONFIG_PACKAGE_ipvsadm is not set
# CONFIG_PACKAGE_irtt is not set
CONFIG_PACKAGE_iw=y
# CONFIG_PACKAGE_iw-full is not set
# CONFIG_PACKAGE_jool-tools-netfilter is not set
# CONFIG_PACKAGE_keepalived is not set
# CONFIG_PACKAGE_knxd is not set
# CONFIG_PACKAGE_kplex is not set
# CONFIG_PACKAGE_krb5-client is not set
# CONFIG_PACKAGE_krb5-libs is not set
# CONFIG_PACKAGE_krb5-server is not set
# CONFIG_PACKAGE_krb5-server-extras is not set
CONFIG_PACKAGE_libipset=y
# CONFIG_PACKAGE_libndp is not set
# CONFIG_PACKAGE_linknx is not set
# CONFIG_PACKAGE_lynx is not set
# CONFIG_PACKAGE_mac-telnet-client is not set
# CONFIG_PACKAGE_mac-telnet-discover is not set
# CONFIG_PACKAGE_mac-telnet-ping is not set
# CONFIG_PACKAGE_mac-telnet-server is not set
# CONFIG_PACKAGE_map is not set
# CONFIG_PACKAGE_mbusd is not set
# CONFIG_PACKAGE_mdns-repeater is not set
# CONFIG_PACKAGE_memcached is not set
# CONFIG_PACKAGE_mii-tool is not set
# CONFIG_PACKAGE_mikrotik-btest is not set
# CONFIG_PACKAGE_mini_snmpd is not set
# CONFIG_PACKAGE_minimalist-pcproxy is not set
# CONFIG_PACKAGE_miredo is not set
# CONFIG_PACKAGE_modemmanager is not set
# CONFIG_PACKAGE_mosquitto-client-nossl is not set
# CONFIG_PACKAGE_mosquitto-client-ssl is not set
# CONFIG_PACKAGE_mosquitto-nossl is not set
# CONFIG_PACKAGE_mosquitto-ssl is not set
# CONFIG_PACKAGE_mstpd is not set
# CONFIG_PACKAGE_mtr-json is not set
# CONFIG_PACKAGE_mtr-nojson is not set
# CONFIG_PACKAGE_nbd is not set
# CONFIG_PACKAGE_nbd-server is not set
# CONFIG_PACKAGE_ncp is not set
# CONFIG_PACKAGE_ndppd is not set
# CONFIG_PACKAGE_ndptool is not set
# CONFIG_PACKAGE_nebula is not set
# CONFIG_PACKAGE_nebula-cert is not set
# CONFIG_PACKAGE_net-tools-route is not set
# CONFIG_PACKAGE_netcat is not set
# CONFIG_PACKAGE_netdiscover is not set
# CONFIG_PACKAGE_netifyd is not set
# CONFIG_PACKAGE_netperf is not set
# CONFIG_PACKAGE_netsniff-ng is not set
# CONFIG_PACKAGE_netstinky is not set
# CONFIG_PACKAGE_nextdns is not set
# CONFIG_PACKAGE_nfdump is not set
# CONFIG_PACKAGE_nlbwmon is not set
# CONFIG_PACKAGE_noping is not set
# CONFIG_PACKAGE_nut is not set
# CONFIG_PACKAGE_obfs4proxy is not set
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcp6c_ext_cer_id=0
# CONFIG_PACKAGE_odhcpd is not set
CONFIG_PACKAGE_odhcpd-ipv6only=y

#
# Configuration
#
CONFIG_PACKAGE_odhcpd_ipv6only_ext_cer_id=0
# end of Configuration

# CONFIG_PACKAGE_ola is not set
# CONFIG_PACKAGE_omcproxy is not set
# CONFIG_PACKAGE_onionshare-cli is not set
# CONFIG_PACKAGE_ooniprobe is not set
# CONFIG_PACKAGE_oor is not set
# CONFIG_PACKAGE_open-iscsi is not set
# CONFIG_PACKAGE_oping is not set
# CONFIG_PACKAGE_ostiary is not set
# CONFIG_PACKAGE_pagekitec is not set
# CONFIG_PACKAGE_pcapplusplus is not set
# CONFIG_PACKAGE_pen is not set
# CONFIG_PACKAGE_phantap is not set
# CONFIG_PACKAGE_pimbd is not set
# CONFIG_PACKAGE_pingcheck is not set
# CONFIG_PACKAGE_port-mirroring is not set
CONFIG_PACKAGE_ppp=y
# CONFIG_PACKAGE_ppp-mod-passwordfd is not set
# CONFIG_PACKAGE_ppp-mod-pppoa is not set
CONFIG_PACKAGE_ppp-mod-pppoe=y
# CONFIG_PACKAGE_ppp-mod-pppol2tp is not set
# CONFIG_PACKAGE_ppp-mod-pptp is not set
# CONFIG_PACKAGE_ppp-mod-radius is not set
# CONFIG_PACKAGE_ppp-multilink is not set
# CONFIG_PACKAGE_pppdump is not set
# CONFIG_PACKAGE_pppoe-discovery is not set
# CONFIG_PACKAGE_pppossh is not set
# CONFIG_PACKAGE_pppstats is not set
# CONFIG_PACKAGE_proto-bonding is not set
# CONFIG_PACKAGE_proxychains-ng is not set
# CONFIG_PACKAGE_ptunnel-ng is not set
# CONFIG_PACKAGE_radsecproxy is not set
# CONFIG_PACKAGE_ratched is not set
# CONFIG_PACKAGE_ratechecker is not set
# CONFIG_PACKAGE_redsocks is not set
# CONFIG_PACKAGE_remserial is not set
# CONFIG_PACKAGE_restic-rest-server is not set
# CONFIG_PACKAGE_rpcapd is not set
# CONFIG_PACKAGE_rpcbind is not set
# CONFIG_PACKAGE_rssileds is not set
# CONFIG_PACKAGE_safe-search is not set
# CONFIG_PACKAGE_sagernet-core is not set
# CONFIG_PACKAGE_samba4-admin is not set
# CONFIG_PACKAGE_samba4-client is not set
# CONFIG_PACKAGE_samba4-libs is not set
# CONFIG_PACKAGE_samba4-server is not set
# CONFIG_PACKAGE_samba4-utils is not set
# CONFIG_PACKAGE_samplicator is not set
# CONFIG_PACKAGE_scapy is not set
# CONFIG_PACKAGE_sctp-tools is not set
# CONFIG_PACKAGE_ser2net is not set
# CONFIG_PACKAGE_simple-adblock is not set
# CONFIG_PACKAGE_simple-obfs-client is not set
# CONFIG_PACKAGE_simple-obfs-server is not set
# CONFIG_PACKAGE_slirp4netns is not set
# CONFIG_PACKAGE_smartdns is not set
# CONFIG_PACKAGE_smbinfo is not set
# CONFIG_PACKAGE_snmp-mibs is not set
# CONFIG_PACKAGE_snmp-utils is not set
# CONFIG_PACKAGE_snmpd is not set
# CONFIG_PACKAGE_snmptrapd is not set
# CONFIG_PACKAGE_socat is not set
# CONFIG_PACKAGE_softflowd is not set
# CONFIG_PACKAGE_soloscli is not set
# CONFIG_PACKAGE_speedtest-netperf is not set
# CONFIG_PACKAGE_speedtestpp is not set
# CONFIG_PACKAGE_spoofer is not set
# CONFIG_PACKAGE_ssocks is not set
# CONFIG_PACKAGE_ssocksd is not set
# CONFIG_PACKAGE_static-neighbor-reports is not set
# CONFIG_PACKAGE_stunnel is not set
# CONFIG_PACKAGE_switchdev-poller is not set
# CONFIG_PACKAGE_tac_plus is not set
# CONFIG_PACKAGE_tac_plus-pam is not set
# CONFIG_PACKAGE_tayga is not set
# CONFIG_PACKAGE_tcpdump is not set
# CONFIG_PACKAGE_tcpdump-mini is not set
CONFIG_PACKAGE_tcping=y
# CONFIG_PACKAGE_tgt is not set
# CONFIG_PACKAGE_tmate-ssh-server is not set
# CONFIG_PACKAGE_tor is not set
# CONFIG_PACKAGE_tor-basic is not set
# CONFIG_PACKAGE_tor-fw-helper is not set
# CONFIG_PACKAGE_trafficshaper is not set
# CONFIG_PACKAGE_travelmate is not set
# CONFIG_PACKAGE_trojan-plus is not set
# CONFIG_PACKAGE_u2pnpd is not set
# CONFIG_PACKAGE_uacme is not set
# CONFIG_PACKAGE_uacme-ualpn is not set
CONFIG_PACKAGE_uclient-fetch=y
# CONFIG_PACKAGE_udhcpsnoop is not set
# CONFIG_PACKAGE_udptunnel is not set
# CONFIG_PACKAGE_udpxy is not set
# CONFIG_PACKAGE_ulogd is not set
# CONFIG_PACKAGE_umdns is not set
# CONFIG_PACKAGE_uradvd is not set
# CONFIG_PACKAGE_usbip is not set
# CONFIG_PACKAGE_usteer is not set
# CONFIG_PACKAGE_ustp is not set
# CONFIG_PACKAGE_v2ray-core is not set
# CONFIG_PACKAGE_vallumd is not set
# CONFIG_PACKAGE_vncrepeater is not set
# CONFIG_PACKAGE_vnstat is not set
# CONFIG_PACKAGE_vnstat2 is not set
# CONFIG_PACKAGE_vpn-policy-routing is not set
# CONFIG_PACKAGE_vpnbypass is not set
# CONFIG_PACKAGE_vxlan is not set
# CONFIG_PACKAGE_wakeonlan is not set
# CONFIG_PACKAGE_wg-installer-client is not set
# CONFIG_PACKAGE_wg-installer-server is not set
# CONFIG_PACKAGE_wifi-presence is not set
# CONFIG_PACKAGE_wpan-tools is not set
# CONFIG_PACKAGE_wwan is not set
# CONFIG_PACKAGE_xinetd is not set
CONFIG_PACKAGE_xray-core=y
# CONFIG_PACKAGE_xray-example is not set
# CONFIG_PACKAGE_xray-geodata is not set
# end of Network

#
# Sound
#
# CONFIG_PACKAGE_alsa-utils is not set
# CONFIG_PACKAGE_alsa-utils-seq is not set
# CONFIG_PACKAGE_alsa-utils-tests is not set
# CONFIG_PACKAGE_aserver is not set
# CONFIG_PACKAGE_espeak is not set
# CONFIG_PACKAGE_faad2 is not set
# CONFIG_PACKAGE_fdk-aac is not set
# CONFIG_PACKAGE_ices is not set
# CONFIG_PACKAGE_lame is not set
# CONFIG_PACKAGE_lame-lib is not set
# CONFIG_PACKAGE_liblo-utils is not set
# CONFIG_PACKAGE_madplay is not set
# CONFIG_PACKAGE_moc is not set
# CONFIG_PACKAGE_mpc is not set
# CONFIG_PACKAGE_mpd-avahi-service is not set
# CONFIG_PACKAGE_mpd-full is not set
# CONFIG_PACKAGE_mpd-mini is not set
# CONFIG_PACKAGE_mpg123 is not set
# CONFIG_PACKAGE_opus-tools is not set
# CONFIG_PACKAGE_owntone is not set
# CONFIG_PACKAGE_pianod is not set
# CONFIG_PACKAGE_pianod-client is not set
# CONFIG_PACKAGE_portaudio is not set
# CONFIG_PACKAGE_pulseaudio-daemon is not set
# CONFIG_PACKAGE_pulseaudio-daemon-avahi is not set
# CONFIG_PACKAGE_rtpmidid is not set
# CONFIG_PACKAGE_shairplay is not set
# CONFIG_PACKAGE_shairport-sync-mbedtls is not set
# CONFIG_PACKAGE_shairport-sync-mini is not set
# CONFIG_PACKAGE_shairport-sync-openssl is not set
# CONFIG_PACKAGE_shine is not set
# CONFIG_PACKAGE_sox is not set
# CONFIG_PACKAGE_squeezelite-full is not set
# CONFIG_PACKAGE_squeezelite-mini is not set
# CONFIG_PACKAGE_svox is not set
# CONFIG_PACKAGE_ttymidi-sysex is not set
# CONFIG_PACKAGE_upmpdcli is not set
# end of Sound

#
# Utilities
#

#
# AppArmor
#
# CONFIG_PACKAGE_apparmor-profiles is not set
# CONFIG_PACKAGE_apparmor-utils is not set
# end of AppArmor

#
# BigClown
#
# CONFIG_PACKAGE_bigclown-control-tool is not set
# CONFIG_PACKAGE_bigclown-firmware-tool is not set
# CONFIG_PACKAGE_bigclown-gateway is not set
# CONFIG_PACKAGE_bigclown-mqtt2influxdb is not set
# end of BigClown

#
# Boot Loaders
#
# CONFIG_PACKAGE_fconfig is not set
# CONFIG_PACKAGE_uboot-envtools is not set
# end of Boot Loaders

#
# Compression
#
# CONFIG_PACKAGE_bsdtar is not set
# CONFIG_PACKAGE_bsdtar-noopenssl is not set
# CONFIG_PACKAGE_bzip2 is not set
# CONFIG_PACKAGE_gzip is not set
# CONFIG_PACKAGE_lz4 is not set
# CONFIG_PACKAGE_pigz is not set
# CONFIG_PACKAGE_unrar is not set
# CONFIG_PACKAGE_unzip is not set
# CONFIG_PACKAGE_xz-utils is not set
# CONFIG_PACKAGE_zipcmp is not set
# CONFIG_PACKAGE_zipmerge is not set
# CONFIG_PACKAGE_ziptool is not set
# CONFIG_PACKAGE_zstd is not set
# end of Compression

#
# Database
#
# CONFIG_PACKAGE_mariadb-client is not set
# CONFIG_PACKAGE_mariadb-server-base is not set
# CONFIG_PACKAGE_pgsql-cli is not set
# CONFIG_PACKAGE_pgsql-cli-extra is not set
# CONFIG_PACKAGE_pgsql-server is not set
# CONFIG_PACKAGE_rrdcgi1 is not set
# CONFIG_PACKAGE_rrdtool1 is not set
# CONFIG_PACKAGE_sqlite3-cli is not set
# CONFIG_PACKAGE_unixodbc-tools is not set
# end of Database

#
# Disc
#
# CONFIG_PACKAGE_autopart is not set
# CONFIG_PACKAGE_blkdiscard is not set
# CONFIG_PACKAGE_blkid is not set
# CONFIG_PACKAGE_blockdev is not set
CONFIG_PACKAGE_cfdisk=y
# CONFIG_PACKAGE_cgdisk is not set
# CONFIG_PACKAGE_eject is not set
# CONFIG_PACKAGE_fatresize is not set
CONFIG_PACKAGE_fdisk=y
# CONFIG_PACKAGE_findfs is not set
# CONFIG_PACKAGE_fio is not set
# CONFIG_PACKAGE_fixparts is not set
# CONFIG_PACKAGE_gdisk is not set
CONFIG_PACKAGE_hd-idle=y
# CONFIG_PACKAGE_hdparm is not set
CONFIG_PACKAGE_lsblk=y
# CONFIG_PACKAGE_lvm2 is not set
# CONFIG_PACKAGE_lvm2-selinux is not set
# CONFIG_PACKAGE_mdadm is not set
# CONFIG_PACKAGE_mtools is not set
# CONFIG_PACKAGE_parted is not set
# CONFIG_PACKAGE_partx-utils is not set
# CONFIG_PACKAGE_sfdisk is not set
# CONFIG_PACKAGE_sgdisk is not set
# CONFIG_PACKAGE_uvol is not set
# CONFIG_PACKAGE_wipefs is not set
# end of Disc

#
# Editors
#
# CONFIG_PACKAGE_hexedit is not set
# CONFIG_PACKAGE_joe is not set
# CONFIG_PACKAGE_joe-extras is not set
# CONFIG_PACKAGE_jupp is not set
# CONFIG_PACKAGE_mg is not set
# CONFIG_PACKAGE_nano is not set
# CONFIG_PACKAGE_nano-full is not set
# CONFIG_PACKAGE_nano-plus is not set
# CONFIG_PACKAGE_vim is not set
# CONFIG_PACKAGE_vim-full is not set
# CONFIG_PACKAGE_vim-fuller is not set
# CONFIG_PACKAGE_vim-help is not set
# CONFIG_PACKAGE_vim-runtime is not set
# CONFIG_PACKAGE_zile is not set
# end of Editors

#
# Encryption
#
# CONFIG_PACKAGE_ccrypt is not set
# CONFIG_PACKAGE_certtool is not set
# CONFIG_PACKAGE_cryptsetup is not set
# CONFIG_PACKAGE_cryptsetup-ssh is not set
# CONFIG_PACKAGE_gnupg is not set
# CONFIG_PACKAGE_gnupg2 is not set
# CONFIG_PACKAGE_gnupg2-dirmngr is not set
# CONFIG_PACKAGE_gnutls-utils is not set
# CONFIG_PACKAGE_gpgv is not set
# CONFIG_PACKAGE_gpgv2 is not set
# CONFIG_PACKAGE_keyctl is not set
# CONFIG_PACKAGE_keyutils is not set
# CONFIG_PACKAGE_px5g-mbedtls is not set
# CONFIG_PACKAGE_px5g-standalone is not set
CONFIG_PACKAGE_px5g-wolfssl=m
# CONFIG_PACKAGE_stoken is not set
# end of Encryption

#
# Filesystem
#
# CONFIG_PACKAGE_acl is not set
# CONFIG_PACKAGE_afuse is not set
# CONFIG_PACKAGE_antfs-mount is not set
# CONFIG_PACKAGE_attr is not set
# CONFIG_PACKAGE_badblocks is not set
# CONFIG_PACKAGE_btrfs-progs is not set
# CONFIG_PACKAGE_chattr is not set
# CONFIG_PACKAGE_debugfs is not set
# CONFIG_PACKAGE_dosfstools is not set
# CONFIG_PACKAGE_dumpe2fs is not set
# CONFIG_PACKAGE_e2freefrag is not set
CONFIG_PACKAGE_e2fsprogs=y
# CONFIG_PACKAGE_e4crypt is not set
# CONFIG_PACKAGE_exfat-fsck is not set
# CONFIG_PACKAGE_exfat-mkfs is not set
# CONFIG_PACKAGE_f2fs-tools is not set
# CONFIG_PACKAGE_f2fs-tools-selinux is not set
# CONFIG_PACKAGE_f2fsck is not set
# CONFIG_PACKAGE_f2fsck-selinux is not set
# CONFIG_PACKAGE_filefrag is not set
# CONFIG_PACKAGE_fstrim is not set
# CONFIG_PACKAGE_fuse-utils is not set
# CONFIG_PACKAGE_fuse3-utils is not set
# CONFIG_PACKAGE_hfsfsck is not set
# CONFIG_PACKAGE_lsattr is not set
# CONFIG_PACKAGE_mkf2fs is not set
# CONFIG_PACKAGE_mkf2fs-selinux is not set
# CONFIG_PACKAGE_mkhfs is not set
# CONFIG_PACKAGE_ncdu is not set
# CONFIG_PACKAGE_nfs-utils is not set
# CONFIG_PACKAGE_nfs-utils-libs is not set
# CONFIG_PACKAGE_ntfs-3g is not set
# CONFIG_PACKAGE_ntfs-3g-low is not set
# CONFIG_PACKAGE_ntfs-3g-utils is not set
# CONFIG_PACKAGE_owfs is not set
# CONFIG_PACKAGE_owshell is not set
# CONFIG_PACKAGE_resize2fs is not set
# CONFIG_PACKAGE_squashfs-tools-mksquashfs is not set
# CONFIG_PACKAGE_squashfs-tools-unsquashfs is not set
# CONFIG_PACKAGE_swap-utils is not set
# CONFIG_PACKAGE_sysfsutils is not set
# CONFIG_PACKAGE_tune2fs is not set
# CONFIG_PACKAGE_xfs-admin is not set
# CONFIG_PACKAGE_xfs-fsck is not set
# CONFIG_PACKAGE_xfs-growfs is not set
# CONFIG_PACKAGE_xfs-mkfs is not set
# end of Filesystem

#
# Image Manipulation
#
# CONFIG_PACKAGE_libjpeg-turbo-utils is not set
# CONFIG_PACKAGE_tiff-utils is not set
# end of Image Manipulation

#
# Microcontroller programming
#
# CONFIG_PACKAGE_avrdude is not set
# CONFIG_PACKAGE_dfu-programmer is not set
# CONFIG_PACKAGE_stm32flash is not set
# end of Microcontroller programming

#
# RTKLIB Suite
#
# CONFIG_PACKAGE_convbin is not set
# CONFIG_PACKAGE_pos2kml is not set
# CONFIG_PACKAGE_rnx2rtkp is not set
# CONFIG_PACKAGE_rtkrcv is not set
# CONFIG_PACKAGE_str2str is not set
# end of RTKLIB Suite

#
# SSL
#
# end of SSL

#
# Shells
#
CONFIG_PACKAGE_bash=y
# CONFIG_PACKAGE_fish is not set
# CONFIG_PACKAGE_klish is not set
# CONFIG_PACKAGE_mksh is not set
# CONFIG_PACKAGE_tcsh is not set
# CONFIG_PACKAGE_zsh is not set
# end of Shells

#
# Telephony
#
# CONFIG_PACKAGE_dahdi-cfg is not set
# CONFIG_PACKAGE_dahdi-monitor is not set
# CONFIG_PACKAGE_gsm-utils is not set
# CONFIG_PACKAGE_sipgrep is not set
# CONFIG_PACKAGE_sngrep is not set
# end of Telephony

#
# Terminal
#
# CONFIG_PACKAGE_agetty is not set
# CONFIG_PACKAGE_dvtm is not set
# CONFIG_PACKAGE_kitty-terminfo is not set
# CONFIG_PACKAGE_minicom is not set
# CONFIG_PACKAGE_picocom is not set
# CONFIG_PACKAGE_rtty-mbedtls is not set
# CONFIG_PACKAGE_rtty-nossl is not set
# CONFIG_PACKAGE_rtty-openssl is not set
# CONFIG_PACKAGE_rtty-wolfssl is not set
# CONFIG_PACKAGE_screen is not set
# CONFIG_PACKAGE_script-utils is not set
# CONFIG_PACKAGE_serialconsole is not set
# CONFIG_PACKAGE_setterm is not set
# CONFIG_PACKAGE_tio is not set
# CONFIG_PACKAGE_tmux is not set
CONFIG_PACKAGE_ttyd=y
# CONFIG_PACKAGE_wall is not set
# end of Terminal

#
# Userspace GPIO Drivers
#
# end of Userspace GPIO Drivers

#
# Virtualization
#
# end of Virtualization

#
# Zoneinfo
#
# CONFIG_PACKAGE_zoneinfo-africa is not set
# CONFIG_PACKAGE_zoneinfo-all is not set
# CONFIG_PACKAGE_zoneinfo-asia is not set
# CONFIG_PACKAGE_zoneinfo-atlantic is not set
# CONFIG_PACKAGE_zoneinfo-australia-nz is not set
# CONFIG_PACKAGE_zoneinfo-core is not set
# CONFIG_PACKAGE_zoneinfo-europe is not set
# CONFIG_PACKAGE_zoneinfo-india is not set
# CONFIG_PACKAGE_zoneinfo-northamerica is not set
# CONFIG_PACKAGE_zoneinfo-pacific is not set
# CONFIG_PACKAGE_zoneinfo-poles is not set
# CONFIG_PACKAGE_zoneinfo-simple is not set
# CONFIG_PACKAGE_zoneinfo-southamerica is not set
# end of Zoneinfo

#
# libimobiledevice
#
# CONFIG_PACKAGE_idevicerestore is not set
# CONFIG_PACKAGE_irecovery is not set
# CONFIG_PACKAGE_libimobiledevice-utils is not set
# CONFIG_PACKAGE_libusbmuxd-utils is not set
# CONFIG_PACKAGE_plistutil is not set
# CONFIG_PACKAGE_usbmuxd is not set
# end of libimobiledevice

#
# libselinux tools
#
# CONFIG_PACKAGE_libselinux-avcstat is not set
# CONFIG_PACKAGE_libselinux-compute_av is not set
# CONFIG_PACKAGE_libselinux-compute_create is not set
# CONFIG_PACKAGE_libselinux-compute_member is not set
# CONFIG_PACKAGE_libselinux-compute_relabel is not set
# CONFIG_PACKAGE_libselinux-getconlist is not set
# CONFIG_PACKAGE_libselinux-getdefaultcon is not set
# CONFIG_PACKAGE_libselinux-getenforce is not set
# CONFIG_PACKAGE_libselinux-getfilecon is not set
# CONFIG_PACKAGE_libselinux-getpidcon is not set
# CONFIG_PACKAGE_libselinux-getsebool is not set
# CONFIG_PACKAGE_libselinux-getseuser is not set
# CONFIG_PACKAGE_libselinux-matchpathcon is not set
# CONFIG_PACKAGE_libselinux-policyvers is not set
# CONFIG_PACKAGE_libselinux-sefcontext_compile is not set
# CONFIG_PACKAGE_libselinux-selabel_digest is not set
# CONFIG_PACKAGE_libselinux-selabel_get_digests_all_partial_matches is not set
# CONFIG_PACKAGE_libselinux-selabel_lookup is not set
# CONFIG_PACKAGE_libselinux-selabel_lookup_best_match is not set
# CONFIG_PACKAGE_libselinux-selabel_partial_match is not set
# CONFIG_PACKAGE_libselinux-selinux_check_access is not set
# CONFIG_PACKAGE_libselinux-selinux_check_securetty_context is not set
# CONFIG_PACKAGE_libselinux-selinuxenabled is not set
# CONFIG_PACKAGE_libselinux-selinuxexeccon is not set
# CONFIG_PACKAGE_libselinux-setenforce is not set
# CONFIG_PACKAGE_libselinux-setfilecon is not set
# CONFIG_PACKAGE_libselinux-togglesebool is not set
# CONFIG_PACKAGE_libselinux-validatetrans is not set
# end of libselinux tools

# CONFIG_PACKAGE_ack is not set
# CONFIG_PACKAGE_acpid is not set
# CONFIG_PACKAGE_adb is not set
# CONFIG_PACKAGE_airos-dfs-reset is not set
# CONFIG_PACKAGE_ap51-flash is not set
# CONFIG_PACKAGE_apk is not set
# CONFIG_PACKAGE_at is not set
# CONFIG_PACKAGE_atheepmgr is not set
# CONFIG_PACKAGE_audit is not set
# CONFIG_PACKAGE_audit-utils is not set
# CONFIG_PACKAGE_augeas is not set
# CONFIG_PACKAGE_augeas-lenses is not set
# CONFIG_PACKAGE_augeas-lenses-tests is not set
# CONFIG_PACKAGE_bandwidthd is not set
# CONFIG_PACKAGE_bandwidthd-pgsql is not set
# CONFIG_PACKAGE_bandwidthd-php is not set
# CONFIG_PACKAGE_bandwidthd-sqlite is not set
# CONFIG_PACKAGE_banhostlist is not set
# CONFIG_PACKAGE_bc is not set
# CONFIG_PACKAGE_bluelog is not set
# CONFIG_PACKAGE_bluez-daemon is not set
# CONFIG_PACKAGE_bluez-tools is not set
# CONFIG_PACKAGE_bluez-utils is not set
# CONFIG_PACKAGE_bluez-utils-extra is not set
# CONFIG_PACKAGE_bluld is not set
# CONFIG_PACKAGE_bonniexx is not set
# CONFIG_PACKAGE_bossa is not set
# CONFIG_PACKAGE_bottlerocket is not set
# CONFIG_PACKAGE_bsdiff is not set
# CONFIG_PACKAGE_bspatch is not set
# CONFIG_PACKAGE_byobu is not set
# CONFIG_PACKAGE_byobu-utils is not set
# CONFIG_PACKAGE_cache-domains-mbedtls is not set
# CONFIG_PACKAGE_cache-domains-openssl is not set
# CONFIG_PACKAGE_cache-domains-wolfssl is not set
# CONFIG_PACKAGE_cal is not set
# CONFIG_PACKAGE_canutils is not set
# CONFIG_PACKAGE_catatonit is not set
# CONFIG_PACKAGE_cgroup-tools is not set
# CONFIG_PACKAGE_cgroupfs-mount is not set
# CONFIG_PACKAGE_checkpolicy is not set
# CONFIG_PACKAGE_checksec is not set
# CONFIG_PACKAGE_checksec_automator is not set
# CONFIG_PACKAGE_chkcon is not set
# CONFIG_PACKAGE_clocate is not set
# CONFIG_PACKAGE_cmdpad is not set
# CONFIG_PACKAGE_cni is not set
# CONFIG_PACKAGE_cni-plugins is not set
# CONFIG_PACKAGE_cni-plugins-nft is not set
# CONFIG_PACKAGE_coap-client is not set
# CONFIG_PACKAGE_collectd is not set
# CONFIG_PACKAGE_conmon is not set
# CONFIG_PACKAGE_containerd is not set
# CONFIG_PACKAGE_coremark is not set
CONFIG_PACKAGE_coreutils=y
# CONFIG_PACKAGE_coreutils-b2sum is not set
# CONFIG_PACKAGE_coreutils-base32 is not set
CONFIG_PACKAGE_coreutils-base64=y
# CONFIG_PACKAGE_coreutils-basename is not set
# CONFIG_PACKAGE_coreutils-basenc is not set
# CONFIG_PACKAGE_coreutils-cat is not set
# CONFIG_PACKAGE_coreutils-chcon is not set
# CONFIG_PACKAGE_coreutils-chgrp is not set
# CONFIG_PACKAGE_coreutils-chmod is not set
# CONFIG_PACKAGE_coreutils-chown is not set
# CONFIG_PACKAGE_coreutils-chroot is not set
# CONFIG_PACKAGE_coreutils-cksum is not set
# CONFIG_PACKAGE_coreutils-comm is not set
# CONFIG_PACKAGE_coreutils-cp is not set
# CONFIG_PACKAGE_coreutils-csplit is not set
# CONFIG_PACKAGE_coreutils-cut is not set
# CONFIG_PACKAGE_coreutils-date is not set
# CONFIG_PACKAGE_coreutils-dd is not set
# CONFIG_PACKAGE_coreutils-df is not set
# CONFIG_PACKAGE_coreutils-dir is not set
# CONFIG_PACKAGE_coreutils-dircolors is not set
# CONFIG_PACKAGE_coreutils-dirname is not set
# CONFIG_PACKAGE_coreutils-du is not set
# CONFIG_PACKAGE_coreutils-echo is not set
# CONFIG_PACKAGE_coreutils-env is not set
# CONFIG_PACKAGE_coreutils-expand is not set
# CONFIG_PACKAGE_coreutils-expr is not set
# CONFIG_PACKAGE_coreutils-factor is not set
# CONFIG_PACKAGE_coreutils-false is not set
# CONFIG_PACKAGE_coreutils-fmt is not set
# CONFIG_PACKAGE_coreutils-fold is not set
# CONFIG_PACKAGE_coreutils-groups is not set
# CONFIG_PACKAGE_coreutils-head is not set
# CONFIG_PACKAGE_coreutils-hostid is not set
# CONFIG_PACKAGE_coreutils-id is not set
# CONFIG_PACKAGE_coreutils-install is not set
# CONFIG_PACKAGE_coreutils-join is not set
# CONFIG_PACKAGE_coreutils-kill is not set
# CONFIG_PACKAGE_coreutils-link is not set
# CONFIG_PACKAGE_coreutils-ln is not set
# CONFIG_PACKAGE_coreutils-logname is not set
# CONFIG_PACKAGE_coreutils-ls is not set
# CONFIG_PACKAGE_coreutils-md5sum is not set
# CONFIG_PACKAGE_coreutils-mkdir is not set
# CONFIG_PACKAGE_coreutils-mkfifo is not set
# CONFIG_PACKAGE_coreutils-mknod is not set
# CONFIG_PACKAGE_coreutils-mktemp is not set
# CONFIG_PACKAGE_coreutils-mv is not set
# CONFIG_PACKAGE_coreutils-nice is not set
# CONFIG_PACKAGE_coreutils-nl is not set
CONFIG_PACKAGE_coreutils-nohup=y
# CONFIG_PACKAGE_coreutils-nproc is not set
# CONFIG_PACKAGE_coreutils-numfmt is not set
# CONFIG_PACKAGE_coreutils-od is not set
# CONFIG_PACKAGE_coreutils-paste is not set
# CONFIG_PACKAGE_coreutils-pathchk is not set
# CONFIG_PACKAGE_coreutils-pinky is not set
# CONFIG_PACKAGE_coreutils-pr is not set
# CONFIG_PACKAGE_coreutils-printenv is not set
# CONFIG_PACKAGE_coreutils-printf is not set
# CONFIG_PACKAGE_coreutils-ptx is not set
# CONFIG_PACKAGE_coreutils-pwd is not set
# CONFIG_PACKAGE_coreutils-readlink is not set
# CONFIG_PACKAGE_coreutils-realpath is not set
# CONFIG_PACKAGE_coreutils-rm is not set
# CONFIG_PACKAGE_coreutils-rmdir is not set
# CONFIG_PACKAGE_coreutils-runcon is not set
# CONFIG_PACKAGE_coreutils-seq is not set
# CONFIG_PACKAGE_coreutils-sha1sum is not set
# CONFIG_PACKAGE_coreutils-sha224sum is not set
# CONFIG_PACKAGE_coreutils-sha256sum is not set
# CONFIG_PACKAGE_coreutils-sha384sum is not set
# CONFIG_PACKAGE_coreutils-sha512sum is not set
# CONFIG_PACKAGE_coreutils-shred is not set
# CONFIG_PACKAGE_coreutils-shuf is not set
# CONFIG_PACKAGE_coreutils-sleep is not set
# CONFIG_PACKAGE_coreutils-sort is not set
# CONFIG_PACKAGE_coreutils-split is not set
# CONFIG_PACKAGE_coreutils-stat is not set
# CONFIG_PACKAGE_coreutils-stdbuf is not set
# CONFIG_PACKAGE_coreutils-stty is not set
# CONFIG_PACKAGE_coreutils-sum is not set
# CONFIG_PACKAGE_coreutils-sync is not set
# CONFIG_PACKAGE_coreutils-tac is not set
# CONFIG_PACKAGE_coreutils-tail is not set
# CONFIG_PACKAGE_coreutils-tee is not set
# CONFIG_PACKAGE_coreutils-test is not set
# CONFIG_PACKAGE_coreutils-timeout is not set
# CONFIG_PACKAGE_coreutils-touch is not set
# CONFIG_PACKAGE_coreutils-tr is not set
# CONFIG_PACKAGE_coreutils-true is not set
# CONFIG_PACKAGE_coreutils-truncate is not set
# CONFIG_PACKAGE_coreutils-tsort is not set
# CONFIG_PACKAGE_coreutils-tty is not set
# CONFIG_PACKAGE_coreutils-uname is not set
# CONFIG_PACKAGE_coreutils-unexpand is not set
# CONFIG_PACKAGE_coreutils-uniq is not set
# CONFIG_PACKAGE_coreutils-unlink is not set
# CONFIG_PACKAGE_coreutils-uptime is not set
# CONFIG_PACKAGE_coreutils-users is not set
# CONFIG_PACKAGE_coreutils-vdir is not set
# CONFIG_PACKAGE_coreutils-wc is not set
# CONFIG_PACKAGE_coreutils-who is not set
# CONFIG_PACKAGE_coreutils-whoami is not set
# CONFIG_PACKAGE_coreutils-yes is not set
# CONFIG_PACKAGE_crconf is not set
# CONFIG_PACKAGE_crelay is not set
# CONFIG_PACKAGE_crun is not set
# CONFIG_PACKAGE_csstidy is not set
# CONFIG_PACKAGE_ct-bugcheck is not set
# CONFIG_PACKAGE_ctop is not set
# CONFIG_PACKAGE_dbus is not set
# CONFIG_PACKAGE_dbus-utils is not set
# CONFIG_PACKAGE_device-observatory is not set
# CONFIG_PACKAGE_dfu-util is not set
# CONFIG_PACKAGE_digitemp is not set
# CONFIG_PACKAGE_digitemp-usb is not set
# CONFIG_PACKAGE_dmesg is not set
# CONFIG_PACKAGE_docker is not set
# CONFIG_PACKAGE_docker-compose is not set
# CONFIG_PACKAGE_dockerd is not set
# CONFIG_PACKAGE_domoticz is not set
# CONFIG_PACKAGE_dropbearconvert is not set
# CONFIG_PACKAGE_dtc is not set
# CONFIG_PACKAGE_dumb-init is not set
# CONFIG_PACKAGE_dump1090 is not set
# CONFIG_PACKAGE_ecdsautils is not set
# CONFIG_PACKAGE_elektra-kdb is not set
# CONFIG_PACKAGE_evtest is not set
# CONFIG_PACKAGE_extract is not set
# CONFIG_PACKAGE_fdt-utils is not set
# CONFIG_PACKAGE_file is not set
# CONFIG_PACKAGE_filebrowser is not set
# CONFIG_PACKAGE_findutils is not set
# CONFIG_PACKAGE_findutils-find is not set
# CONFIG_PACKAGE_findutils-locate is not set
# CONFIG_PACKAGE_findutils-xargs is not set
# CONFIG_PACKAGE_flashrom is not set
# CONFIG_PACKAGE_flashrom-pci is not set
# CONFIG_PACKAGE_flashrom-spi is not set
# CONFIG_PACKAGE_flashrom-usb is not set
# CONFIG_PACKAGE_flent-tools is not set
# CONFIG_PACKAGE_flock is not set
# CONFIG_PACKAGE_fritz-caldata is not set
# CONFIG_PACKAGE_fritz-tffs is not set
# CONFIG_PACKAGE_fritz-tffs-nand is not set
# CONFIG_PACKAGE_ftdi_eeprom is not set
# CONFIG_PACKAGE_fuse-overlayfs is not set
# CONFIG_PACKAGE_gammu is not set
# CONFIG_PACKAGE_gawk is not set
# CONFIG_PACKAGE_gddrescue is not set
# CONFIG_PACKAGE_getopt is not set
# CONFIG_PACKAGE_giflib-utils is not set
# CONFIG_PACKAGE_gkermit is not set
# CONFIG_PACKAGE_gl-puli-mcu is not set
# CONFIG_PACKAGE_gnuplot is not set
# CONFIG_PACKAGE_gpioctl-sysfs is not set
# CONFIG_PACKAGE_gpiod-tools is not set
# CONFIG_PACKAGE_gpsd is not set
# CONFIG_PACKAGE_gpsd-clients is not set
# CONFIG_PACKAGE_gpsd-utils is not set
# CONFIG_PACKAGE_grep is not set
# CONFIG_PACKAGE_hamlib is not set
# CONFIG_PACKAGE_haserl is not set
# CONFIG_PACKAGE_hashdeep is not set
# CONFIG_PACKAGE_haveged is not set
# CONFIG_PACKAGE_hplip-common is not set
# CONFIG_PACKAGE_hplip-sane is not set
# CONFIG_PACKAGE_hub-ctrl is not set
# CONFIG_PACKAGE_hwclock is not set
# CONFIG_PACKAGE_hwinfo is not set
# CONFIG_PACKAGE_hwloc-utils is not set
# CONFIG_PACKAGE_i2c-tools is not set
# CONFIG_PACKAGE_iconv is not set
# CONFIG_PACKAGE_iio-utils is not set
# CONFIG_PACKAGE_inotifywait is not set
# CONFIG_PACKAGE_inotifywatch is not set
# CONFIG_PACKAGE_io is not set
# CONFIG_PACKAGE_ipcs is not set
# CONFIG_PACKAGE_ipfs-http-client-tests is not set
# CONFIG_PACKAGE_irqbalance is not set
# CONFIG_PACKAGE_iwcap is not set
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_jshn=y
# CONFIG_PACKAGE_kmod is not set
# CONFIG_PACKAGE_lcd4linux-custom is not set
# CONFIG_PACKAGE_lcdproc-clients is not set
# CONFIG_PACKAGE_lcdproc-drivers is not set
# CONFIG_PACKAGE_lcdproc-server is not set
# CONFIG_PACKAGE_less is not set
CONFIG_PACKAGE_libjson-script=y
# CONFIG_PACKAGE_libnetwork is not set
CONFIG_PACKAGE_libucode=y
# CONFIG_PACKAGE_libxml2-utils is not set
# CONFIG_PACKAGE_lm-sensors is not set
# CONFIG_PACKAGE_lm-sensors-detect is not set
# CONFIG_PACKAGE_logger is not set
# CONFIG_PACKAGE_logrotate is not set
# CONFIG_PACKAGE_lolcat is not set
# CONFIG_PACKAGE_look is not set
# CONFIG_PACKAGE_losetup is not set
# CONFIG_PACKAGE_lrzsz is not set
# CONFIG_PACKAGE_lscpu is not set
# CONFIG_PACKAGE_lslocks is not set
# CONFIG_PACKAGE_lsns is not set
# CONFIG_PACKAGE_lsof is not set
# CONFIG_PACKAGE_lxc is not set
# CONFIG_PACKAGE_maccalc is not set
# CONFIG_PACKAGE_macchanger is not set
# CONFIG_PACKAGE_mandoc is not set
# CONFIG_PACKAGE_mbedtls-util is not set
# CONFIG_PACKAGE_mbim-utils is not set
# CONFIG_PACKAGE_mbtools is not set
# CONFIG_PACKAGE_mc is not set
# CONFIG_PACKAGE_mc-skins is not set
# CONFIG_PACKAGE_mcookie is not set
# CONFIG_PACKAGE_mdio-tools is not set
# CONFIG_PACKAGE_micrond is not set
# CONFIG_PACKAGE_miniflux is not set
# CONFIG_PACKAGE_mmc-utils is not set
# CONFIG_PACKAGE_more is not set
# CONFIG_PACKAGE_moreutils is not set
# CONFIG_PACKAGE_mosh-client is not set
# CONFIG_PACKAGE_mosh-server is not set
# CONFIG_PACKAGE_mount-utils is not set
# CONFIG_PACKAGE_mpack is not set
# CONFIG_PACKAGE_mqttled is not set
# CONFIG_PACKAGE_mt-st is not set
# CONFIG_PACKAGE_namei is not set
# CONFIG_PACKAGE_nand-utils is not set
# CONFIG_PACKAGE_naywatch is not set
# CONFIG_PACKAGE_netopeer2-cli is not set
# CONFIG_PACKAGE_netopeer2-server is not set
# CONFIG_PACKAGE_netwhere is not set
# CONFIG_PACKAGE_nnn is not set
# CONFIG_PACKAGE_nsenter is not set
# CONFIG_PACKAGE_nss-utils is not set
# CONFIG_PACKAGE_nsutils is not set
# CONFIG_PACKAGE_oath-toolkit is not set
# CONFIG_PACKAGE_oci-runtime-tool is not set
# CONFIG_PACKAGE_open-plc-utils is not set
# CONFIG_PACKAGE_open2300 is not set
# CONFIG_PACKAGE_openobex is not set
# CONFIG_PACKAGE_openobex-apps is not set
# CONFIG_PACKAGE_openocd is not set
# CONFIG_PACKAGE_opensc-utils is not set
CONFIG_PACKAGE_openssl-util=y
# CONFIG_PACKAGE_openzwave is not set
# CONFIG_PACKAGE_openzwave-config is not set
# CONFIG_PACKAGE_owipcalc is not set
# CONFIG_PACKAGE_passh is not set
# CONFIG_PACKAGE_pciids is not set
# CONFIG_PACKAGE_pciutils is not set
# CONFIG_PACKAGE_pcsc-tools is not set
# CONFIG_PACKAGE_pcscd is not set
# CONFIG_PACKAGE_podman is not set

#
# Configuration
#
# CONFIG_PODMAN_SELINUX_SUPPORT is not set
# CONFIG_PODMAN_IPTABLES_FW is not set
# end of Configuration

# CONFIG_PACKAGE_poemgr is not set
# CONFIG_PACKAGE_policycoreutils is not set
# CONFIG_PACKAGE_powertop is not set
# CONFIG_PACKAGE_pps-tools is not set
# CONFIG_PACKAGE_prlimit is not set
# CONFIG_PACKAGE_procps-ng is not set
# CONFIG_PACKAGE_progress is not set
# CONFIG_PACKAGE_prometheus is not set
# CONFIG_PACKAGE_prometheus-node-exporter-lua is not set
# CONFIG_PACKAGE_prometheus-statsd-exporter is not set
# CONFIG_PACKAGE_pservice is not set
# CONFIG_PACKAGE_psmisc is not set
# CONFIG_PACKAGE_pv is not set
# CONFIG_PACKAGE_qmi-utils is not set
# CONFIG_PACKAGE_qrencode is not set
# CONFIG_PACKAGE_quota is not set
# CONFIG_PACKAGE_ravpower-mcu is not set
# CONFIG_PACKAGE_readsb is not set
# CONFIG_PACKAGE_relayctl is not set
# CONFIG_PACKAGE_rename is not set
# CONFIG_PACKAGE_restic is not set
# CONFIG_PACKAGE_rng-tools is not set
# CONFIG_PACKAGE_rtl-ais is not set
# CONFIG_PACKAGE_rtl-sdr is not set
# CONFIG_PACKAGE_rtl_433 is not set
# CONFIG_PACKAGE_rtl_433-ssl is not set
# CONFIG_PACKAGE_runc is not set
# CONFIG_PACKAGE_sane-backends is not set
# CONFIG_PACKAGE_sane-daemon is not set
# CONFIG_PACKAGE_sane-frontends is not set
# CONFIG_PACKAGE_secilc is not set
# CONFIG_PACKAGE_sed is not set
# CONFIG_PACKAGE_selinux-audit2allow is not set
# CONFIG_PACKAGE_selinux-chcat is not set
# CONFIG_PACKAGE_selinux-semanage is not set
# CONFIG_PACKAGE_semodule-utils is not set
# CONFIG_PACKAGE_serdisplib-tools is not set
# CONFIG_PACKAGE_setools is not set
# CONFIG_PACKAGE_setserial is not set
# CONFIG_PACKAGE_sexpect is not set
# CONFIG_PACKAGE_shadow-utils is not set
# CONFIG_PACKAGE_shared-mime-info is not set
# CONFIG_PACKAGE_sipcalc is not set
# CONFIG_PACKAGE_sispmctl is not set
# CONFIG_PACKAGE_slide-switch is not set
# CONFIG_PACKAGE_smartd is not set
# CONFIG_PACKAGE_smartd-mail is not set
# CONFIG_PACKAGE_smartmontools is not set
# CONFIG_PACKAGE_smartmontools-drivedb is not set
# CONFIG_PACKAGE_smstools3 is not set
# CONFIG_PACKAGE_sockread is not set
# CONFIG_PACKAGE_spi-tools is not set
# CONFIG_PACKAGE_spidev-test is not set
# CONFIG_PACKAGE_ssdeep is not set
# CONFIG_PACKAGE_sshpass is not set
# CONFIG_PACKAGE_strace is not set
CONFIG_STRACE_NONE=y
# CONFIG_STRACE_LIBDW is not set
# CONFIG_STRACE_LIBUNWIND is not set
# CONFIG_PACKAGE_stress is not set
# CONFIG_PACKAGE_stress-ng is not set
# CONFIG_PACKAGE_sumo is not set
# CONFIG_PACKAGE_syncthing is not set
# CONFIG_PACKAGE_sysrepo is not set
# CONFIG_PACKAGE_sysrepocfg is not set
# CONFIG_PACKAGE_sysrepoctl is not set
# CONFIG_PACKAGE_sysstat is not set
# CONFIG_PACKAGE_tar is not set
# CONFIG_PACKAGE_taskd is not set
# CONFIG_PACKAGE_taskset is not set
# CONFIG_PACKAGE_taskwarrior is not set
# CONFIG_PACKAGE_telegraf is not set
# CONFIG_PACKAGE_telegraf-full is not set
# CONFIG_PACKAGE_telldus-core is not set
# CONFIG_PACKAGE_temperusb is not set
# CONFIG_PACKAGE_tesseract is not set
# CONFIG_PACKAGE_tini is not set
# CONFIG_PACKAGE_tinyionice is not set
# CONFIG_PACKAGE_tracertools is not set
# CONFIG_PACKAGE_tree is not set
# CONFIG_PACKAGE_triggerhappy is not set
CONFIG_PACKAGE_ubi-utils=y
# CONFIG_PACKAGE_ubnt-manager is not set
CONFIG_PACKAGE_ucode=y
CONFIG_PACKAGE_ucode-mod-fs=y
# CONFIG_PACKAGE_ucode-mod-lua is not set
# CONFIG_PACKAGE_ucode-mod-math is not set
# CONFIG_PACKAGE_ucode-mod-nl80211 is not set
# CONFIG_PACKAGE_ucode-mod-resolv is not set
# CONFIG_PACKAGE_ucode-mod-rtnl is not set
# CONFIG_PACKAGE_ucode-mod-struct is not set
CONFIG_PACKAGE_ucode-mod-ubus=y
CONFIG_PACKAGE_ucode-mod-uci=y
# CONFIG_PACKAGE_udns-dnsget is not set
# CONFIG_PACKAGE_udns-ex-rdns is not set
# CONFIG_PACKAGE_udns-rblcheck is not set
# CONFIG_PACKAGE_ugps is not set
# CONFIG_PACKAGE_uhubctl is not set
# CONFIG_PACKAGE_uledd is not set
# CONFIG_PACKAGE_unshare is not set
# CONFIG_PACKAGE_usb-modeswitch is not set
# CONFIG_PACKAGE_usbids is not set
CONFIG_PACKAGE_usbutils=y
# CONFIG_PACKAGE_uuidd is not set
# CONFIG_PACKAGE_uuidgen is not set
# CONFIG_PACKAGE_uvcdynctrl is not set
# CONFIG_PACKAGE_v4l-utils is not set
# CONFIG_PACKAGE_view1090 is not set
# CONFIG_PACKAGE_viewadsb is not set
CONFIG_PACKAGE_watchcat=y
# CONFIG_PACKAGE_whereis is not set
# CONFIG_PACKAGE_which is not set
# CONFIG_PACKAGE_whiptail is not set
# CONFIG_PACKAGE_whois is not set
# CONFIG_PACKAGE_wifitoggle is not set
# CONFIG_PACKAGE_wipe is not set
# CONFIG_PACKAGE_xsltproc is not set
# CONFIG_PACKAGE_xxd is not set
# CONFIG_PACKAGE_yanglint is not set
# CONFIG_PACKAGE_yara is not set
# CONFIG_PACKAGE_ykclient is not set
# CONFIG_PACKAGE_ykpers is not set
# CONFIG_PACKAGE_yq is not set
# end of Utilities

#
# Xorg
#

#
# Font-Utils
#
# CONFIG_PACKAGE_fontconfig is not set
# end of Font-Utils
# end of Xorg
EOF
}

config_test() {
    config_func
    #=========================================
    # 测试域
    #=========================================
    cat >> .config << EOF
CONFIG_PACKAGE_luci-app-ledtrig-rssi=y
CONFIG_PACKAGE_luci-app-ledtrig-switch=y
CONFIG_PACKAGE_luci-app-ledtrig-usbport=y
CONFIG_PACKAGE_luci-app-uhttpd=y
CONFIG_PACKAGE_luci-app-unblockmusic=y
CONFIG_PACKAGE_luci-app-adblock=y
CONFIG_PACKAGE_luci-app-tinyproxy=y
CONFIG_PACKAGE_luci-app-wireguard=y
CONFIG_PACKAGE_tcpdump-mini=y
EOF
}
