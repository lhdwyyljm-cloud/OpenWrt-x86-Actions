#!/bin/bash
# diy-part1.sh —— 在 feeds update 之前执行：追加第三方 feeds
#
# 基线：ImmortalWrt v25.12.2（见 feeds.conf.default）
# 说明：OpenClash / dockerman / diskman / autoreboot / timewol / vlmcsd /
#       adguardhome / argon-config 由 ImmortalWrt 自带 feed 提供，此处不再重复
#       引入 —— 第三方同名 feed（vernesong/lisaac）会与自带同名包构成重复包名，
#       feeds install 后 build 直接报错。
# 注意：ImmortalWrt 自带并不等于中文完整。以下两处中文缺失，已在 diy-part2.sh 修补
#       （必须等 feeds install 之后目录才存在，否则改不到）：
#       - luci-app-openclash：po 目录是旧式 po/zh-cn，会被 luci.mk 整条跳过
#       - luci-app-adguardhome：po 里只有老挝语，模板 28 条 msgid 全无中文
#
# 注意：OpenWrt feeds 解析脚本要求 feed 名只能为 [a-zA-Z0-9_]，不能带连字符（见 scripts/feeds 正则 \w+）

# --- ImmortalWrt 与官方源都未收录的第三方插件，各自上游 ---

# Lucky —— 内网穿透 / DDNS / 端口转发 / Web 服务（含本体 lucky + luci-app-lucky）
echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git;main' >> feeds.conf.default

# iStore 插件商店（同时提供 taskd / luci-lib-taskd / luci-lib-xterm）
echo 'src-git istore https://github.com/linkease/istore.git;main' >> feeds.conf.default

# Bandix-Plus 带宽测速（LuCI 界面 + 本体）
echo 'src-git bandix https://github.com/timsaya/luci-app-bandix-plus.git;main' >> feeds.conf.default
echo 'src-git bandixcore https://github.com/timsaya/openwrt-bandix-plus.git;main' >> feeds.conf.default

# luci-app-partexp 一键分区扩容
echo 'src-git partexp https://github.com/sirpdboy/luci-app-partexp.git;main' >> feeds.conf.default

# --- ImmortalWrt 也没有的：用原作者仓库，复制到 package/ 绕过 feed 扫描 ---
# luci-app-onliner 在线用户（xuanranran fork，含中文）
git clone --depth 1 -b master https://github.com/xuanranran/luci-app-onliner.git /tmp/iw-onliner
cp -r /tmp/iw-onliner package/luci-app-onliner
rm -rf package/luci-app-onliner/.git
sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' package/luci-app-onliner/Makefile
# xuanranran 的 po 放在 po/zh-cn/（老式语言码），但 luci.mk 的翻译开关只认 zh_Hans
# 重命名目录 po/zh-cn -> po/zh_Hans，使 LUCI_LANG.zh_Hans 命中，编译出 luci-i18n-onliner-zh-cn
if [ -d package/luci-app-onliner/po/zh-cn ]; then
  mkdir -p package/luci-app-onliner/po/zh_Hans
  mv package/luci-app-onliner/po/zh-cn/*.po package/luci-app-onliner/po/zh_Hans/ 2>/dev/null
  rmdir package/luci-app-onliner/po/zh-cn 2>/dev/null
fi
