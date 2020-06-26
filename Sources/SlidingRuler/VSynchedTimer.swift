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
    typealias Animations = (TimeInterval, TimeInterval) -> ()
    typealias Completion = (Bool) -> ()

    private let timer: SynchedTimer
    
    init(duration: TimeInterval, animations: @escaping Animations, completion: Completion? = nil) {
        self.timer = .init(duration, animations, completion)
    }

    func cancel() { timer.cancel() }
}


private final class SynchedTimer {
    private let duration: TimeInterval
    private let animationBlock: VSynchedTimer.Animations
    private let completionBlock: VSynchedTimer.Completion?
    private weak var displayLink: CADisplayLink?
    
    private var isRunning: Bool
    private let startTimeStamp: TimeInterval
    private var lastTimeStamp: TimeInterval
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    init(_ duration: TimeInterval, _ animations: @escaping VSynchedTimer.Animations, _ completion: VSynchedTimer.Completion? = nil) {
        self.duration = duration
        self.animationBlock = animations
        self.completionBlock = completion
        
        self.isRunning = true
        self.startTimeStamp = CACurrentMediaTime()
        self.lastTimeStamp = startTimeStamp
        self.displayLink = self.createDisplayLink()
    }
    
    func cancel() {
        guard isRunning else { return }

        isRunning.toggle()
        displayLink?.invalidate()
        self.completionBlock?(false)
    }

    private func complete() {
        guard isRunning else { return }

        isRunning.toggle()
        displayLink?.invalidate()
        self.completionBlock?(true)
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        guard isRunning else { return }

        let currentTimeStamp = CACurrentMediaTime()
        let progress = currentTimeStamp - startTimeStamp
        let elapsed = currentTimeStamp - lastTimeStamp
        lastTimeStamp = currentTimeStamp

        if progress < duration {
            animationBlock(progress, elapsed)
        } else {
            complete()
        }
    }
    
    private func createDisplayLink() -> CADisplayLink {
        let dl = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        dl.add(to: .main, forMode: .common)
        
        return dl
    }
}
