import Foundation

/// Basic learning steps strategy implementation
public func basicLearningStepsStrategy(
    params: FSRSParameters,
    state: State,
    curStep: Int
) -> [Rating: (scheduledMinutes: Int, nextStep: Int)] {
    let learningSteps = (state == .relearning || state == .review)
        ? params.relearningSteps
        : params.learningSteps
    
    let stepsLength = learningSteps.count
    
    // If no steps or current step is beyond available steps, return empty
    if stepsLength == 0 || curStep >= stepsLength {
        return [:]
    }
    
    let firstStep = learningSteps[0]
    
    let getAgainInterval: () -> Int = {
        firstStep.scheduledMinutes
    }
    
    let getHardInterval: () -> Int = {
        if stepsLength == 1 {
            return Int(round(Double(firstStep.scheduledMinutes) * 1.5))
        }
        // stepsLength > 1
        let nextStep = learningSteps[1]
        return Int(round(Double(firstStep.scheduledMinutes + nextStep.scheduledMinutes) / 2.0))
    }
    
    let getStepInfo: (Int) -> StepUnit? = { index in
        if index < 0 || index >= stepsLength {
            return nil
        } else {
            return learningSteps[index]
        }
    }
    
    var result: [Rating: (scheduledMinutes: Int, nextStep: Int)] = [:]
    let stepInfo = getStepInfo(max(0, curStep))
    
    if state == .review {
        // Review state: only Again rating
        if let step = stepInfo {
            result[.again] = (
                scheduledMinutes: step.scheduledMinutes,
                nextStep: 0
            )
        }
        return result
    } else {
        // New, Learning, or Relearning states
        result[.again] = (
            scheduledMinutes: getAgainInterval(),
            nextStep: 0
        )
        
        result[.hard] = (
            scheduledMinutes: getHardInterval(),
            nextStep: curStep
        )
        
        if let nextInfo = getStepInfo(curStep + 1) {
            result[.good] = (
                scheduledMinutes: nextInfo.scheduledMinutes,
                nextStep: curStep + 1
            )
        }
    }
    
    return result
}
