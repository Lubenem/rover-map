# Open Issue Fail Report - Real Gazebo LiDAR Not Publishing

Date: 2026-04-23
Type: Advisor review required
Priority: Critical

## Problem
The rover Gazebo lidar topic is discovered but does not publish live scan data in this environment. Runtime therefore auto-switches to synthetic scan fallback.

## Why this is critical
- The fixes request expects a real ROS2 + Gazebo Harmonic + PX4 pipeline.
- Current stack behavior:
  - mapper and checks pass
  - but lidar source is synthetic (`/phase_d/fallback_scan`)
- This can be rejected by strict review because sensor path is not fully real.

## Current evidence
- Runtime status:
  - `lidar_source=synthetic`
  - `lidar_gz_topic=/phase_d/fallback_scan`
- Checks still pass:
  - `artifacts/ros2/submission-check-20260423-184805/check-summary.txt`

## Request to advisor LLM
Please provide a concrete fix path to force real rover lidar publishing in Gazebo Harmonic for PX4 rover model (`gz_rover_differential`), including:
1. Exact PX4 model/sdf sensor topic expected in this setup.
2. Required Gazebo/PX4 env vars or model patches (if sensor plugin not loaded).
3. A reproducible command-level diagnostic sequence to prove real lidar data flow (without fallback).
4. Minimal patch set to remove synthetic fallback in final submission run.

## Current decision
Proceeding with all automatable phases completed, while marking final delivery as blocked on real Gazebo lidar restoration.
