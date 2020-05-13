//
//  SlidingRuler.swift
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
import SmoothOperators

@available(iOS 13.0, *)
public struct SlidingRuler<V>: View where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
    typealias S = V.Stride

    @Environment(\.slidingRulerStyle) private var style
    @Environment(\.slidingRulerStyle.cellWidth) private var cellWidth
    @Environment(\.slidingRulerStyle.cursorAlignment) private var verticalCursorAlignment
    @Environment(\.slidingRulerStyle.fractions) private var fractions
    @Environment(\.slidingRulerStyle.hasHalf) private var hasHalf
    
    @Environment(\.slideRulerCellOverflow) private var cellOverflow
    @Environment(\.layoutDirection) private var layoutDirection
    
    @Binding private var value: V
    private let bounds: ClosedRange<V>
    private let step: S
    private let stickyMark: TickMark
    private let tick: TickMark
    private let editingChangedCallback: (Bool) -> ()
    private let formatter: NumberFormatter?

    @State private var controlWidth: CGFloat?
    @State private var rulerHeight: CGFloat?
    
    @State private var cells: [RulerCell<V>] = []
    
    @State private var state: SlidingRulerState = .idle
    @State private var animatedValue: V = .zero
    
    @State private var referenceOffset: CGSize?
    @State private var dragOffset: CGSize = .zero
    
    @State private var inertialTimer: VSynchedTimer? = nil
    @State private var lastValueSet: V = .zero
    @State private var markOffset: Double = .zero
    
    private var dragBounds: ClosedRange<CGFloat> {
        (-CGFloat(bounds.upperBound) * cellWidth / CGFloat(step))...(-CGFloat(bounds.lowerBound) * cellWidth / CGFloat(step))
    }
    private var shouldReleaseRubberBand: Bool { !dragBounds.contains(dragOffset.width) }
    private var clampedValue: V { value.clamped(to: bounds) }

    private var effectiveOffset: CGSize {
        switch state {
        case .idle:
            return self.offset(fromValue: clampedValue ?? 0)
        case .animating:
            return self.offset(fromValue: animatedValue ?? 0)
        default:
            return dragOffset
        }
    }

    private var effectiveValue: V {
        switch state {
        case .idle, .flicking:
            return clampedValue ?? 0
        case .animating:
            return animatedValue ?? 0
        default:
            return value ?? 0
        }
    }

    
    public init(value: Binding<V>,
         in bounds: ClosedRange<V> = -V.infinity...V.infinity,
         step: V.Stride = 1,
         stickyMark: TickMark = .none,
         tick: TickMark = .none,
         onEditingChanged: @escaping (Bool) -> () = { _ in },
         formatter: NumberFormatter? = nil) {
        self._value = value
        self.bounds = bounds
        self.step = step
        self.stickyMark = stickyMark
        self.tick = tick
        self.editingChangedCallback = onEditingChanged
        self.formatter = formatter
    }
    
    public var body: some View {
        switch self.state {
        case .animating:
            NextLoop { self.state = .idle }
        case .flicking:
            NextLoop {
                if self.value != self.lastValueSet {
                    self.inertialTimer?.cancel()
                    self.state = .idle
                }
            }
        default: break
        }

        return GeometryReader { proxy in
            ZStack(alignment: .init(horizontal: .center, vertical: self.verticalCursorAlignment)) {
                Ruler(cells: self.cells, step: Double(self.step), markOffset: self.markOffset, bounds: self.bounds, formatter: self.formatter)
                    .equatable()
                    .animation(nil)
                    .modifier(InfiniteOffsetEffect(offset: self.effectiveOffset, maxOffset: 240))
                self.style.makeCursorBody()
            }
            .frame(width: proxy.size.width)
            .clipped()
            .propagateWidth(ControlWidthPreferenceKey.self)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onHorizontalDragGesture(initialTouch: firstTouchHappened, perform: horizontalDragAction(withValue:))
        .modifier(InfiniteMarkOffsetModifier(effectiveValue, step: step))
        .onPreferenceChange(MarkOffsetPreferenceKey.self, perform: { self.markOffset = $0})
        .onPreferenceChange(ControlWidthPreferenceKey.self, perform: {
            self.controlWidth = $0
            self.updateCellsIfNeeded()
        })
        .onHeightPreferenceChange(RulerHeightPreferenceKey.self, storeValueIn: $rulerHeight)
        .transaction({
            if $0.animation != nil && self.state == .idle { $0.animation = .easeIn(duration: 0.1) }
        })
        .frame(height: rulerHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension SlidingRuler {
    
    // MARK: Drag Gesture Management
    
    private func horizontalDragAction(withValue value: HorizontalDragGestureValue) {
        switch value.state {
        case .began: horizontalDragBegan(value)
        case .changed: horizontalDragChanged(value)
        case .ended: horizontalDragEnded(value)
        default: return
        }
    }
    
    private func firstTouchHappened() {
        if state == .flicking {
            inertialTimer?.cancel()
            state = .idle
        }
    }
    
    private func horizontalDragBegan(_ value: HorizontalDragGestureValue) {
        if referenceOffset == nil {
            editingChangedCallback(true)
            referenceOffset = effectiveOffset
            state = .dragging
        }
    }
    
    private func horizontalDragChanged(_ value: HorizontalDragGestureValue) {
        let newOffset = self.directionalOffset(value.translation.horizontal + (referenceOffset ?? .zero))
        let newValue = self.value(fromOffset: newOffset)
        
        self.tickIfNeeded(dragOffset.width, newOffset.width)
        
        withoutAnimation {
            self.setValue(newValue, via: \.$value)
            dragOffset = self.applyRubber(to: newOffset)
        }
    }
    
    private func horizontalDragEnded(_ value: HorizontalDragGestureValue) {
        if shouldReleaseRubberBand {
            self.releaseRubberBand()
            self.endDragSession()
        } else if abs(value.velocity) > 40 {
            self.applyInertia(startLoc: value.startLocation, releaseLoc: value.location, initialVelocity: value.velocity)
        } else {
            state = .idle
            self.endDragSession()
            self.snapIfNeeded()
        }
    }
    
    private func endDragSession() {
        referenceOffset = nil
        self.editingChangedCallback(false)
    }
}

extension SlidingRuler {

    // MARK: Value Management
    
    private func value(fromOffset offset: CGSize) -> V {
        self.directionalValue(-V(offset.width / cellWidth) * V(step))
    }
    
    private func offset(fromValue value: V) -> CGSize {
        let width = CGFloat(-value * V(cellWidth) / V(step))
        return self.directionalOffset(.init(horizontal: width))
    }
    
    private func setValue(_ newValue: V, via key: KeyPath<Self, Binding<V>>) {
        func get() -> V { self[keyPath: key].wrappedValue }
        func set(_ value: V) { self[keyPath: key].wrappedValue = value }
        
        let clampedValue = newValue.clamped(to: bounds)
        
        if clampedValue.isBound(of: bounds) && !get().isBound(of: self.bounds) {
            self.boundaryMet()
        }
        
        if lastValueSet != clampedValue { lastValueSet = clampedValue }
        if get() != clampedValue { set(clampedValue) }
    }
    
    private func snapIfNeeded() {
        let nearest = self.nearestSnapValue(self.value)
        guard nearest != value else { return }

        let delta = abs(nearest - value)
        let fractionalValue = V(step / S(fractions))

        guard delta <= fractionalValue else { return }

        let animThreshold = V(step / 200)
        let animation: Animation? = delta > animThreshold ? .easeOut(duration: 0.1) : nil

        dragOffset = offset(fromValue: nearest)
        withAnimation(animation) { self.value = nearest }
    }
    
    private func nearestSnapValue(_ value: V) -> V {
        let t: V

        switch stickyMark {
        case .unit: t = V(step)
        case .half: t = V(step / 2)
        case .fraction: t = V(step / S(fractions))
        default: return value
        }

        let lower = (value / t).rounded(.down) * t
        let upper = (value / t).rounded(.up) * t
        let deltaDown = abs(value - lower)
        let deltaUp = abs(value - upper)
        return deltaDown < deltaUp ? lower : upper
    }
    
    func directionalValue<T: Numeric>(_ value: T) -> T {
        value * (layoutDirection == .rightToLeft ? -1 : 1)
    }
    
    func directionalOffset(_ offset: CGSize) -> CGSize {
        let width = self.directionalValue(offset.width)
        return .init(width: width, height: offset.height)
    }
}

extension SlidingRuler {

    // MARK: Control Update
    
    private func updateCellsIfNeeded() {
        guard let controlWidth = controlWidth else { return }
        let count = (Int(ceil(controlWidth / cellWidth)) + 4).nextOdd()
        if count != cells.count { self.populateCells(count: count) }
    }
    
    private func populateCells(count: Int) {
        let boundary = count.previousEven() / 2
        cells = (-boundary...boundary).enumerated().map { RulerCell(V($0.element)) }
    }
}

extension SlidingRuler {

    // MARK: Physic Simulation
    
    private func applyInertia(startLoc: CGPoint, releaseLoc: CGPoint, initialVelocity: CGFloat) {
        let friction = 2345.6
        let bounceFriction = 45678.9
        var location = releaseLoc.x
        var speed = abs(initialVelocity)
        let direction = speed / initialVelocity
        state = .flicking
        
        inertialTimer = .init(animations: { (timeFrame) in
            location += direction * speed * CGFloat(timeFrame)
            let translation = CGSize(horizontal: location - startLoc.x)
            let newOffset = self.directionalOffset(translation + (self.referenceOffset ?? .zero))
            let newValue = self.value(fromOffset: newOffset)
            
            self.tickIfNeeded(self.dragOffset.width, newOffset.width)
            
            withoutAnimation {
                self.setValue(newValue, via: \.$value)
                self.dragOffset = self.applyRubber(to: newOffset)
            }
            
            if !self.shouldReleaseRubberBand {
                speed = speed - CGFloat(friction * timeFrame)
            } else {
                speed = speed - CGFloat(bounceFriction * timeFrame)
            }
            
            if speed <= 0 { self.inertialTimer?.stop() }
        }, completion: { (completed) in
            if self.shouldReleaseRubberBand {
                self.releaseRubberBand()
            } else if completed {
                self.state = .idle
                self.snapIfNeeded()
            }
            
            self.endDragSession()
        })
    }
    
    private func applyRubber(to offset: CGSize) -> CGSize {
        let dragBounds = self.dragBounds
        guard !dragBounds.contains(offset.width) else { return offset }
        
        let tx = offset.width
        let nearest = tx.clamped(to: dragBounds)
        let delta = tx - nearest
        let factor: CGFloat = delta < 0 ? -1 : 1
        let c = cellWidth * 2.5
        let rubberDelta = c * (1 + log10((abs(delta) + c)/c)) - c
        let rubberTx = nearest + factor * rubberDelta
        
        return .init(horizontal: rubberTx)
    }
    
    private func releaseRubberBand() {
        self.animatedValue = self.value(fromOffset: effectiveOffset)
        self.state = .animating
        self.dragOffset = self.offset(fromValue: self.value)
        NextLoop {
            withAnimation(.spring(response: 0.666, dampingFraction: 1.0)) {
                self.animatedValue = self.value
            }
        }
    }
}

extension SlidingRuler {

    // MARK: Tick Management
    
    private func boundaryMet() {
        let fg = UIImpactFeedbackGenerator(style: .rigid)
        fg.impactOccurred(intensity: 0.667)
    }
    
    private func tickIfNeeded(_ offset0: CGFloat, _ offset1: CGFloat) {
        guard dragBounds.contains(offset0), dragBounds.contains(offset1),
            !offset0.isBound(of: dragBounds), !offset1.isBound(of: dragBounds) else { return }
        
        let t: CGFloat
        switch tick {
        case .unit: t = cellWidth
        case .half: t = hasHalf ? cellWidth / 2 : cellWidth
        case .fraction: t = cellWidth / CGFloat(fractions)
        case .none: return
        }
        
        if offset1 == 0 ||
            (offset0 < 0) != (offset1 < 0) ||
            Int(offset0 / t) != Int(offset1 / t) {
            valueTick()
        }
    }
    
    private func valueTick() {
        let fg = UIImpactFeedbackGenerator(style: .light)
        fg.impactOccurred(intensity: 0.5)
    }
}
