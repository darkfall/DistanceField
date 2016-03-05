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
    
    let inflightSemaphore = dispatch_semaphore_create(MaxBuffers)
    var bufferIndex = 0
    var width = 480
    var height = 320

    init(isLowPower: Bool)
    {
#if os(OSX)
        let devices = MTLCopyAllDevices()
        if devices.count == 1 {
            device = devices[0]
        }
        if device == nil
        {
            for d in devices
            {
                if (!isLowPower && !d.lowPower)
                {
                    device = d
                    break
                }
                else if(isLowPower && d.lowPower)
                {
                    device = d
                    break
                }
            }
        }
#else
        device = MTLCreateSystemDefaultDevice()
#endif
        
        guard device != nil else {
            assert(false, "Metal is not supported on this device")
            return
        }
    }
    
    func loadAssets(pixelFormat: MTLPixelFormat, sampleCount: Int, width: Int, height: Int)
    {
        commandQueue = device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.newFunctionWithName("passThroughFragment")!
        let vertexProgram = defaultLibrary.newFunctionWithName("passThroughVertex")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineStateDescriptor.sampleCount = sampleCount
        
        do {
            try pipelineState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
        }
        
        camera = Camera(vf3(10.0, 10.0, 0.0), vf3(0, 0, 0), vf3(0, 1, 0), Float(3.14159265 / 360.0), Float(width), Float(height))
        
        let texDescirptor = MTLTextureDescriptor()
        texDescirptor.width = Int(width)
        texDescirptor.height = Int(height)
        texDescirptor.pixelFormat = .RGBA8Unorm
        texDescirptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.ShaderWrite.rawValue | MTLTextureUsage.ShaderRead.rawValue)
        
        texture = device.newTextureWithDescriptor(texDescirptor)
        let df = defaultLibrary.newFunctionWithName("DistanceField")
        
        do {
            try computePipelineState = device.newComputePipelineStateWithFunction(df!)
        } catch let error {
            print("Failed to create compute pipeline state, error \(error)")
        }
        
        quadVertexBuffer = device.newBufferWithBytes(quadVertices, length: sizeofValue(quadVertices[0]) * quadVertices.count, options: [])
        quadUVBuffer = device.newBufferWithBytes(quadUV, length: sizeofValue(quadUV[0]) * quadUV.count, options: [])
        sampler = device.newSamplerStateWithDescriptor(MTLSamplerDescriptor())

        self.width = width
        self.height = height
    }
    
    func draw(drawable: MTLDrawable, drawableRenderPassDescriptor: MTLRenderPassDescriptor)
    {
        dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        let computeCmdBuffer = commandQueue.commandBuffer()
        let computeEncoder = computeCmdBuffer.computeCommandEncoder()
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(texture, atIndex: 0)
        
        let params: [Float] = [
            camera.eye.x, camera.eye.y, camera.eye.z,
            camera.xStep.x, camera.xStep.y, camera.xStep.z,
            camera.yStep.x, camera.yStep.y, camera.yStep.z,
            camera.leftTopPoint.x, camera.leftTopPoint.y, camera.leftTopPoint.z,
            camera.viewportWidth, camera.viewportHeight, camera.fov
        ]
        let paramBuffer = device.newBufferWithBytes(params, length: sizeofValue(params[0]) * params.count, options: [])
        
        computeEncoder.setBuffer(paramBuffer, offset: 0, atIndex: 0)
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1);
        let numThreadgroups = MTLSize(width: Int(width+15) / threadsPerGroup.width, height: Int(height+15) / threadsPerGroup.height, depth: 1)
        
        computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        computeCmdBuffer.commit()
        computeCmdBuffer.waitUntilCompleted()
        
        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.inflightSemaphore)
            }
            return
        }
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(drawableRenderPassDescriptor)
        renderEncoder.label = "render encoder"
        
        renderEncoder.pushDebugGroup("DistanceField")
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(quadUVBuffer, offset: 0, atIndex: 1)
        renderEncoder.setFragmentTexture(texture, atIndex: 0)
        renderEncoder.setFragmentSamplerState(sampler, atIndex: 0)
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6)
        
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        
        bufferIndex = (bufferIndex + 1) % MaxBuffers
        
        commandBuffer.commit()
    }
    
    func mouseMoved(x: Float, y: Float)
    {
        camera.rotate(x, y)
    }
}