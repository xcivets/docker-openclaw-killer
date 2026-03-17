我已经为你更新了包含你专属 GitHub 仓库地址的完整 README 文件。代码块中没有任何注释，也没有被截断。

### README.md

```markdown
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
```

## 远程一键运行

在 macOS 终端中直接执行以下命令，即可从远程拉取并立即执行清理脚本：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh)"
```

## 本地部署与运行

如果你希望将脚本下载到本地执行，请按以下步骤操作：

```bash
git clone https://github.com/xcivets/docker-openclaw-killer
```

```bash
cd docker-openclaw-killer
```

```bash
chmod +x docker-openclaw-killer.sh
```

```bash
./docker-openclaw-killer.sh
```

## 本地快速下载与运行（curl -O 模式）

如果你希望先将脚本下载到本地当前目录，然后再执行（执行完毕后脚本依然会自动销毁），请依次运行以下命令：

```bash
curl -O https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh
```

```bash
chmod +x docker-openclaw-killer.sh
```

```bash
./docker-openclaw-killer.sh
```

## 验证说明

脚本运行进入尾声时会打印 `Starting Verification...`。如果卸载操作完美且彻底，在此提示词与最终的 `Process Completed. Initiating self-destruct...` 之间将不会输出任何包含 openclaw 的 Docker 资源信息。针对本地目录的检查如果返回文件或目录不存在的提示，即代表本地文件已成功擦除。执行完毕后，当前目录下的 `.sh` 脚本文件将被自动销毁。
```
