# OpenWrt x86_64 云编译（ImmortalWrt）

使用 GitHub Actions 在线编译 **ImmortalWrt x86_64** 固件，全部个性化定制集中在本仓库。

> 本仓库由私有库 `OpenWrt-Actions` 迁移而来，配置与定制**逐字节一致**（20 个文件已做 git blob SHA 校验）。

---

## 快速开始

1. 进入 **Actions** → 左侧选择 **OpenWrt-x86 Builder** → **Run workflow**
2. 分支选 `main`，点击运行
3. 约 **3～4 小时**后，到 **Releases** 下载固件

产物为 x86_64 generic 系列：`ext4-combined(-efi)`、`squashfs-combined(-efi)`、`rootfs`、`kernel.bin` 等。

---

## 定制内容

### 上游与 feeds

| 项 | 值 |
|---|---|
| 源码 | `immortalwrt/immortalwrt` @ `v25.12.2`（tag 锁定） |
| feeds | `packages` / `luci` / `routing` 按 **commit 锁定**（与 ImmortalWrt 官方发版配法一致） |
| 第三方 feed | `lucky`、`istore`、`bandix` + `bandixcore`、`partexp`（见 `diy-part1.sh`） |
| 额外引入 | `luci-app-onliner`（xuanranran fork，含中文） |

### 已选插件（`.config`，约 190 个包）

| 类别 | 内容 |
|---|---|
| 代理 / 网络 | `luci-app-openclash`、`luci-app-lucky`、`luci-app-upnp`、`miniupnpd-nftables` |
| 容器 | `docker` + `dockerd` + `docker-compose` + `luci-app-dockerman` |
| 去广告 | `adguardhome` + `luci-app-adguardhome` |
| 存储 | `luci-app-diskman`、`parted`、`resize2fs`、`btrfs-progs`、`f2fs-tools`、`exfat-*` |
| 文件管理 | `luci-app-filemanager`、`nano`、`vim` |
| 工具 | `luci-app-vlmcsd`、`luci-app-timewol`、`luci-app-autoreboot`、`luci-app-partexp`、`luci-app-bandix-plus`、`luci-app-onliner`、`luci-app-store` |
| 主题 | `luci-theme-argon` + `luci-app-argon-config` |
| 中文 | 全套 `luci-i18n-*-zh-cn`，`CONFIG_LUCI_LANG_zh_Hans=y` |
| 内核 | BBR、fullcone、tproxy、ipvs、`kmod-nft-*`、`kmod-ipt-*` 等 |

### argon 主题覆盖层（`files/`，16 个文件）

```
files/etc/config/network                                    676 B
files/etc/uci-defaults/99-set-zh-lang                       150 B   默认中文界面
files/usr/libexec/rpcd/luci.argon_wallpaper                3942 B   壁纸 rpcd 插件
files/usr/share/ucode/luci/template/themes/argon/*.ut   5 个模板
files/www/luci-static/argon/css/cascade.css              101551 B   定制样式
files/www/luci-static/argon/css/dark.css                  23553 B
files/www/luci-static/argon/icon/*.png/xml               5 个图标
```

> 说明：主题本体（字体 / 图片 / 图标等静态资源）由 feeds 的 `luci-theme-argon` 提供，
> 覆盖层只保留个性化文件 —— 已确认被移除的 24 个文件与自带版本逐字节相同。

### `diy-part2.sh` 里的两处关键修补

**① dockerd 构建修复**

moby 的 `hack/make/binary-daemon` 会从构建机 PATH 复制嵌套可执行文件
（containerd / runc / docker-init / rootlesskit 等）到 bundle，GitHub 镜像偶尔缺失，
导致 `cp: cannot stat ''` 编译失败。脚本用空 stub 补齐这 8 个工具。

**② 中文翻译修补 —— 两类包，处理方式相反**

| 类型 | 判定 | 处理 |
|---|---|---|
| **(A)** 走 `luci.mk` 的包 | `LUCI_LANGUAGES` 只认 `zh_Hans`/`zh_Hant`，`po/zh-cn` 会被整条跳过 | 目录改名 `po/zh-cn` → `po/zh_Hans` |
| **(B)** 自带翻译逻辑的包 | `luci-app-openclash` 不 include `luci.mk`，`zh-cn` **硬编码**在 Makefile 里，lmo 编进主包 | **绝对不能改名**，否则 `*.*.lmo` 落空导致构建中断 |

脚本对 `luci-app-onliner`、`luci-app-adguardhome`（注入自译译本）执行 (A)，
对 `luci-app-openclash` 执行 (B) 并做存在性自检。

---

## 构建流程与磁盘策略

| 步骤 | 作用 |
|---|---|
| `Free Disk Space` | 释放 runner 预装内容 |
| `Pre-build space check` | 清理残缺的 `tmp/` 中间文件；断言可用 ≥ **30 G** |
| `Purge ccache leftovers` | 兜底删除 `.ccache`（ccache 已停用） |
| `Clean Go module cache` | 避免跨构建污染 |
| `Disk rehearsal` | 编译前跑 180 s，量化磁盘消耗速率 |
| `Compile the firmware` | 含**磁盘守护**：每 60 s 检查，可用 < 3 G 立即中止，防止 runner 崩溃 |
| `Show build error tail` | 失败时输出 `df -hT` / `du -sh` 诊断 |

### 关于 ccache

**已停用**（`.config` 中 `CONFIG_CCACHE` 以注释保留，取消注释即可恢复）。原因：

- GitHub Actions 缓存每仓库限额 **10 GB**，而 ccache 需 5～15 GB，**跨 run 存不下**；
- 轮内复用收益小于其占用的数 GB 磁盘，而磁盘正是本项目瓶颈。

### ⚠️ 已知遗留问题

实测编译期间：

```
dl           2.6 G
build_dir     35 G      ← 主要消耗
staging_dir  3.4 G
────────────────────
合计约 41 G，而编译起始仅 44.6 G 可用（基础镜像已占 27 G）
```

**`build_dir` 的 35 G 会触及 72 G 分区上限。** 曾尝试通过 ccache 上限、
清理 `tmp/`、去掉重试链等方式缓解，但 `build_dir` 才是根因。
后续优化方向：**分段编译 + 打包前清理中间产物**（产物已进 `bin/`，中间件可安全删除）。

---

## 文件说明

| 路径 | 用途 |
|---|---|
| `.config` | 编译配置（约 190 个包） |
| `diy-part1.sh` | feeds update **之前**执行：添加第三方 feed、引入 onliner |
| `diy-part2.sh` | feeds install **之后**执行：dockerd 修复、中文翻译修补 |
| `feeds.conf.default` | feeds 定义（commit 锁定） |
| `files/` | 覆盖到固件的个性化文件（argon 主题等） |
| `.github/workflows/openwrt-x86.yml` | 构建流程 |

---

## 许可证

MIT
