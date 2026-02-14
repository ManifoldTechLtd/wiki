---
layout: default
title: 14.外参说明
nav_order: 15
---

# 14. 外参符号说明
## 14.1 Odin1

下面使用 $$\mathbf{T}^{\text{A}}_{\text{B}}$$ 来表示坐标转换，具体含义为:

$$
\mathbf{P}_{\text{A}} = \mathbf{T}^{\text{A}}_{\text{B}} \cdot \mathbf{P}_{\text{B}}
$$

其中 $$P_A$$ 和 $$P_B$$ 分别表示物体在A坐标系和B坐标系下坐标。

### Camera - LiDAR

外参 $$\mathbf{T}^{\text{camera}}_{\text{lidar}}$$  不同机器存在差异，请在驱动程序启动后，在config/calib.yaml获取（Tcl_0），具体信息请查看驱动。

### IMU - LiDAR

外参 $$\mathbf{T}^{\text{imu}}_{\text{lidar}}$$  是固定值，数值如下：

$$
\mathbf{T}^{\text{imu}}_{\text{lidar}} =
\begin{bmatrix}
1 & 0 & 0 & -0.02663 \\
0 & 1 & 0 & 0.03447 \\
0 & 0 & 1 & 0.02174 \\
0      & 0      & 0      & 1
\end{bmatrix}
$$

### 其它

- 如果需要 Camera 到 IMU 的外参，请根据上述自行计算。