# f2s

**简体中文** · [English](README.en.md)

从 Finder 工具栏用终端打开当前文件夹、复制路径或新建文件。支持 macOS 11 及以上版本，适用于 Apple 芯片和 Intel Mac。

<p>
  <img src="docs/images/finder-toolbar-menu.png" width="219" alt="Finder 工具栏中的 f2s 菜单，依次为 Open Shell、Copy Path、New File… 和 Quit f2s">
  <img src="docs/images/new-file-dialog.png" width="332" alt="New File 弹窗中，Release Notes 的完整目录路径分两行显示，文件名为 changelog.md">
</p>

## 安装

1. [下载最新版 f2s.dmg](https://github.com/yuki-node/f2s/releases/latest/download/f2s.dmg) 并双击打开。
2. 将 **f2s** 拖到 **Applications（应用程序）**。
3. 从「应用程序」打开 **f2s**，点击「启用 f2s」。

## 使用

在 Finder 中打开一个文件夹，点击工具栏上的 **f2s** 图标。

| 菜单 | 功能 |
| --- | --- |
| **Open Shell** | 用默认终端打开当前文件夹。 |
| **Copy Path** | 复制当前文件夹的完整路径。 |
| **New File…** | 输入文件名（如 `notes.txt` 或 `.gitignore`），按回车创建空文件。 |
| **Quit f2s** | 退出 f2s 并停用 Finder 扩展。 |

要使用 iTerm2，可在 iTerm2 菜单中选择 **Make iTerm2 Default Term**。

## 卸载

在工具栏菜单中选择 **Quit f2s**，再将「应用程序」中的 **f2s** 移到废纸篓。

## 从源码构建

安装 Xcode Command Line Tools 后，在终端运行以下命令。

```sh
git clone https://github.com/yuki-node/f2s.git
cd f2s
bash build.sh
```

输出文件为 `build/f2s.app` 和 `build/f2s.dmg`。默认构建使用本地临时签名。使用 Developer ID 签名时，设置 `APP_SIGNING_IDENTITY`。如需 Apple 公证，同时设置 `NOTARYTOOL_PROFILE`。

## 支持项目

[![请我喝杯咖啡，点击查看微信收款码](docs/images/buy-me-a-coffee.svg)](docs/images/wechat-pay.png)
