//
//  VSynchedTimer.swift
//
//  SlidingRuler
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import UIKit

struct VSynchedTimer {
    private let timer: SynchedTimer
    
    init(animations: @escaping (TimeInterval) -> (), completion: ((Bool) -> ())? = nil) {
        self.timer = .init(animations: animations, completion: completion)
    }
    
    func stop() { timer.stop() }
    func cancel() { timer.cancel() }
}


private final class SynchedTimer {
    private let animationBlock: (TimeInterval) -> ()
    private let completionBlock: ((Bool) -> ())?
    private weak var displayLink: CADisplayLink?
    
    private var isRunning: Bool
    private var lastTimeStamp: TimeInterval
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    init(animations: @escaping (TimeInterval) -> (), completion: ((Bool) -> ())? = nil) {
        self.animationBlock = animations
        self.completionBlock = completion
        
        self.isRunning = true
        self.lastTimeStamp = CACurrentMediaTime()
        self.displayLink = self.createDisplayLink()
    }
    
    func cancel() {
        if isRunning {
            isRunning.toggle()
            displayLink?.invalidate()
            NextLoop { self.completionBlock?(false) }
        }
    }
    
    func stop() {
        if isRunning {
            isRunning.toggle()
            displayLink?.invalidate()
            completionBlock?(true)
        }
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        guard isRunning else { return }
        let currentTimeStamp = CACurrentMediaTime()
        let elapsed = currentTimeStamp - lastTimeStamp
        lastTimeStamp = currentTimeStamp
        animationBlock(elapsed)
    }
    
    private func createDisplayLink() -> CADisplayLink {
        let dl = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        dl.add(to: .main, forMode: .common)
        
        return dl
    }
}
