---
title: 驱动配置
parent: 快速启动
nav_order: 1
---

# 5. 配置文件说明

## 5.1 odin1_ros_driver/config/control_command.yaml
```shell
register_keys:
  strict_usb3.0_check: 0  # 0: off: 1: on;
  # 如果关闭，则驱动则不会检测USB速率是否为3.2或者2.1，允许速率在3.0以下的设备上传输数据
  # 注意：SLAM模式下采集地图需要USB速率为3.0，如果低于3.0则有保存失败风险

  use_host_ros_time: 2
  # 0：使用Odin内部计时，该时间会随驱动重启或者Odin断电重置
  # 1：使用ros时间，但是各传感器之间的时间同步可能存在不准的情况，非必要不推荐使用
  # 2：将 odin1 的时间与主机时间对齐，时间戳即传感器数据在主机时间轴上的接收时间。

  streamctrl: 1           # 0: off; 1: on
  # 控制是否向Odin获取数据，默认为1

  sendrgbcompressed: 1    # 0: off; 1: on
  # 来自Odin的压缩rgb jpeg数据

  sendrgb: 1              # 0: off; 1: on
  # 解压后的rgb jpeg数据，bgr8格式
  # 解压过程在主机（上位机）进行

  sendrgbundistort: 1     # 0: off; 1: on.
  # 将解码后的rgb数据进行去畸变
  # 去畸变过程在主机（上位机）上进行

  sendimu: 1              # 0: off; 1: on
  # IMU 数据

  sendodom: 1             # 0: off; 1: on
  # Odometry 数据

  send_odom_baselink_tf: 1 # 0: off; 1: on.
  # odom到base_link的TF变换，建议开启
  # 注意：这对于rviz是否可以显示cloud_raw topic至关重要

  senddtof: 1             # 0: off; 1: on
  # 是否开启dtof lidar模组
  cloud_raw_confidence_threshold: 35 # please refer to readme for more detail

  dtof_fps: 100           # 100: 10fps; 145: 14.5fps
  # dtof传感器的帧率，支持10hz和14.5hz
  # 高帧率数据可以提供更为流畅的点云效果但是会增加带宽，用户需根据实际情况使用
  # 100代表10hz，145代表14.5hz，默认10hz

  sendcloudslam: 1        # 0: off; 1: on
  # slam点云数据

  sendcloudrender: 1      # 0: off; 1: on
  # 根据calib.yaml的参数融合点云和图像，获取彩色点云
  # 该过程在主机上进行

  senddepth: 0            # 0: off; 1: on
  # 是否发送深度图
  # 该过程在主机上进行，且会占用主机较大资源，默认关闭

  sendreprojection: 1    # 0: off; 1: on
  # 点云重投影示例，使用里程计数据将cloud_slam数据投影到相机原始图像（畸变图像）上
  # 该过程在主机上进行

  recorddata: 0           # 0: off; 1: on
  # 将 RGB、里程计和 SLAM 点云数据录制为专有的 olx 格式，以便在 MindCloud(TM) 软件中进行后续处理。
  # 保存路径：ws/src/odin_ros_driver/recorddata/{record_start_time}
  # 注意：请复制整个文件夹以进行后处理。

  devstatuslog: 1         # 0: off; 1: on.
  # 将设备运行时状态信息保存至 ws/src/odin_ros_driver/log/Driver_{驱动程序启动时间}/Conn_{设备连接时间}/dev_status.csv

  save_log: 0 # 0: off; 1: on; 

  pubintensitygray: 0     # 0: off; 1: on
  # 原始 dToF 传感器灰度格式强度数据，主要用于调试目的。默认关闭

  showpath: 1             # 0: off; 1: on
  # 发送Odin_path话题，在rviz中显示Odin运动轨迹

  showcamerapose: 0       # 0: off; 1: on
  # 显示相机位姿和视场角
  
  custom_map_mode: 0      # 0: Odometry mode 1: SLAM mode 2: Relocalization mode
  # 运行模式：模式 0 - 里程计模式：地图坐标系和里程计坐标系位姿相同。模式 1 - 建图（含回环）模式：此模式支持地图保存。模式 2 - 重定位模式：需指定地图文件的绝对路径。重定位成功后，将输出地图坐标系与里程计坐标系之间的 TF 关系。

  custom_init_pos: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
  # 初始化位置值，目前未启用

  relocalization_map_abs_path: "/home/hugo/git/odin_0.9.0_pub/map/Q9000-DA.bin" # must be set for Relocalization mode or will fail
  # 重定位bin文件所在绝对路径，需要写到bin

  # To get the mapping result file, please use the set_param.sh script provided: "./set_param.sh save_map 1"
  mapping_result_dest_dir: "" # "": if not specified, save to default location of {ws}/src/odin_ros_driver/map/{driver_start_time}/
  mapping_result_file_name: "" # "": if not specified, save to location above with default file name of map_{map_save_time}.bin
```