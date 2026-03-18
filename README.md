# Docker OpenClaw Killer Safe

面向 macOS / Linux 的 OpenClaw Docker 清理脚本，目标是“尽量彻底”而不是“盲目全删”。

它会按较窄的匹配规则扫描并清理 OpenClaw 相关的 Docker 容器、卷、网络，并可选清理镜像；同时对本地目录删除做额外路径校验，避免误删非 OpenClaw 数据。

## 设计目标

- 默认安全优先，不执行 `docker system prune`
- 不自删除脚本
- 默认不删除镜像，只有显式传入 `--remove-images` 才会处理
- 支持 `--dry-run` 预演
- 执行前展示清理计划，并在非 `--yes` 模式下要求确认
- 执行后进行验证，验证失败时返回非零退出码

## 清理范围

脚本会独立扫描以下资源，而不是只依赖容器反推，因此可以发现孤立资源：

- 容器
- 镜像，需配合 `--remove-images`
- 数据卷
- 网络
- 本地目录，默认目标为 `~/openclaw`

本地目录只有在满足以下条件时才会被删除：

- 路径真实存在
- 解析后的真实路径位于 `$HOME` 下
- 路径不是 `/` 或 `$HOME`
- 目录名中包含 `openclaw`

如果目录不满足这些条件，脚本会拒绝删除并给出警告。

## 默认匹配规则

默认规则故意收紧，避免把名称里“碰巧包含 openclaw”的其他资源一并删除。

```text
容器 / 卷 / 网络名称:
^openclaw([._-].+)?$

镜像引用:
(^|.*/)openclaw([._-].+)?(:[^/]+)?$
```

如果你的命名规则不同，可以通过环境变量覆盖：

```bash
OPENCLAW_NAME_REGEX='^my-openclaw-.*$' \
OPENCLAW_IMAGE_REGEX='(^|.*/)my-openclaw(:.*)?$' \
./docker-openclaw-killer.safe.sh --dry-run
```

## 依赖要求

- 已安装 `docker`
- Docker daemon 正在运行
- 当前用户有权限执行相关 Docker 命令

## 从 GitHub 远程使用

项目仓库：

```text
https://github.com/xcivets/docker-openclaw-killer
```

默认分支已确认是 `main`。

如果 `docker-openclaw-killer.safe.sh` 已经提交到仓库根目录的 `main` 分支，可以通过 Raw 地址直接拉取。

先定义脚本的 Raw 地址：

```bash
RAW_URL="https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.safe.sh"
```

直接远程执行：

```bash
curl -fsSL "$RAW_URL" | bash -s -- --dry-run
curl -fsSL "$RAW_URL" | bash -s --
```

更稳妥的方式是先下载到本地，再执行：

```bash
curl -fsSLo docker-openclaw-killer.safe.sh "$RAW_URL"
chmod +x ./docker-openclaw-killer.safe.sh
./docker-openclaw-killer.safe.sh --dry-run
./docker-openclaw-killer.safe.sh
```

如果你提供的是完整仓库而不是单文件 Raw 地址，也可以直接克隆：

```bash
git clone https://github.com/xcivets/docker-openclaw-killer.git
cd docker-openclaw-killer
chmod +x ./docker-openclaw-killer.safe.sh
./docker-openclaw-killer.safe.sh --dry-run
```

说明：

- 远程直跑本质上是执行网络拉取的脚本，建议至少先执行一次 `--dry-run`
- 如果仓库里当前还没有 `docker-openclaw-killer.safe.sh`，Raw 方式会失败；这时请先用 `git clone` 或先把脚本推送到 `main`

## 本地使用

先预演，再执行真实清理。

```bash
chmod +x ./docker-openclaw-killer.safe.sh
./docker-openclaw-killer.safe.sh --dry-run
./docker-openclaw-killer.safe.sh
```

如果你确认要连镜像一起清理：

```bash
./docker-openclaw-killer.safe.sh --remove-images
```

如果你希望跳过本地目录删除：

```bash
./docker-openclaw-killer.safe.sh --keep-dir
```

如果你已经检查过清理计划，想跳过交互确认：

```bash
./docker-openclaw-killer.safe.sh --yes
```

## 命令行参数

- `-n`, `--dry-run`：仅展示将要执行的删除动作，不做任何修改
- `-y`, `--yes`：跳过确认提示
- `--remove-images`：删除匹配到的 OpenClaw 镜像
- `--keep-dir`：保留本地目录，不执行目录删除
- `-h`, `--help`：显示帮助

## 环境变量

- `OPENCLAW_DIR`：要删除的本地目录，默认 `~/openclaw`
- `OPENCLAW_NAME_REGEX`：容器、卷、网络名称匹配规则
- `OPENCLAW_IMAGE_REGEX`：镜像引用匹配规则

## 运行流程

1. 检查 Docker CLI 和 daemon 是否可用
2. 扫描匹配到的容器、镜像、卷、网络
3. 校验本地目录是否满足安全删除条件
4. 打印清理计划
5. 用户确认后执行删除
6. 重新扫描资源做验证
7. 根据验证结果返回退出码

## 验证与退出码

- 返回 `0`：清理完成且验证通过；或者没有匹配到任何资源；或者只是执行了 `--dry-run`
- 返回非 `0`：Docker 不可用、用户取消、删除过程报错，或验证阶段仍发现残留资源

这使脚本适合被 CI、运维脚本或其他自动化任务调用。

## 重要说明

- 脚本不会执行全局 Docker 垃圾清理
- 脚本不会删除自身
- 脚本默认不会删除镜像
- 脚本会跳过仍被容器占用的镜像、卷或网络，并在输出中提示原因

## 示例

仅预览：

```bash
./docker-openclaw-killer.safe.sh --dry-run
```

清理容器、卷、网络和本地目录：

```bash
./docker-openclaw-killer.safe.sh
```

清理容器、镜像、卷、网络和本地目录，并跳过确认：

```bash
./docker-openclaw-killer.safe.sh --remove-images --yes
```

指定自定义目录但仍保留安全校验：

```bash
OPENCLAW_DIR="$HOME/openclaw-data" ./docker-openclaw-killer.safe.sh
```
