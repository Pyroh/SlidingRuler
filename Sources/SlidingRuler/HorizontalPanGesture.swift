//
//  HorizontalPanGesture.swift
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
import CoreGeometry

struct HorizontalDragGestureValue {
    let state: UIGestureRecognizer.State
    let translation: CGSize
    let velocity: CGFloat
    let startLocation: CGPoint
    let location: CGPoint
}

protocol HorizontalPanGestureReceiverViewDelegate: AnyObject {
    func viewTouchedWithoutPan(_ view: UIView)
}

class HorizontalPanGestureReceiverView: UIView {
    weak var delegate: HorizontalPanGestureReceiverViewDelegate?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        delegate?.viewTouchedWithoutPan(self)
    }
}

extension View {
    func onHorizontalDragGesture(initialTouch: @escaping () -> () = { },
                                 prematureEnd: @escaping () -> () = { },
                                 perform action: @escaping (HorizontalDragGestureValue) -> ()) -> some View {
        self.overlay(HorizontalPanGesture(beginTouch: initialTouch, prematureEnd: prematureEnd, action: action))
    }
}

private struct HorizontalPanGesture: UIViewRepresentable {
    typealias Action = (HorizontalDragGestureValue) -> ()
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate, HorizontalPanGestureReceiverViewDelegate {
        private let beginTouch: () -> ()
        private let prematureEnd: () -> ()
        private let action: Action
        weak var view: UIView?
        
        init(_ beginTouch: @escaping () -> () = { }, _ prematureEnd: @escaping () -> () = { }, _ action: @escaping Action) {
            self.beginTouch = beginTouch
            self.prematureEnd = prematureEnd
            self.action = action
        }
        
        @objc func panGestureHandler(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: view)
            let velocity = gesture.velocity(in: view)
            let location = gesture.location(in: view)
            let startLocation = location - translation

            let value = HorizontalDragGestureValue(state: gesture.state,
                                                   translation: .init(horizontal: translation.x),
                                                   velocity: velocity.x,
                                                   startLocation: startLocation,
                                                   location: location)
            self.action(value)
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pgr = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pgr.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
            beginTouch()
            return true
        }

        func viewTouchedWithoutPan(_ view: UIView) {
            prematureEnd()
        }
    }

    @Environment(\.slidingRulerStyle) private var style
    
    let beginTouch: () -> ()
    let prematureEnd: () -> ()
    let action: Action
    
    func makeCoordinator() -> Coordinator {
        .init(beginTouch, prematureEnd, action)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = HorizontalPanGestureReceiverView(frame: .init(size: .init(square: 42)))
        let pgr = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panGestureHandler(_:)))
        view.delegate = context.coordinator
        pgr.delegate = context.coordinator
        view.addGestureRecognizer(pgr)
        context.coordinator.view = view

        // Pointer interactions
        if #available(iOS 13.4, *), style.supportsPointerInteraction {
            pgr.allowedScrollTypesMask = .continuous
            view.addInteraction(UIPointerInteraction(delegate: context.coordinator))
        }

        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
}

@available(iOS 13.4, *)
extension HorizontalPanGesture.Coordinator: UIPointerInteractionDelegate {
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        .init(shape: .path(Pointers.standard), constrainedAxes: .vertical)
    }
}
