//
//  ScaleView.swift
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

struct ScaleView: View, Equatable {
    private struct ScaleShape: Shape {
        private var unitsSize: CGSize { .init(width: 3.0, height: 27.0)}
        private var halvesSize: CGSize { .init(width: UIScreen.main.scale == 3 ? 1.8 : 2.0, height: 19.0) }
        private var tenthsSize: CGSize { .init(width: 1.0, height: 11.0)}
        
        func path(in rect: CGRect) -> Path {
            let centerX = rect.center.x
            var p = Path()
            
            p.addRoundedRect(in: unitRect(x: centerX), cornerSize: .init(square: unitsSize.width/2))
            p.addRoundedRect(in: halfRect(x: 0), cornerSize: .init(square: halvesSize.width/2))
            p.addRoundedRect(in: halfRect(x: rect.maxX), cornerSize: .init(square: halvesSize.width/2))
            
            let tenth = rect.width / 10
            for i in 1...4 {
                p.addRoundedRect(in: tenthRect(x: centerX + CGFloat(i) * tenth), cornerSize: .init(square: tenthsSize.width/2))
                p.addRoundedRect(in: tenthRect(x: centerX - CGFloat(i) * tenth), cornerSize: .init(square: tenthsSize.width/2))
            }
            
            return p
        }
        
        private func unitRect(x: CGFloat) -> CGRect { rect(centerX: x, size: unitsSize) }
        private func halfRect(x: CGFloat) -> CGRect { rect(centerX: x, size: halvesSize) }
        private func tenthRect(x: CGFloat) -> CGRect { rect(centerX: x, size: tenthsSize) }
        
        private func rect(centerX x: CGFloat, size: CGSize) -> CGRect {
            CGRect(origin: .init(x: x - size.width / 2, y: 0), size: size)
        }
    }

    let width: CGFloat
    private let height: CGFloat = 30.0
    
    var body: some View {
        return ScaleShape()
            .frame(size: .init(width: width, height: height))
            .fixedSize()
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.width == rhs.width
    }
}
