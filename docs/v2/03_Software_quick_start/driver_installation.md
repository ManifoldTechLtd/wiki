---
layout: default
title: 6.驱动安装
nav_order: 7
---

# 6.环境依赖

## 6.1 ROS install
For ROS Noetic installation, please refer to:
[ROS Noetic installation instructions](https://wiki.ros.org/noetic/Installation)

For ROS2 Foxy installation, please refer to:
[ROS Foxy installation instructions](https://docs.ros.org/en/foxy/Installation/Ubuntu-Install-Debians.html)

For ROS2 Humble installation, please refer to:
[ROS Humble installation instructions](https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debians.html)

## 6.2 Create Udev rules
```shell
sudo vim /etc/udev/rules.d/99-odin-usb.rules
```
Add the following content to the 99-odin-usb.rules file
```shell
SUBSYSTEM=="usb", ATTR{idVendor}=="2207", ATTR{idProduct}=="0019", MODE="0666", GROUP="plugdev"
```
Reload rules and reinsert devices
```shell
sudo udevadm control --reload
sudo udevadm trigger
```

## 6.3获取驱动

```shell
git clone https://github.com/manifoldsdk/odin_ros_driver.git  catkin_ws/src/
```
Note: \
请将克隆下来的代码放到**`[ros_workspace]/src/`**文件夹中，如果文件路径错误则会出现错误。
