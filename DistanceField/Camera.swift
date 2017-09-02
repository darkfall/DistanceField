//
//  Camera.swift
//  DistanceField
//
//  Created by Robert Bu on 2/25/16.
//  Copyright © 2016 Robert Bu. All rights reserved.
//

import Foundation
import simd

typealias vf3 = vector_float3;

class quaternion {
    var x,y,z,w: Float

    init() {
        x = 1
        y = 1
        z = 1
        w = 1
    }
    
    init(_ _x: Float, _ _y: Float, _ _z: Float, _ _w: Float) {
        x = _x
        y = _y
        z = _z
        w = _w
    }
    
    init(_ axis: vf3, _ angle: Float) {
        x = axis.x * sin(angle / 2.0)
        y = axis.y * sin(angle / 2.0)
        z = axis.z * sin(angle / 2.0)
        w = cos(angle / 2.0)
    }
    
    init(_ a: quaternion) {
        x = a.x
        y = a.y
        z = a.z
        w = a.w
    }
    
    func rotate(_ v: vf3) -> vf3 {
        let u = vf3(x, y, z)
        let s = w
        let result = u * dot(u, v) * 2.0 +
                     v * (s * s - dot(u, u)) +
                     cross(u, v) * s * 2.0
        return result
    }

    static func * (left: inout quaternion, right: quaternion) -> quaternion {
        return quaternion(left.x * right.x - left.y * right.y - left.z * right.z - left.w * right.w,
                          left.x * right.y + left.y * right.x - left.z * right.w + left.w * right.z,
                          left.x * right.z + left.y * right.w + left.z * right.x - left.w * right.y,
                          left.x * right.w - left.y * right.z + left.z * right.y + left.w * right.x)
    }

    static func + (left: inout quaternion, right: quaternion) -> quaternion {
        return quaternion(left.x + right.x,
                          left.y + right.y,
                          left.z + right.z,
                          left.w + right.w)
    }

    static func * (left: inout quaternion, right: Float) -> quaternion {
        return quaternion(left.x * right,
                          left.y * right,
                          left.z * right,
                          left.w * right)
    }

    
    func length() -> Float {
        return sqrt(x * x + y * y + z * z + w * w)
    }
}


class Camera {
    init(_ eye: vf3, _ lookAt: vf3, _ up: vf3,  _ fov: Float, _ vpWidth: Float, _ vpHeight: Float) {
        self.lookAt = lookAt
        self.eye = eye
        self.viewportWidth = vpWidth;
        self.viewportHeight = vpHeight;
        self.up = up
        self.fov = fov
        
        self.update()
        
        self.sensitiveFactor = 100.0;
    }
    
    func update() {
        let verticalFov = self.fov * self.viewportHeight / self.viewportWidth
        let centerRay = lookAt - eye
        self.dir = normalize(centerRay)
        
        let rayLength = length(centerRay)
        self.left = normalize(cross(self.up, centerRay))
        self.up = cross(self.dir, self.left)
        
        let lengthx = tan(fov / 2.0) * rayLength
        let lengthy = tan(verticalFov / 2.0) * rayLength
        
        let leftVector = self.left * lengthx
        let upVector = up * lengthy
        let upperLeftRay = centerRay + leftVector + upVector
        
        self.xStep = leftVector * (2.0 / self.viewportWidth)
        self.yStep = upVector * (2.0 / self.viewportHeight)
        self.leftTopPoint = eye + upperLeftRay
    }
    
    func rotate(_ yaw: Float, pitch: Float) {
        if fabs(yaw) > 100.0 || fabs(pitch) > 100.0 {
            return
        }
        
        let yawT = yaw / sensitiveFactor
        let pitchT = pitch / sensitiveFactor
        
        let yawR = yawT / 180.0 * 3.1415926535897932
        let pitchR = pitchT / 180.0 * 3.1415926535897932
        
        let qYaw = quaternion(self.up, yawR)
        self.dir = qYaw.rotate(self.dir)
        self.lookAt = self.eye + self.dir * 1000.0
        update()
        
        let qPitch = quaternion(self.left, pitchR)
        self.dir = qPitch.rotate(self.dir)
        self.up = qPitch.rotate(self.up)
        self.lookAt = self.eye + self.dir * 1000.0
        
        update()
    }
    
    var left: vf3 = vf3(0, 0, 0)
    var up: vf3 = vf3(0, 0, 0)
    var eye: vf3 = vf3(0, 0, 0)
    var lookAt: vf3 = vf3(0, 0, 0)
    var dir: vf3 = vf3(0, 0, 0)
    var xStep: vf3 = vf3(0, 0, 0)
    var yStep: vf3 = vf3(0, 0, 0)
    var leftTopPoint: vf3 = vf3(0, 0, 0)
    var viewportWidth: Float = 0
    var viewportHeight: Float = 0
    var fov: Float = 0
    var sensitiveFactor: Float = 0
}
