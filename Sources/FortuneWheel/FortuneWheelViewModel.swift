//
//  FortuneWheelViewModel.swift
//  FortuneWheel
//
//  Created by Sameer Nawaz on 19/04/21.
//

import SwiftUI
import AudioToolbox
#if canImport(AVFoundation)
import AVFoundation
#endif

@available(macOS 10.15, *)
@available(iOS 13.0, *)
class FortuneWheelViewModel: ObservableObject {

    private var pendingRequestWorkItem: DispatchWorkItem?
    @Published var degree = 0.0
    
    // Tick sound properties
    private var lastTickSegment = -1
    private var tickSoundEnabled = true
    private var animationStartTime: TimeInterval = 0
    
    // Track last selected option to prevent consecutive same results
    private var lastSelectedIndex: Int? = nil

    private let model: FortuneWheelModel

    init(model: FortuneWheelModel) {
        self.model = model
        self.tickSoundEnabled = model.enableTickSound
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        #if canImport(AVFoundation) && !os(macOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }
    
    private func playTickSound() {
        if tickSoundEnabled {
            // Use a more basic system sound that should work reliably
            AudioServicesPlaySystemSound(1105) // System click sound - more reliable
            print("Playing tick sound") // Debug output
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
        if index < 0 || index >= model.titles.count { 
            // Generate a random index, but exclude the last selected option if it exists
            // Note: If there's only 1 option, we can't prevent the same result (expected behavior)
            var availableIndices = Array(0..<model.titles.count)
            if let lastIndex = lastSelectedIndex, model.titles.count > 1 {
                availableIndices.removeAll { $0 == lastIndex }
            }
            index = availableIndices.randomElement() ?? Int.random(in: 0..<model.titles.count)
        }
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
            let selectedIndex = count - Int(pointer) - 1
            
            // Update the last selected index for next spin
            self.lastSelectedIndex = selectedIndex
            
            if let onSpinEnd = self.model.onSpinEnd { onSpinEnd(selectedIndex) }
        }
    }
    
    private func startTickSoundMonitoring() {
        // Cancel any existing monitoring
        pendingRequestWorkItem?.cancel()
        
        animationStartTime = Date().timeIntervalSince1970
        
        func scheduleNextTick() {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // Calculate elapsed time and progress
                let elapsedTime = Date().timeIntervalSince1970 - self.animationStartTime
                let remainingTime = self.model.animDuration - elapsedTime
                let progress = elapsedTime / self.model.animDuration
                
                // Stop if animation is complete
                if remainingTime <= 0 {
                    return
                }
                
                let currentSegment = self.getCurrentSegmentUnderPointer()
                
                print("currentSegment: \(currentSegment)")
                print("lastTickSegment: \(self.lastTickSegment)")
                // Play tick sound when a new segment passes under the pointer
                // if currentSegment != self.lastTickSegment && self.lastTickSegment != -1 {
                    self.playTickSound()
                // }
                
                self.lastTickSegment = currentSegment
                
                // Calculate next tick interval based on progress (ease-in/ease-out)
                let tickInterval: TimeInterval
                if progress < 0.05 {
                    // First 5%: slow (ease in)
                    // Progress from 0.4s to 0.04s
                    let easeProgress = progress / 0.05 // 0 to 1 in first 5%
                    tickInterval = 0.4 - (easeProgress * 0.36) // 0.4s → 0.04s
                } else if progress > 0.95 {
                    // Last 5%: slow (ease out)
                    // Progress from 0.04s to 0.4s
                    let easeProgress = (progress - 0.95) / 0.05 // 0 to 1 in last 5%
                    tickInterval = 0.04 + (easeProgress * 0.36) // 0.04s → 0.4s
                } else {
                    // Middle 90%: fast
                    tickInterval = 0.04 // 40ms - fast ticking
                }
                
                // Continue monitoring if animation is still running
                if remainingTime > tickInterval {
                    scheduleNextTick()
                }
            }
            
            self.pendingRequestWorkItem = workItem
            
            // Calculate initial interval based on current progress
            let elapsedTime = Date().timeIntervalSince1970 - self.animationStartTime
            let progress = elapsedTime / self.model.animDuration
            
            let initialInterval: TimeInterval
            if progress < 0.05 {
                let easeProgress = progress / 0.05
                initialInterval = 0.4 - (easeProgress * 0.36)
            } else if progress > 0.95 {
                let easeProgress = (progress - 0.95) / 0.05
                initialInterval = 0.04 + (easeProgress * 0.36)
            } else {
                initialInterval = 0.04
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + initialInterval, execute: workItem)
        }
        
        scheduleNextTick()
    }
}
