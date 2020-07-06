//
//  Pointers.swift
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


import UIKit.UIBezierPath

enum Pointers {
    static var standard: UIBezierPath {
        let path = UIBezierPath()

        path.move(to: CGPoint(x: 18.78348, y: 1.134168))
        path.addCurve(to: CGPoint(x: 19, y: 2.051366), controlPoint1: CGPoint(x: 18.925869, y: 1.418949), controlPoint2: CGPoint(x: 19, y: 1.732971))
        path.addLine(to: CGPoint(x: 19, y: 16.949083))
        path.addCurve(to: CGPoint(x: 16.949083, y: 19), controlPoint1: CGPoint(x: 19, y: 18.081774), controlPoint2: CGPoint(x: 18.081774, y: 19))
        path.addCurve(to: CGPoint(x: 16.031885, y: 18.78348), controlPoint1: CGPoint(x: 16.63069, y: 19), controlPoint2: CGPoint(x: 16.316668, y: 18.925869))
        path.addLine(to: CGPoint(x: 1.134168, y: 11.33462))
        path.addCurve(to: CGPoint(x: 0.21697, y: 8.583027), controlPoint1: CGPoint(x: 0.121059, y: 10.828066), controlPoint2: CGPoint(x: -0.289584, y: 9.596135))
        path.addCurve(to: CGPoint(x: 1.134168, y: 7.665829), controlPoint1: CGPoint(x: 0.415425, y: 8.186118), controlPoint2: CGPoint(x: 0.737259, y: 7.864284))
        path.addLine(to: CGPoint(x: 16.031885, y: 0.21697))
        path.addCurve(to: CGPoint(x: 18.78348, y: 1.134168), controlPoint1: CGPoint(x: 17.044994, y: -0.289584), controlPoint2: CGPoint(x: 18.276924, y: 0.121059))
        path.close()
        path.move(to: CGPoint(x: 30.21652, y: 1.134168))
        path.addCurve(to: CGPoint(x: 32.968113, y: 0.21697), controlPoint1: CGPoint(x: 30.723076, y: 0.121059), controlPoint2: CGPoint(x: 31.955006, y: -0.289584))
        path.addLine(to: CGPoint(x: 32.968113, y: 0.21697))
        path.addLine(to: CGPoint(x: 47.865833, y: 7.665829))
        path.addCurve(to: CGPoint(x: 48.783031, y: 8.583027), controlPoint1: CGPoint(x: 48.262741, y: 7.864284), controlPoint2: CGPoint(x: 48.584576, y: 8.186118))
        path.addCurve(to: CGPoint(x: 47.865833, y: 11.33462), controlPoint1: CGPoint(x: 49.289585, y: 9.596135), controlPoint2: CGPoint(x: 48.878941, y: 10.828066))
        path.addLine(to: CGPoint(x: 47.865833, y: 11.33462))
        path.addLine(to: CGPoint(x: 32.968113, y: 18.78348))
        path.addCurve(to: CGPoint(x: 32.050915, y: 19), controlPoint1: CGPoint(x: 32.683334, y: 18.925869), controlPoint2: CGPoint(x: 32.369312, y: 19))
        path.addCurve(to: CGPoint(x: 30, y: 16.949083), controlPoint1: CGPoint(x: 30.918226, y: 19), controlPoint2: CGPoint(x: 30, y: 18.081774))
        path.addLine(to: CGPoint(x: 30, y: 16.949083))
        path.addLine(to: CGPoint(x: 30, y: 2.051366))
        path.addCurve(to: CGPoint(x: 30.21652, y: 1.134168), controlPoint1: CGPoint(x: 30, y: 1.732971), controlPoint2: CGPoint(x: 30.074131, y: 1.418949))
        path.close()
        path.move(to: CGPoint(x: 24.5, y: 6))
        path.addCurve(to: CGPoint(x: 28, y: 9.5), controlPoint1: CGPoint(x: 26.432997, y: 6), controlPoint2: CGPoint(x: 28, y: 7.567003))
        path.addCurve(to: CGPoint(x: 24.5, y: 13), controlPoint1: CGPoint(x: 28, y: 11.432997), controlPoint2: CGPoint(x: 26.432997, y: 13))
        path.addCurve(to: CGPoint(x: 21, y: 9.5), controlPoint1: CGPoint(x: 22.567003, y: 13), controlPoint2: CGPoint(x: 21, y: 11.432997))
        path.addCurve(to: CGPoint(x: 24.5, y: 6), controlPoint1: CGPoint(x: 21, y: 7.567003), controlPoint2: CGPoint(x: 22.567003, y: 6))
        path.close()

        path.apply(.init(translationX: -24.5, y: 0))

        return path
    }
}
