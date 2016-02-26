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

class Camera
{
    init(_ eye: vf3, _ lookAt: vf3, _ up: vf3,  _ fov: Float, _ vpWidth: Float, _ vpHeight: Float)
    {
        let verticalFov = fov * vpHeight / vpWidth
        self.lookAt = lookAt
        
        let centerRay = lookAt - eye
        self.dir = normalize(centerRay)
        
        let rayLength = length(centerRay)
        self.left = normalize(cross(up, centerRay))
        
        let lengthx = tan(fov / 2.0) * rayLength
        let lengthy = tan(verticalFov / 2.0) * rayLength
        
        let leftVector = self.left * lengthx
        let upVector = up * lengthy
        let upperLeftRay = centerRay + leftVector + upVector
        
        self.xStep = leftVector * (2.0 / vpWidth)
        self.yStep = upVector * (2.0 / vpHeight)
        self.leftTopPoint = eye + upperLeftRay
        self.eye = eye
        self.fov = fov
        self.up = cross(self.dir, self.left)
        self.viewportWidth = vpWidth;
        self.viewportHeight = vpHeight;
        self.sensitiveFactor = 5.0;
        self.objDistance = 0
    }
    
    var left: vf3;
    var up: vf3;
    var eye: vf3;
    var lookAt: vf3;
    var dir: vf3;
    var xStep: vf3;
    var yStep: vf3;
    var leftTopPoint: vf3;
    var viewportWidth: Float;
    var viewportHeight: Float;
    var fov: Float;
    var objDistance: Float;
    var sensitiveFactor: Float;
}