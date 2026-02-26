---
title: Odin1固件升级
parent: 快速启动
nav_order: 3
---

# 7.固件升级

## 7.1 获取固件及升级工具

- [Odin固件0.10.0](https://vvcazjv268.feishu.cn/drive/folder/OCJVf66P2l7kp5dhnzvc2IGOnuc?from=from_copylink)
- [Odin驱动0.9.0](https://github.com/manifoldsdk/odin_ros_driver.git)

💡 提示：截止当前时间{{ site.time | date: "%Y年%m月%d日 %H:%M" }}，最新固件版本为上述链接，如有更新我们会及时同步。新机器请进行固件升级，不搭配使用则会提示版本不匹配而导致驱动停止运行。

## 7.2 升级固件

### 7.2.1 连接Odin到PC
```shell
hugo@hugo:~$ lsusb
Bus 001 Device 025: ID 2207:0019 Fuzhou Rockchip Electronics Company hawk
```

### 7.2.2 升级固件
```shell
hugo@hugo:~$ cd ~/odin1_firmware_update_pack_0.10.0_20260209
hugo@hugo:~/odin1_firmware_update_pack_0.10.0_20260209: ./odin1_firmware_update_tool_0.4.5_amd64_ubuntu22.04 odin1_firmware_update_0.10.0.tar.gz 
odin 1 firmware_update_tool 0.4.5
temp folder ./odin1_fw_update_temp/ created.
You entered: odin1_firmware_update_0.10.0.tar.gz
config.yaml
lyd_soc_app_0.4.9.bin
update_0.10.0.bin
Daemon_process_0.4.9.bin
wating for device attach...
device attach success.
get device version success!
device soc app version: 0.10.0
device daemon version: 0.6.0
device install version: 0.10.1
device mcu version: 1.5.2
device kernel version: 4.10.0
device start upgrade procedure success.
device version is 0.10.0, skip intermidiate stage.
transfering new module 1, this one will take longer
file transfer progress:  0.00%.
file transfer progress:  5.18%.
file transfer progress:  10.37%.
file transfer progress:  15.55%.
file transfer progress:  20.73%.
file transfer progress:  25.91%.
file transfer progress:  31.10%.
file transfer progress:  36.28%.
file transfer progress:  41.46%.
file transfer progress:  46.65%.
file transfer progress:  51.83%.
file transfer progress:  57.01%.
file transfer progress:  62.19%.
file transfer progress:  67.38%.
file transfer progress:  72.56%.
file transfer progress:  77.74%.
file transfer progress:  82.93%.
file transfer progress:  88.11%.
file transfer progress:  93.29%.
file transfer progress:  98.48%.
transfer new module 1 success.
device commit upgrade procedure...
device commit upgrade procedure success.
prepare for firmware flashing...
[2026:02:14:11:10:04][ERROR][lib_usb.cpp:transfer_cb:90]: transfer error: LIBUSB_TRANSFER_ERROR.
[2026:02:14:11:10:04][ERROR][lib_usb.cpp:transfer_cb:90]: transfer error: LIBUSB_TRANSFER_ERROR.
[2026:02:14:11:10:04][ERROR][lib_usb.cpp:transfer_cb:90]: transfer error: LIBUSB_TRANSFER_ERROR.
now flashing...
device rebooted && reconnected in 41 seconds.
get device version success!
new firmware version:
device soc app version: 0.10.0
device daemon version: 0.6.0
device install version: 0.10.1
device mcu version: 1.5.2
device kernel version: 4.10.0
firmware update success, now exit.
```
💡 升级提示：升级过程中请勿运行驱动、请勿断开Odin设备电源。升级过程大概会持续2-3分钟。出现上述LIBUSB_TRANSFER_ERROR不影响升级。如果长时间未升级成功，请Ctrl+c结束升级然后重启Odin再次尝试。

