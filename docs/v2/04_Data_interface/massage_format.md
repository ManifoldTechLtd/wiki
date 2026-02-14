---
layout: default
title: 12.data format
nav_order: 13
---

# 12.  Data format

### 1. The raw point cloud (cloud_raw) has the following fields:
```
float32 x             // X axis, in meters
float32 y             // Y axis, in meters
float32 z             // Z axis, in meters
uint8  intensity      // Reflectivity, range 0–255
uint16 confidence     // Point confidence, actual value range from 0 to around 1300 in typical scene, higher value means more reliable. Recommanded filtering threshold is 30-35, should be adjusted accordingly.
float32 offset_time   // Time offset relative to the base timestamp unit: s 
```

To work with this custom format in PCL, first define the point type:
```cpp
/*** LS ***/
namespace ls_ros {
    struct EIGEN_ALIGN16 Point {
        float x;
        float y;
        float z;
        uint8_t intensity;
        uint16_t confidence;
        float offset_time;
        EIGEN_MAKE_ALIGNED_OPERATOR_NEW
    };
}  // namespace ls_ros

POINT_CLOUD_REGISTER_POINT_STRUCT(ls_ros::Point,
      (float, x, x)
      (float, y, y)
      (float, z, z)
      (uint8_t, intensity, intensity)
      (uint16_t, confidence, confidence)
      (float offset_time , offset_time)
)
```
Then, you can easily convert a ROS sensor_msgs::PointCloud2 message into a PCL point cloud:
```
pcl::PointCloud<ls_ros::Point> ls_cloud;
pcl::fromROSMsg(*msg, ls_cloud);
```

### 2. The slam point cloud (cloud_slam) and directly rendered point cloud (cloud_render) has the following fields:
```
float32 x             // X axis, in meters
float32 y             // Y axis, in meters
float32 z             // Z axis, in meters
float32 rgb           // RGB value