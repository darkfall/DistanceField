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

extension NSView {
    func location(for event: NSEvent) -> CGPoint {
        return convert(event.locationInWindow, from: nil)
    }
}

class GameViewController: NSViewController, MTKViewDelegate {
    
    override var acceptsFirstResponder: Bool { return true }
    var trackingArea: NSTrackingArea! = nil
    var renderer: MTLDistanceField! = nil

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        renderer = MTLDistanceField(isLowPower: false)
        
        let view = self.view as! MTKView
        view.delegate = self
        view.device = renderer.device
        view.sampleCount = 1
        
        let trackingOptions : NSTrackingAreaOptions = [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved]

        trackingArea = NSTrackingArea(rect: view.bounds, options: trackingOptions, owner: view, userInfo: nil)
        view.addTrackingArea(trackingArea)
        
        loadAssets()
    }
    
    func loadAssets() {
        let view = self.view as! MTKView
        
        renderer.loadAssets(view.colorPixelFormat, sampleCount: view.sampleCount, width: Int(view.frame.size.width), height: Int(view.frame.size.height))
    }
    
    func draw(in view: MTKView) {
        renderer.draw(view.currentDrawable!, drawableRenderPassDescriptor: view.currentRenderPassDescriptor!)
    }
//    
//    override func keyDown(theEvent: NSEvent) {
//        
//    }
//    
    override func mouseMoved(with event: NSEvent) {
        let pos = view.location(for: event)
//        
//        renderer.mouseMoved(Float(self.view.bounds.size.width) / 2 - Float(pos.x),
//                            y: Float(pos.y) - Float(self.view.bounds.size.height) / 2)
        renderer.mouseMoved(Float(event.deltaX), y: Float(event.deltaY))
    }
//
//    override func mouseDown(theEvent: NSEvent) {
//        
//    }
//    
//    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
