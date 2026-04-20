# Terms/Tools of Robotics 
* `Gazebo` - virtual playground for robots (fake physics, 3d space and stuff)
* `ROS` - (Robot Operating System) robots brain, we program the robots behaviour using this
* `Fast-Livo2` - 3d maps generation tool, saves the robots experience in the 3D space
 - we need to draw some maps using this, in the scope of the task

##
> Is this correct?
####
```markdown
 • Mostly yes. Your summary is good for beginner level.

  I’d tighten it like this:

  - Gazebo: virtual world + physics + virtual sensors (LiDAR/camera/IMU).
  - ROS: communication framework/runtime for robot software (nodes, topics, launch, tools). It is not the “brain” by itself; your algorithms are the brain.
  - FAST-LIVO2: LiDAR-IMU-Visual odometry + mapping system. It estimates robot motion and builds a 3D point-cloud map in real time.

  For this task, your last line is correct: run simulation, feed sensor topics to FAST-LIVO2, and visualize the generated map in RViz.
```

##
> what is RViz?
####
```markdown
• RViz is ROS’s 3D visualization app.

  You use it to see robot data live, like:

  - point clouds (LiDAR maps),
  - robot pose/path,
  - TF frames,
  - sensor streams and markers.

  In your FAST-LIVO2 task, RViz is where you visually confirm that the map (/cloud_registered) and trajectory are being built correctly.
```
