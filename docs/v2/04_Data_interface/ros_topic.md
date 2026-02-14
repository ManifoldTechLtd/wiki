---
layout: default
title: 11.ROS topic 
nav_order: 12
---

# 11. ROS topics
## 11.1 Odin1输出topic说明
Internal parameters of the Odin ROS driver are defined in config/control_command.yaml. Below are descriptions of the commonly used parameters:

| Topic               |control_command.yaml  | Detailed Description |
|---------------------|----------------------|----------------------|
| odin1/imu                     | sendimu           | Imu Topic |
| odin1/image                   | sendrgb           | RGB Camera Topic, decoded from original jpeg data from device, bgr8 format |
| odin1/image_undistort         | sendrgbundistort  | undistorted RGB Camera Topic, processed with calib.yaml from device |
| odin1/image/compressed        | sendrgbcompressed | RGB Camera compressed Topic, original jpeg data from device |
| odin1/cloud_raw               | senddtof          | Raw_Cloud Topic |
| odin1/cloud_render            | sendcloudrender   | Render_Cloud Topic, processed with raw point cloud, rgb image, and calib.yaml from device |
| odin1/cloud_slam              | sendcloudslam     | Slam_PointCloud Topic |
| odin1/odometry                | sendodom          | Odom Topic |
| odin1/odometry_high           | sendodom          | high frequency Odom Topic |
| odin1/path                    | showpath          | Odom Path Topic |
| tf                            | sendodom          | tf tree Topic |
| odin1/depth_img_competetion   | senddepth         | Dense depth image Topic. Demo, high computing power required. One-to-one with odin1/image_undistort. To utilize the data please directly subscribe to this topic instead of echoing it. Original value is already depth data, no need for further convert. |
| odin1/depth_img_competetion_cloud  | senddepth         | Dense Depth_Cloud Topic. Demo, high computing power required |
| odin1/reprojected_image       | sendreprojection  | Reprojected cloud to image Topic. Projects cloud_slam to camera image using odometry. Processed on host device. |

## 11.2 Odin1其他功能描述
|control_command.yaml   | Detailed Description |
|-----------------------|----------------------|
| use_host_ros_time     | Time synchronization mode: 0 - use odin internal system time as data timestamp (typical and recommended); 1 - use host ROS time upon receive (not recommended for most users); 2 - align odin1 time to host time via NTP-like synchronization, timestamp is the sensor data reception time on host time axis. |
| strict_usb3.0_check   | Strict USB3.0 check, if off, allow connection even if usb connection is below usb 3.0 |
| recorddata            | Record data in specific format that can be imported into MindCloud(TM) for post-processing. Please be aware that this will consume a lot of storage space. Testing shows 9.5G for 10mins of data. |
| devstatuslog          | Device status logging, currently save device status (soc temperature, cpu usage, ram usage, dtof sensor temp .etc) and data tx & rx rate to devstatus.csv under log folder. A new file will be created every time the driver is started. |
| showcamerapose        | Display Camera Pose and Field of View. |
| custom_map_mode        | Operation Modes: Mode 0 - Odometry mode: The map frame and odom frame share the same pose. Mode 1 - Mapping (with loop closure) mode: This mode supports map saving. Mode 2 - Relocalization mode: Requires specifying the absolute path to the map file. After successful relocalization, it will output the TF relationship between the map and odom frames.|
| custom_init_pos        | Initialization Position (currently unused). |
| relocalization_map_abs_path        | Absolute Path to Map File: Used for relocalization mode. |
| mapping_result_dest_dir and mapping_result_file_name| Path and Name for Saving Maps in Mapping Mode: If not specified, default values will be used. |