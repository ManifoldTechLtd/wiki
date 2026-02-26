---
title: 消息格式说明
parent: 数据接口
nav_order: 1
---

# 10.  消息格式

## 10.1. 原始点云（cloud_raw）包含以下字段:
```
float32 x             // X axis, in meters
float32 y             // Y axis, in meters
float32 z             // Z axis, in meters
uint8  intensity      // Reflectivity, range 0–255
uint16 confidence     // Point confidence, actual value range from 0 to around 1300 in typical scene, higher value means more reliable. Recommanded filtering threshold is 30-35, should be adjusted accordingly.
float32 offset_time   // Time offset relative to the base timestamp unit: s 
```

要在PCL中处理这种自定义格式，首先需要定义点类型：
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
然后，你可以轻松地将ROS的sensor_msgs::PointCloud2消息转换为PCL点云：
```
pcl::PointCloud<ls_ros::Point> ls_cloud;
pcl::fromROSMsg(*msg, ls_cloud);
```

## 10.2. SLAM点云（cloud_slam）和直接渲染的点云（cloud_render）包含以下字段：
```
float32 x             // X axis, in meters
float32 y             // Y axis, in meters
float32 z             // Z axis, in meters
float32 rgb           // RGB value