//
//  FortuneWheelViewModel.swift
//  FortuneWheel
//
//  Created by Sameer Nawaz on 19/04/21.
//

import SwiftUI
import AudioToolbox

@available(macOS 10.15, *)
@available(iOS 13.0, *)
class FortuneWheelViewModel: ObservableObject {

    private var pendingRequestWorkItem: DispatchWorkItem?
    @Published var degree = 0.0
    
    // Tick sound properties
    private var lastTickSegment = -1
    private var tickSoundEnabled = true
    private var animationStartTime: TimeInterval = 0

    private let model: FortuneWheelModel

    init(model: FortuneWheelModel) {
        self.model = model
        self.tickSoundEnabled = model.enableTickSound
    }
    
    private func playTickSound() {
        if tickSoundEnabled {
            AudioServicesPlaySystemSound(1104) // System tick sound
        }
    }
    
    private func getCurrentSegmentUnderPointer() -> Int {
        let count = model.titles.count
        let normalizedDegree = degree.truncatingRemainder(dividingBy: 360)
        // Convert to 0-360 range and adjust for pointer position (top of wheel)
        let adjustedDegree = (360 - normalizedDegree).truncatingRemainder(dividingBy: 360)
        let segmentSize = 360.0 / Double(count)
        let segment = Int(adjustedDegree / segmentSize)
        return segment
    }

    private func getWheelStopDegree() -> Double {
        var index = -1;
        if let method = model.getWheelItemIndex { index = method() }
        if index < 0 || index >= model.titles.count { index = Int.random(in: 0..<model.titles.count) }
        index = model.titles.count - index - 1;
        /*
         itemRange - Each items degree range (For 4, each will have 360 / 4 = 90 degrees)
         indexDegree - No. of 90 degrees to reach i item
         freeSpins - No. of spins before it goes to selected item index
         finalDegree - Final exact degree to spin and stop in the index
         */
        let itemRange = 360 / model.titles.count;
        let indexDegree = itemRange * index;
        let centerOffset = itemRange / 2; // Center the segment with the pointer
        let freeSpins = (2...20).map({ return $0 * 360 }).randomElement()!
        let finalDegree = freeSpins + indexDegree + centerOffset;
        return Double(finalDegree);
    }
    
    func spinWheel() {
        // Reset tick tracking
        lastTickSegment = -1
        
        withAnimation(model.animation) {
            self.degree = Double(360 * Int(self.degree / 360)) + getWheelStopDegree();
        }
        
        // Start tick sound monitoring during animation
        startTickSoundMonitoring()
        
        // Handle completion after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + model.animDuration) { [weak self] in
            guard let self = self else { return }
            let count = self.model.titles.count
            let distance = self.degree.truncatingRemainder(dividingBy: 360)
            let pointer = floor(distance / (360 / Double(count)))
            if let onSpinEnd = self.model.onSpinEnd { onSpinEnd(count - Int(pointer) - 1) }
        }
    }
    
    private func startTickSoundMonitoring() {
        // Cancel any existing monitoring
        pendingRequestWorkItem?.cancel()
        
        animationStartTime = Date().timeIntervalSince1970
        
        func scheduleNextTick() {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                let currentSegment = self.getCurrentSegmentUnderPointer()
                
                // Play tick sound when a new segment passes under the pointer
                if currentSegment != self.lastTickSegment && self.lastTickSegment != -1 {
                    self.playTickSound()
                }
                
                self.lastTickSegment = currentSegment
                
                // Continue monitoring if animation is still running
                let remainingTime = self.model.animDuration - (Date().timeIntervalSince1970 - self.animationStartTime)
                if remainingTime > 0.1 { // Continue if more than 0.1 seconds remain
                    scheduleNextTick()
                }
            }
            
            self.pendingRequestWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
        }
        
        scheduleNextTick()
    }
}
