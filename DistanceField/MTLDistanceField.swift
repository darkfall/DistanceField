//
//  DistanceField.swift
//  DistanceField
//
//  Created by ruiwei_bu on 2/29/16.
//  Copyright © 2016 Robert Bu. All rights reserved.
//

import Foundation
import Metal

let MaxBuffers = 3

class MTLDistanceField
{
    let ConstantBufferSize = 1024*1024
    
    let quadVertices: [Float] = [
        -1,  1,   0, 1,
        1,   1,   0, 1,
        1,  -1,   0, 1,
        1,  -1,   0, 1,
        -1,  -1,  0, 1,
        -1,  1,   0, 1
    ]
    
    let quadUV: [Float] = [
        0, 0,
        0, 1,
        1, 1,
        1, 1,
        1, 0,
        0, 0
    ]

    var device: MTLDevice! = nil
    
    var commandQueue: MTLCommandQueue! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    var computePipelineState: MTLComputePipelineState! = nil
    var camera: Camera! = nil
    var texture: MTLTexture! = nil
    var quadVertexBuffer: MTLBuffer! = nil
    var quadUVBuffer: MTLBuffer! = nil
    var sampler: MTLSamplerState! = nil
    
    let inflightSemaphore = DispatchSemaphore(value: MaxBuffers)
    var bufferIndex = 0
    var width = 480
    var height = 320
    
    init(isLowPower: Bool) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
    }
    
    func loadAssets(_ pixelFormat: MTLPixelFormat, sampleCount: Int, width: Int, height: Int) {
        commandQueue = device.makeCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "passThroughFragment")!
        let vertexProgram = defaultLibrary.makeFunction(name: "passThroughVertex")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineStateDescriptor.sampleCount = sampleCount
        
        do {
            try pipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
        }
        
        camera = Camera(vf3(10.0, 10.0, 0.0), vf3(0, 0, 0), vf3(0, 1, 0), Float(3.14159265 / 360.0), Float(width), Float(height))
        
        let texDescirptor = MTLTextureDescriptor()
        texDescirptor.width = Int(width)
        texDescirptor.height = Int(height)
        texDescirptor.pixelFormat = .rgba8Unorm
        texDescirptor.usage = [.shaderWrite, .shaderRead]
        
        texture = device.makeTexture(descriptor: texDescirptor)
        let df = defaultLibrary.makeFunction(name: "DistanceField")
        
        do {
            try computePipelineState = device.makeComputePipelineState(function: df!)
        } catch let error {
            print("Failed to create compute pipeline state, error \(error)")
        }
        
        quadVertexBuffer = device.makeBuffer(bytes: quadVertices, length: MemoryLayout.size(ofValue: quadVertices[0]) * quadVertices.count, options: [])
        quadUVBuffer = device.makeBuffer(bytes: quadUV, length: MemoryLayout.size(ofValue: quadUV[0]) * quadUV.count, options: [])
        sampler = device.makeSamplerState(descriptor: MTLSamplerDescriptor())

        self.width = width
        self.height = height
    }
    
    func draw(_ drawable: MTLDrawable, drawableRenderPassDescriptor: MTLRenderPassDescriptor)
    {
        inflightSemaphore.wait(timeout: .distantFuture)
        
        let computeCmdBuffer = commandQueue.makeCommandBuffer()
        let computeEncoder = computeCmdBuffer.makeComputeCommandEncoder()
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(texture, at: 0)
        
        let params: [Float] = [
            camera.eye.x, camera.eye.y, camera.eye.z,
            camera.xStep.x, camera.xStep.y, camera.xStep.z,
            camera.yStep.x, camera.yStep.y, camera.yStep.z,
            camera.leftTopPoint.x, camera.leftTopPoint.y, camera.leftTopPoint.z,
            camera.viewportWidth, camera.viewportHeight, camera.fov
        ]
        let paramBuffer = device.makeBuffer(bytes: params, length: MemoryLayout.size(ofValue: params[0]) * params.count, options: [])
        
        computeEncoder.setBuffer(paramBuffer, offset: 0, at: 0)
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1);
        let numThreadgroups = MTLSize(width: Int(width+15) / threadsPerGroup.width, height: Int(height+15) / threadsPerGroup.height, depth: 1)
        
        computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        computeCmdBuffer.commit()
        computeCmdBuffer.waitUntilCompleted()
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                strongSelf.inflightSemaphore.signal()
            }
            return
        }
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: drawableRenderPassDescriptor)
        renderEncoder.label = "render encoder"
        
        renderEncoder.pushDebugGroup("DistanceField")
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, at: 0)
        renderEncoder.setVertexBuffer(quadUVBuffer, offset: 0, at: 1)
        renderEncoder.setFragmentTexture(texture, at: 0)
        renderEncoder.setFragmentSamplerState(sampler, at: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        bufferIndex = (bufferIndex + 1) % MaxBuffers
        
        commandBuffer.commit()
    }
    
    func mouseMoved(_ x: Float, y: Float)
    {
        camera.rotate(-y, pitch: -x)
    }
}
