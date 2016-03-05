//
//  GameViewController.swift
//  DistanceField_iOS
//
//  Created by ruiwei_bu on 3/1/16.
//  Copyright © 2016 Robert Bu. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class GameViewController:UIViewController, MTKViewDelegate {
    
    var renderer: MTLDistanceField! = nil
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        renderer = MTLDistanceField(isLowPower: false)
        
        let view = self.view as! MTKView
        view.delegate = self
        view.device = renderer.device
        view.sampleCount = 1
        
        loadAssets()
    }
    
    func loadAssets() {
        
        let view = self.view as! MTKView
        
        renderer.loadAssets(view.colorPixelFormat, sampleCount: view.sampleCount, width: Int(view.frame.size.width), height: Int(view.frame.size.height))
    }
    
    func drawInMTKView(view: MTKView) {
        
        renderer.draw(view.currentDrawable!, drawableRenderPassDescriptor: view.currentRenderPassDescriptor!)
    }
    
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
