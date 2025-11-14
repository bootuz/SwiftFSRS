//
//  TestCard.swift
//  FSRS
//
//  Created by Astemir Boziev on 05.11.25.
//
import Foundation
@testable import FSRS

struct TestCard: FSRSCard {
    let id: UUID
    let question: String
    let answer: String
    let tags: [String]
    let notes: String?
    
    
    var due: Date
    var state: State
    var lastReview: Date?
    var stability: Double
    var difficulty: Double
    var scheduledDays: Int
    var learningSteps: Int
    var reps: Int
    var lapses: Int
    
    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        tags: [String] = [],
        notes: String? = nil,
        due: Date = Date(),
        state: State = .new,
        lastReview: Date? = nil,
        stability: Double = 0,
        difficulty: Double = 0,
        scheduledDays: Int = 0,
        learningSteps: Int = 0,
        reps: Int = 0,
        lapses: Int = 0
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.tags = tags
        self.notes = notes
        self.due = due
        self.state = state
        self.lastReview = lastReview
        self.stability = stability
        self.difficulty = difficulty
        self.scheduledDays = scheduledDays
        self.learningSteps = learningSteps
        self.reps = reps
        self.lapses = lapses
    }
}
