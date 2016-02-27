//
//  GameViewController.swift
//  DistanceField
//
//  Created by Robert Bu on 2/25/16.
//  Copyright (c) 2016 Robert Bu. All rights reserved.
//

import Cocoa
import MetalKit
import simd

let MaxBuffers = 3
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

class GameViewController: NSViewController, MTKViewDelegate {
    
    override var acceptsFirstResponder: Bool { return true }
    
    var device: MTLDevice! = nil
    
    var commandQueue: MTLCommandQueue! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    var computePipelineState: MTLComputePipelineState! = nil
    var camera: Camera! = nil
    var texture: MTLTexture! = nil
    var quadVertexBuffer: MTLBuffer! = nil
    var quadUVBuffer: MTLBuffer! = nil
    var sampler: MTLSamplerState! = nil
    var trackingArea: NSTrackingArea! = nil
    
    let inflightSemaphore = dispatch_semaphore_create(MaxBuffers)
    var bufferIndex = 0

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let devices = MTLCopyAllDevices()
        for d in devices
        {
            if (!d.lowPower)
            {
                device = d
                break
            }
        }
        guard device != nil else { // Fallback to a blank NSView, an application could also fallback to OpenGL here.
            print("Metal is not supported on this device")
            self.view = NSView(frame: self.view.frame)
            return
        }

        // setup view properties
        let view = self.view as! MTKView
        view.delegate = self
        view.device = device
        view.sampleCount = 1
        
//        self.nextResponder = self.view
//        for subview in self.view.subviews {
//            subview.nextResponder = self
//        }
//        
        let trackingOptions = NSTrackingAreaOptions(rawValue: NSTrackingAreaOptions.ActiveAlways.rawValue |
                                                              NSTrackingAreaOptions.InVisibleRect.rawValue |
                                                              NSTrackingAreaOptions.MouseEnteredAndExited.rawValue |
                                                              NSTrackingAreaOptions.MouseMoved.rawValue)
        trackingArea = NSTrackingArea(rect: self.view.bounds, options: trackingOptions, owner: self.view, userInfo: nil)
        [self.view .addTrackingArea(trackingArea)]
        
        loadAssets()
    }
    
    func loadAssets() {
        let view = self.view as! MTKView
        
        commandQueue = device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.newFunctionWithName("passThroughFragment")!
        let vertexProgram = defaultLibrary.newFunctionWithName("passThroughVertex")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineStateDescriptor.sampleCount = view.sampleCount
        
        do {
            try pipelineState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
        }
        
        camera = Camera(vf3(10.0, 10.0, 0.0), vf3(0, 0, 0), vf3(0, 1, 0),
            Float(3.14159265 / 360.0), Float(view.frame.size.width), Float(view.frame.size.height))
        
        let texDescirptor = MTLTextureDescriptor()
        texDescirptor.width = Int(view.frame.size.width)
        texDescirptor.height = Int(view.frame.size.height)
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
    }
    
    func update() {
        
      
    }
    
    func drawInMTKView(view: MTKView) {
        
        dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        self.update()
        
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
        let numThreadgroups = MTLSize(width: Int(view.frame.size.width+15) / threadsPerGroup.width, height: Int(view.frame.size.height+15) / threadsPerGroup.height, depth: 1)
        
        computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        computeCmdBuffer.commit()
        computeCmdBuffer.waitUntilCompleted()
        
        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.inflightSemaphore)
            }
            return
        }
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor, currentDrawable = view.currentDrawable
        {
            
            let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
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
                
            commandBuffer.presentDrawable(currentDrawable)
        }
        
        // bufferIndex matches the current semaphore controled frame index to ensure writing occurs at the correct region in the vertex buffer
        bufferIndex = (bufferIndex + 1) % MaxBuffers
        
        commandBuffer.commit()
    }
//    
//    override func keyDown(theEvent: NSEvent) {
//        
//    }
//    
    override func mouseMoved(theEvent: NSEvent) {
        let pos = self.view.convertPoint(theEvent.locationInWindow, fromView: self.view)
        
        camera.rotate(Float(self.view.bounds.size.width) / 2 - Float(pos.x),
                      Float(pos.y) - Float(self.view.bounds.size.height) / 2)
    }
//
//    override func mouseDown(theEvent: NSEvent) {
//        
//    }
//    
//    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
