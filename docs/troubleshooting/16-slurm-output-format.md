---
layout: default
title: Slurm 命令输出截断与格式设置
parent: 故障手册
nav_order: 16
---

# Slurm 命令输出截断与格式设置

## 问题

Slurm 部分查询命令默认列宽较小，长分区名、账户名、TRES 列表和数值可能被截断。部分命令显示 `+` 提示，`sprio` 的 TRES 列则可能直接截掉尾部数字。

例如默认 20 字符的 TRES 列会将 `cpu=1562,gres/gpu=1250` 显示为 `cpu=1562,gres/gpu=12`。这属于显示截断，不能根据截断后的数值反推资源请求或调度计算。

## 方法

保留原生对齐表格：有默认格式环境变量的命令设置环境变量，其余查询命令通过交互式 Bash 函数补充格式。

| 命令 | 格式参数 | 默认设置方法 |
|---|---|---|
| `sprio` | `-o '%.10i %32r %T'` | `SPRIO_FORMAT`；末尾 `%T` 不指定宽度，完整显示 TRES |
| `squeue` | `-o '%.18i %.32P %.28j %.16u %.10T %R'` | `SQUEUE_FORMAT` |
| `sinfo` | `-o '%32P %5a %12l %6D %12t %N'` | `SINFO_FORMAT` |
| `sacct` | `--format=JobID%24,Partition%32,State%24` | `SACCT_FORMAT` |
| `sacctmgr` | `show tres format=Type%16,Name%40,ID%8` | 按查询实体设置 Bash 函数 |
| `sshare` | `--format=Account%32,User%16,FairShare%12` | Bash 函数 |
| `sstat` | `--format=JobID%24,AveCPU%16,MaxRSS%14` | Bash 函数 |
| `sreport` | `cluster utilization format=Cluster%24,Allocated%16` | 按报告类型设置 Bash 函数 |
| `scontrol` | `show job`、`show node`、`show partition` | 默认多行键值输出；通常无需调整；`-o` 表示单行输出，不是字段格式 |
| `sbatch`、`srun`、`salloc`、`scancel` | 无通用查询表格格式 | 不设置格式包装 |

`sprio`、`squeue`、`sinfo` 使用 `%宽度字段代码`；`sacct`、`sacctmgr`、`sshare`、`sstat`、`sreport` 使用 `字段名%宽度`，不能混用。固定宽度仍可能截断更长内容，需要时继续增加对应字段宽度。

### 全局默认配置

将下面完整内容保存到 `/etc/profile.d/slurm-output.sh`，权限设为 `0644`，不需要重启 Slurm。配套文件：[slurm-output.sh](slurm-output.sh)。

配置覆盖常用查询；`sacctmgr` 和 `sreport` 函数只匹配脚本中列出的完整小写命令形式（例如 `sacctmgr show assoc`）。缩写、大写写法、命令前置选项、其他实体和交互式子命令保持原生命令行为。

```bash
# Slurm table output defaults. Source from Bash login/interactive shells.
export SPRIO_FORMAT='%.10i %32r %.10Y %.10S %.10A %.10F %.10Q %T'
export SQUEUE_FORMAT='%.18i %.32P %.28j %.16u %.10T %.12M %.12l %.6D %R'
export SINFO_FORMAT='%32P %5a %12l %6D %12t %N'
export SACCT_FORMAT='JobID%24,JobName%28,Partition%32,User%16,State%24,Elapsed%14,AllocCPUS%10,ExitCode%10,NodeList%40'

# Functions below are for interactive Bash only.
[ -n "${BASH_VERSION:-}" ] || return 0
case $- in *i*) ;; *) return 0 ;; esac

# Respect explicit formats and alternate output modes.
_slurm_has_output_option() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -o*|--format*|[Ff][Oo][Rr][Mm][Aa][Tt]=*|-p|-P|--parsable*|--json*|--yaml*|-h|--help*|-V|--version|-l|--long)
                return 0 ;;
        esac
    done
    return 1
}

sshare() {
    if _slurm_has_output_option "$@"; then
        command sshare "$@"
    else
        command sshare --format='Account%32,User%16,RawShares%12,NormShares%12,RawUsage%16,NormUsage%12,EffectvUsage%14,FairShare%12' "$@"
    fi
}

sstat() {
    if _slurm_has_output_option "$@"; then
        command sstat "$@"
    else
        command sstat --format='JobID%24,NTasks%10,AveCPU%16,AveRSS%14,MaxRSS%14,MaxRSSNode%40' "$@"
    fi
}

sacctmgr() {
    local fmt=''
    if _slurm_has_output_option "$@"; then
        command sacctmgr "$@"
        return $?
    fi
    # Apply only to full, direct "show/list entity" commands.
    case "${1-}:${2-}" in
        show:tres|list:tres)
            fmt='Type%16,Name%40,ID%8' ;;
        show:assoc|list:assoc|show:association|list:association)
            fmt='Cluster%24,Account%24,User%16,Partition%32,Share%10,Priority%10,GrpTRES%60,MaxTRES%60,QOS%40,DefaultQOS%24' ;;
        show:user|list:user)
            fmt='User%16,DefaultAccount%24,AdminLevel%16' ;;
        show:account|list:account)
            fmt='Account%24,Descr%40,Org%24' ;;
        show:qos|list:qos)
            fmt='Name%24,Priority%10,UsageFactor%12,GrpTRES%60,MaxTRESPJ%60,MaxTRESPU%60,Flags%40' ;;
        show:cluster|list:cluster)
            fmt='Cluster%24,ControlHost%40,ControlPort%12,TRES%80' ;;
    esac
    if [ -n "$fmt" ]; then
        command sacctmgr "$@" "format=$fmt"
    else
        command sacctmgr "$@"
    fi
}

sreport() {
    local fmt=''
    if _slurm_has_output_option "$@"; then
        command sreport "$@"
        return $?
    fi
    case "${1-}:${2-}" in
        cluster:utilization)
            fmt='Cluster%24,TresName%20,Allocated%16,Down%16,Idle%16,Reported%16' ;;
        cluster:accountutilizationbyuser)
            fmt='Cluster%24,Accounts%24,Login%16,Proper%24,Used%16' ;;
        cluster:userutilizationbyaccount)
            fmt='Cluster%24,Login%16,Accounts%24,Used%16' ;;
        user:topusage|user:top)
            fmt='Cluster%24,Login%16,Account%24,Used%16' ;;
    esac
    if [ -n "$fmt" ]; then
        command sreport "$@" "format=$fmt"
    else
        command sreport "$@"
    fi
}

```

### 加载与使用

当前交互式 Bash 会话加载：

```bash
source /etc/profile.d/slurm-output.sh
```

后续 Bash 登录会话通常由 `/etc/profile` 自动加载。非登录交互式终端如果未加载，可在系统 Bash 初始化文件或个人 `~/.bashrc` 中加入：

```bash
[ ! -r /etc/profile.d/slurm-output.sh ] || . /etc/profile.d/slurm-output.sh
```

然后直接使用：

```bash
sprio
squeue
sinfo
sacct -j 1259
sacctmgr show tres
sacctmgr show assoc
sacctmgr show qos
sshare -a
sstat -j 1259.batch
sreport cluster utilization
```

显式指定格式优先于默认格式：

```bash
sprio -j 1259 -o '%i | %r | %T'
sacct -j 1259 --format=JobID%24,ReqTRES%100,AllocTRES%100
sacctmgr show assoc format=Cluster%24,Account%24,User%16,GrpTRES%120
```

默认 `sacct` 表格侧重任务概览；查看资源请求时使用上面的 `ReqTRES`、`AllocTRES` 格式。

函数仅在交互式 Bash 中定义；显式格式、长格式、帮助和结构化输出请求直接转交原生命令。环境变量设置仍会被子进程继承；自定义格式会固定列集合，`sprio -n` 等模式应配合对应的小写归一化字段，例如：

```bash
sprio -j 1259 -o '%.10i %32r %.12a %.12f %t'
```

需要绕过函数时使用 `command`；需要恢复环境变量控制的原生默认格式时同时移除对应变量：

```bash
command sacctmgr show tres
command sshare -l
env -u SPRIO_FORMAT sprio -l
env -u SQUEUE_FORMAT squeue -l
env -u SINFO_FORMAT sinfo -N -l
env -u SACCT_FORMAT sacct -j 1259
```

### 官方参数说明

- [sprio](https://slurm.schedmd.com/sprio.html)
- [squeue](https://slurm.schedmd.com/squeue.html)
- [sinfo](https://slurm.schedmd.com/sinfo.html)
- [sacct](https://slurm.schedmd.com/sacct.html)
- [sacctmgr](https://slurm.schedmd.com/sacctmgr.html)
- [sshare](https://slurm.schedmd.com/sshare.html)
- [sstat](https://slurm.schedmd.com/sstat.html)
- [sreport](https://slurm.schedmd.com/sreport.html)
