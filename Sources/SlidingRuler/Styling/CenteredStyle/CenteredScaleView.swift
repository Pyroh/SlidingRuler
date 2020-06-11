//
//  BlankCellView.swift
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


import SwiftUI

struct CenteredScaleView: ScaleView {
    struct ScaleShape: Shape {
        fileprivate var unitMarkSize: CGSize { .init(width: 3.0, height: 27.0)}
        fileprivate var halfMarkSize: CGSize { .init(width: UIScreen.main.scale == 3 ? 1.8 : 2.0, height: 19.0) }
        fileprivate var fractionMarkSize: CGSize { .init(width: 1.0, height: 11.0)}

        func path(in rect: CGRect) -> Path {
            let centerX = rect.center.x
            let centerY = rect.center.y
            var p = Path()

            p.addRoundedRect(in: unitRect(x: centerX, y: centerY), cornerSize: .init(square: unitMarkSize.width/2))
            p.addRoundedRect(in: halfRect(x: 0, y: centerY), cornerSize: .init(square: halfMarkSize.width/2))
            p.addRoundedRect(in: halfRect(x: rect.maxX, y: centerY), cornerSize: .init(square: halfMarkSize.width/2))

            let tenth = rect.width / 10
            for i in 1...4 {
                p.addRoundedRect(in: tenthRect(x: centerX + CGFloat(i) * tenth, y: centerY), cornerSize: .init(square: fractionMarkSize.width/2))
                p.addRoundedRect(in: tenthRect(x: centerX - CGFloat(i) * tenth, y: centerY), cornerSize: .init(square: fractionMarkSize.width/2))
            }

            return p
        }

        private func unitRect(x: CGFloat, y: CGFloat) -> CGRect { .init(center: .init(x: x, y: y), size: unitMarkSize) }
        private func halfRect(x: CGFloat, y: CGFloat) -> CGRect { .init(center: .init(x: x, y: y), size: halfMarkSize) }
        private func tenthRect(x: CGFloat, y: CGFloat) -> CGRect { .init(center: .init(x: x, y: y), size: fractionMarkSize) }
    }

    let width: CGFloat
    let height: CGFloat
    var shape: ScaleShape { .init() }

    var unitMarkWidth: CGFloat { shape.unitMarkSize.width }
    var halfMarkWidth: CGFloat { shape.halfMarkSize.width }
    var fractionMarkWidth: CGFloat { shape.fractionMarkSize.width }

    init(width: CGFloat, height: CGFloat = 30) {
        self.width = width
        self.height = height
    }
}
