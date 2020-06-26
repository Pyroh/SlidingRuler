//
//  ViewExtension.swift
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

extension View {
    public func slidingRulerStyle<S>(_ style: S) -> some View where S: SlidingRulerStyle {
        environment(\.slidingRulerStyle, .init(style: style))
    }

    public func slidingRulerCellOverflow(_ overflow: Int) -> some View {
        environment(\.slidingRulerCellOverflow, overflow)
    }
}

extension View {
    func frame(size: CGSize?, alignment: Alignment = .center) -> some View {
        self.frame(width: size?.width, height: size?.height, alignment: alignment)
    }

    func onPreferenceChange<K: PreferenceKey>(_ key: K.Type,
                                              storeValueIn storage: Binding<K.Value>,
                                              action: (() -> ())? = nil ) -> some View where K.Value: Equatable {
        onPreferenceChange(key, perform: {
            storage.wrappedValue = $0
            action?()
        })
    }

    func propagateHeight<K: PreferenceKey>(_ key: K.Type, transform: @escaping (K.Value) -> K.Value = { $0 }) -> some View where K.Value == CGFloat? {
        overlay(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: key, value: transform(proxy.size.height))
            }
        )
    }

    func propagateWidth<K: PreferenceKey>(_ key: K.Type, transform: @escaping (K.Value) -> K.Value = { $0 }) -> some View where K.Value == CGFloat? {
        overlay(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: key, value: transform(proxy.size.width))
            }
        )
    }
}
