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
        
        renderer.loadAssets(view.colorPixelFormat, sampleCount: view.sampleCount, width: Int(view.frame.size.width), height: Int(view.frame.size.height))
    }
    
    func drawInMTKView(view: MTKView) {
        renderer.draw(view.currentDrawable!, drawableRenderPassDescriptor: view.currentRenderPassDescriptor!)
    }
//    
//    override func keyDown(theEvent: NSEvent) {
//        
//    }
//    
    override func mouseMoved(theEvent: NSEvent) {
        let pos = self.view.convertPoint(theEvent.locationInWindow, fromView: self.view)
        
        renderer.mouseMoved(Float(self.view.bounds.size.width) / 2 - Float(pos.x),
                            y: Float(pos.y) - Float(self.view.bounds.size.height) / 2)
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
