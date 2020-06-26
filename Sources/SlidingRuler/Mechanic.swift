//
//  Mechanic.swift
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

import UIKit.UIScrollView
import CoreGraphics

enum Mechanic {

    enum Inertia {
        private static let epsilon: CGFloat = 0.6

        /// Velocity at time `t` of the initial velocity `v0` decelerated by the given deceleration rate.
        static func velocity(atTime t: TimeInterval, v0: CGFloat, decelerationRate rate: UIScrollView.DecelerationRate) -> CGFloat {
            v0 * pow(rate.rawValue, (1000 * CGFloat(t)))
        }

        /// Travelled distance at time `t` for the initial velocity `v0` decelerated by the given deceleration rate.
        static func distance(atTime t: TimeInterval, v0: CGFloat, decelerationRate rate: UIScrollView.DecelerationRate) -> CGFloat {
            v0 * (pow(rate.rawValue, 1000 * CGFloat(t)) - 1) / (coef(rate))
        }

        /// Total distance travelled for he initial velocity `v0` decelerated by the given deceleration rate before being completely still.
        static func totalDistance(forVelocity v0: CGFloat, decelerationRate rate: UIScrollView.DecelerationRate) -> CGFloat {
            distance(atTime: duration(forVelocity: v0, decelerationRate: rate), v0: v0, decelerationRate: rate)
        }

        /// Total time ellapsed before the motion become completely still for the initial velocity `v0` decelerated by the given deceleration rate.
        static func duration(forVelocity v0: CGFloat, decelerationRate rate: UIScrollView.DecelerationRate) -> TimeInterval {
            TimeInterval((log((-1000 * epsilon * log(rate.rawValue)) / abs(v0))) / coef(rate))
        }

        static func time(toReachDistance x: CGFloat, forVelocity v0: CGFloat, decelerationRate rate: UIScrollView.DecelerationRate) -> TimeInterval {
            TimeInterval(log(1 + coef(rate) * x / v0) / coef(rate))
        }

        static func coef(_ rate: UIScrollView.DecelerationRate) -> CGFloat {
            1000 * log(rate.rawValue)
        }
    }

    enum Spring {
        private static var e: CGFloat { CGFloat(M_E) }
        private static var threshold: CGFloat { 0.25 }

        private static var stiffness: CGFloat { 100 }
        private static var damping: CGFloat { 2 * sqrt(stiffness) }
        private static var beta: CGFloat { sqrt(stiffness) }

        static func duration(forVelocity v0: CGFloat, displacement c1: CGFloat) -> TimeInterval {
            guard v0 + c1 != 0 else { return .zero }

            let c2 = v0 + beta * c1

            let t1 = 1 / beta * log(2 * c1 / threshold)
            let t2 = 2 / beta * log(4 * c2 / (e * beta * threshold))

            return TimeInterval(max(t1, t2))
        }

        static func value(atTime t: TimeInterval, v0: CGFloat, displacement c1: CGFloat) -> CGFloat {
            let c2 = v0 + beta * c1

            return exp(-beta * CGFloat(t)) * (c1 + c2 * CGFloat(t))
        }
    }
}
