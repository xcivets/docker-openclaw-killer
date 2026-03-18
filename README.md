# Docker OpenClaw Killer

面向 macOS / Linux 环境的 OpenClaw Docker 专属安全清理工具。

## 设计目标与核心特性

* **核心目标**：实现针对性、彻底的清理，绝不盲目删除无关资源。
* **安全优先**：坚决不使用破坏性强的 `docker system prune` 命令。
* **自我保护**：脚本执行完毕后不会进行自删除操作，方便重复调用。
* **镜像保护**：默认状态下绝不触碰镜像文件，必须显式附加 `--remove-images` 参数才会执行镜像清理。
* **预演机制**：全面支持 `--dry-run` 模式，在真实执行前无损预览清理计划，不产生任何破坏。
* **防误删机制**：执行前必须经过计划确认环节，并对本地目录实施极其严格的路径校验。
* **闭环验证**：清理结束后自动启动验证程序，一旦发现残留或错误即返回非零错误码。

## 严格的清理范围

* **容器资源**：独立扫描并清理符合规则的 OpenClaw 容器，不依赖容器反推。
* **镜像资源**：配合特定参数独立扫描并清理相关的 Docker 镜像（仍被占用的镜像会被自动跳过）。
* **数据卷**：独立扫描并清理挂载的冗余数据卷，有效发现并清除孤立卷（仍被占用的卷会被自动跳过）。
* **网络设置**：独立扫描并清理专属的自定义网络配置（仍被占用的网络会被自动跳过）。
* **本地目录**：默认清理目标设定为 `~/openclaw`，且必须同时满足以下所有安全条件才会执行删除：
    * 目标路径在系统中必须真实存在。
    * 解析后的绝对路径必须严格位于当前用户的 `$HOME` 目录层级之下。
    * 目标路径绝对不能是根目录 `/` 或用户主目录 `$HOME`。
    * 目标目录的名称字符串中必须明确包含 `openclaw` 字样。

## 安全的默认匹配规则

* **容器/数据卷/网络匹配**：默认采用收紧的正则表达式，避免误伤。
    ```text
    ^openclaw([._-].+)?$
    ```
* **镜像引用匹配**：默认采用收紧的正则表达式限制镜像层级。
    ```text
    (^|.*/)openclaw([._-].+)?(:[^/]+)?$
    ```

## 环境依赖要求

* **核心组件**：操作系统中必须已成功安装 `docker` 命令行工具。
* **服务状态**：Docker daemon 后台服务必须处于正常运行状态。
* **执行权限**：当前执行脚本的用户必须具备调用相关 Docker 命令的充足权限。

## 快速使用说明

### 方式一：直接远程执行

* **适用场景**：快速预览或执行标准清理。
* **执行指令**：
    ```bash
    curl -fsSL "[https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh](https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh)" | bash -s -- --dry-run
    
    curl -fsSL "[https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh](https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh)" | bash -s --
    ```

### 方式二：下载后本地执行

* **适用场景**：需要反复使用或修改执行参数。
* **执行指令**：
    ```bash
    curl -fsSLo docker-openclaw-killer.sh "[https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh](https://raw.githubusercontent.com/xcivets/docker-openclaw-killer/main/docker-openclaw-killer.sh)"
    
    chmod +x ./docker-openclaw-killer.sh
    
    ./docker-openclaw-killer.sh --dry-run
    
    ./docker-openclaw-killer.sh
    ```

### 方式三：克隆仓库执行

* **适用场景**：获取完整项目文件用于二次开发或审计。
* **执行指令**：
    ```bash
    git clone [https://github.com/xcivets/docker-openclaw-killer.git](https://github.com/xcivets/docker-openclaw-killer.git)
    
    cd docker-openclaw-killer
    
    chmod +x ./docker-openclaw-killer.sh
    
    ./docker-openclaw-killer.sh --dry-run
    ```

## 高级执行示例

* **连同镜像一并清理**：
    ```bash
    ./docker-openclaw-killer.sh --remove-images
    ```
* **跳过本地目录的删除动作**：
    ```bash
    ./docker-openclaw-killer.sh --keep-dir
    ```
* **跳过所有的交互式确认提示**：
    ```bash
    ./docker-openclaw-killer.sh --yes
    ```
* **深度清理所有内容并强制跳过确认**：
    ```bash
    ./docker-openclaw-killer.sh --remove-images --yes
    ```
* **通过环境变量指定自定义本地目录进行清理**：
    ```bash
    OPENCLAW_DIR="$HOME/openclaw-data" ./docker-openclaw-killer.sh
    ```

## 命令行参数一览

* `-n`, `--dry-run`：启动预演模式，仅在终端打印将要执行的动作清单，不执行真正的删除指令。
* `-y`, `--yes`：静默模式，直接跳过执行前的用户 `[y/N]` 交互确认提示。
* `--remove-images`：扩展清理范围，授权脚本删除匹配到的所有 OpenClaw 镜像。
* `--keep-dir`：目录保护模式，强制保留本地目录，忽略针对本地文件系统的删除操作。
* `-h`, `--help`：在终端输出该工具的详细帮助与参数说明信息。

## 环境变量覆盖机制

* `OPENCLAW_DIR`：用于指定需要被删除的本地目录路径，若未配置则系统默认值为 `~/openclaw`。
* `OPENCLAW_NAME_REGEX`：用于重新定义容器、数据卷、网络的正则匹配规则，满足企业级自定义命名规范。
* `OPENCLAW_IMAGE_REGEX`：用于重新定义镜像引用的正则匹配规则，支持特定仓库源的精细化匹配。

## 运行流程与退出码验证

* **步骤 1**：严格检查当前 Docker CLI 客户端和后台 daemon 服务的连通性与可用性。
* **步骤 2**：依据设定的正则规则，深度扫描并汇总容器、镜像、数据卷以及网络资源。
* **步骤 3**：对传入的本地目录进行真实性、归属性等多重路径校验，判别安全删除条件。
* **步骤 4**：在终端向用户结构化地打印将被清理的详细资源计划列表。
* **步骤 5**：等待并获取用户的显式确认后，开始按顺序逐一调用移除命令。
* **步骤 6**：清理环节结束后，触发二次扫描机制，对上述所有类别进行残留状态验证。
* **步骤 7**：依据验证结果向系统返回退出状态码：
    * **返回 `0`**：表示清理完成且验证通过，或者没有匹配到任何资源，或者仅执行了 `--dry-run` 预演。
    * **返回非 `0`**：表示 Docker 环境不可用、用户主动取消操作、删除执行过程中抛出异常，或在二次验证阶段依然发现相关资源残留。
