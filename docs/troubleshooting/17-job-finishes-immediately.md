---
layout: default
title: 作业没有运行，瞬间完成
parent: 故障手册
nav_order: 1
---

# 作业没有运行，瞬间完成

表现为job启动以后，立即变为Completed状态。

检查job的输出路径是否能打开。
   
如果不能够打开 -> 未知错误，提交issue。
如果能够打开 -> 观察目录下是否存在 output.log

如果存在，观察log输出。
如果不存在output.log, 大概率是网络断开了，NFS重启失败。当前已经配置自动重连，但是有一定概率失败。联系超管重新挂载。
