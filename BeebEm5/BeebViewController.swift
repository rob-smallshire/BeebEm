//
//  BeebViewController.swift
//  BeebEm5
//
//  Created by Commander Coder on 25/07/2020.
//  Copyright © 2020 Andrew Hague. All rights reserved.
//

import Cocoa
import Carbon


// MODIFIED FOR MacOS FROM
// https://github.com/nicklockwood/RetroRampage
// AND
// https://stackoverflow.com/questions/25981553/cvdisplaylink-with-swift

class BeebViewController: NSViewController {

    @IBOutlet var imageView: BeebImageView!
    
    var displayLink : CVDisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        // create a callback for the DisplayLink to the update() method of this class
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = {
            (displayLink: CVDisplayLink, inNow: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>, flagsIn: CVOptionFlags, flagsOut: UnsafeMutablePointer<CVOptionFlags>, displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in

            // need to typecast the context from pointer to self.
            let view = unsafeBitCast(displayLinkContext, to: BeebViewController.self)

            DispatchQueue.main.async {
              // the use of 'imageView' variable must occur on the main thread
              view.update(displayLink)
            }
            
            return kCVReturnSuccess
        }
                
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        // need to convert 'self' to unsafe pointer
        CVDisplayLinkSetOutputCallback(displayLink!,
                                       displayLinkOutputCallback,
                                       UnsafeMutableRawPointer(
                                        Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink!)
        
        setupBeeb()

    }
    
    func update(_ displayLink: CVDisplayLink) {
        var renderer = Renderer(width: 640, height: 512)
        renderer.draw()
        
        imageView.image = NSImage(bitmap: renderer.bitmap)

        // update the CPU
        update_cpu()
    }


    deinit {
        //  Stop the display link.  A better place to stop the link is in
        //  the viewController or windowController within functions such as
        //  windowWillClose(_:)
        CVDisplayLinkStop(displayLink!)

        end_cpu()

    }

    
    
    private var cpuUpdateSpeed: Double = 200.0
    private var cpuDelaying = false

    private var width : Int = 0
    private var height : Int = 0
    
    @IBOutlet weak var WIPlabel: NSTextField!

 
    func setupBeeb()
    {
        width = 640
        height = 512
        
        //init_audio()
        init_cpu()
    }

}



// - CPU
extension BeebViewController{
    
    func init_cpu()
    {
        var commandline : [UnsafeMutablePointer<Int8>?] = []
        
        // convert the Strings to UnsafeMutablePointer<Int8>? suitable for passing to C
        for a in 0 ..< Int(CommandLine.argc)
        {
            commandline.append(strdup(CommandLine.arguments[a]))
        }
        
        // pass the 'arr' into the closure as the variable p as unsafe mutable bytes - this is
        // so that beeb_main can modify them if necessary
        commandline.withUnsafeMutableBytes { (p) -> () in
            // find the base address of the UnsafeMutableRawBufferPointer (it is a UnsafeMutableRawPointer)
            // get the typed pointer to the base address assuming it is already bound to a type
            // in this case it will make pp : UnsafeMutablePointer<Int8>
            // self is the arr instance
            let pp = p.baseAddress?.assumingMemoryBound(to: UnsafeMutablePointer<Int8>?.self)
            beeb_main(CommandLine.argc, pp)
        }
    }
    
    func update_cpu()  // game update
    {
        
        tcViewControllerInstance?.update()

        if let mainwindow = NSApplication.shared.mainWindow {
            mainwindow.title = CBridge.windowTitle
        }
        WIPlabel?.stringValue = CBridge.windowTitle

        
        if !cpuDelaying {
        
            cpuDelaying = true
            
            // update the CPU after any calculated delay that came from the previous CPU update
            DispatchQueue.main.asyncAfter(deadline: .now() + .microseconds(CBridge.nextCPU), execute: {
                CBridge.nextCPU = 0
                beeb_MainCpuLoop()
                self.cpuDelaying = false
            })
            
        }
    }

    
    func end_cpu()
    {
        beeb_end()
    }
    
}
