# Docker OpenClaw Killer

macOS 环境下基于 Docker 的 OpenClaw 完美一键卸载与彻底清理工具。具备用后即焚的自我销毁功能。

## 核心功能要点

* **强制停止并删除容器**：精准匹配并移除所有包含 openclaw 标识的活动或停止状态的 Docker 容器。
* **彻底清除镜像文件**：强制检索并删除本地所有的 OpenClaw Docker 镜像。
* **清理冗余数据卷**：识别并永久销毁 OpenClaw 运行时产生的所有关联 Docker 数据卷。
* **深度网络与缓存清理**：执行全局网络修剪，并清理未使用的系统缓存与悬空资源，释放磁盘空间。
* **擦除本地映射目录**：强制删除位于 macOS 用户主目录下的 `~/openclaw` 本地映射文件夹及其所有内容。
* **自动化双重验证**：在卸载流程结束后自动触发验证机制，遍历检查容器、镜像、数据卷、网络和本地目录，确保达成完美卸载。
* **无痕自我销毁**：脚本在执行完所有清理和验证任务后，会自动从系统中彻底删除自身文件，用完即走，不留任何痕迹（兼容本地运行与远程拉取模式）。

## 远程一键运行

在 macOS 终端中直接执行以下命令，即可从远程拉取并立即执行清理脚本：

```bash
bash -c "$(curl -fsSL [https://raw.githubusercontent.com/你的用户名/你的仓库名/main/docker-openclaw-killer.sh](https://raw.githubusercontent.com/你的用户名/你的仓库名/main/docker-openclaw-killer.sh))"
