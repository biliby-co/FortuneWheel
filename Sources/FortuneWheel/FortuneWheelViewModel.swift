//
//  FortuneWheelViewModel.swift
//  FortuneWheel
//
//  Created by Sameer Nawaz on 19/04/21.
//

import SwiftUI

@available(macOS 10.15, *)
@available(iOS 13.0, *)
class FortuneWheelViewModel: ObservableObject {

    @Published var degree = 0.0
    
    // Track last selected option to prevent consecutive same results
    private var lastSelectedIndex: Int? = nil

    private let model: FortuneWheelModel

    init(model: FortuneWheelModel) {
        self.model = model
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
        if let onSpinStart = model.onSpinStart { onSpinStart() }

        withAnimation(model.animation) {
            self.degree = Double(360 * Int(self.degree / 360)) + getWheelStopDegree();
        }
        
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
}
