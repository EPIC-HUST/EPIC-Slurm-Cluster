---
layout: default
title: 节点处于 DOWN、DRAIN 或 INVALID_REG
parent: 故障手册
nav_order: 12
---

<a id="node-state-failure"></a>

# 节点处于 DOWN、DRAIN 或 INVALID_REG

## 网络中断的容忍与自动恢复

仓库声明的目标配置如下，实际生效值以 `scontrol show config` 为准：

| 参数 | 值 | 作用 |
| --- | ---: | --- |
| `SlurmdTimeout` | 3600 | 控制器等待计算节点响应约 1 小时后，才因无响应将节点设为 DOWN |
| `MessageTimeout` | 120 | 单次往返通信允许等待 2 分钟 |
| `BatchStartTimeout` | 900 | 作业启动容忍时间为 15 分钟，实际检查时机由 Slurm 决定 |
| `UnkillableStepTimeout` | 1800 | SIGKILL 后进程仍无法清理时，等待 30 分钟再触发排空 |
| `ReturnToService` | 2 | DOWN 节点重新注册且资源配置有效后自动恢复服务 |

`UnkillableStepTimeout` 必须至少为 `MessageTimeout` 的 5 倍。
延长超时不会保证断网期间继续投递新任务，也不能保证依赖网络或共享存储的作业不受影响。
`ReturnToService=2` 不会清除 DRAIN 标志；启动失败、清理失败、资源异常或维护导致的
排空仍应先检查 `Reason` 和对应日志，不要定时对所有排空节点强制 RESUME。

## 检查与恢复

```bash
scontrol show node <node>
sinfo -N -l --nodes=<node>
sudo journalctl -u slurmd --since today
```

确认节点通信、MUNGE、`slurmd`、时间同步和 host vars 资源声明。原因处理完后再恢复：

```bash
scontrol update nodename=<node> state=resume
```

不要把删除 `NodeName`、重建文件系统或清空 Slurm 状态作为普通恢复步骤。
