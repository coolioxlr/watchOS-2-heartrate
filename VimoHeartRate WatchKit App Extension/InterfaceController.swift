//
//  InterfaceController.swift
//  VimoHeartRate WatchKit App Extension
//
//  Created by Ethan Fan on 6/25/15.
//  Copyright © 2015 Vimo Lab. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit


class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    
    @IBOutlet private weak var label: WKInterfaceLabel!
    @IBOutlet private weak var deviceLabel : WKInterfaceLabel!
    @IBOutlet private weak var heart: WKInterfaceImage!
    @IBOutlet private weak var startStopButton : WKInterfaceButton!
    
    let healthStore = HKHealthStore()
    
    //State of the app - is the workout activated
    var workoutActive = false
    
    // define the activity type and location
    var workoutSession : HKWorkoutSession?
    let heartRateUnit = HKUnit(fromString: "count/min")
    var anchor = HKQueryAnchor(fromValue: Int(HKAnchoredObjectQueryNoAnchor))
    
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
    }
    
    override func willActivate() {
        super.willActivate()
        
        guard HKHealthStore.isHealthDataAvailable() == true else {
            label.setText("not available")
            return
        }
    
        guard let quantityType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else {
            displayNotAllowed()
            return
        }
        
        let dataTypes = Set(arrayLiteral: quantityType)
        healthStore.requestAuthorizationToShareTypes(nil, readTypes: dataTypes) { (success, error) -> Void in
            if success == false {
                self.displayNotAllowed()
            }
        }
    }
    
    func displayNotAllowed() {
        label.setText("not allowed")
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate) {
        switch toState {
        case .Running:
            workoutDidStart(date)
        case .Ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError) {
        // Do nothing for now
        NSLog("Workout error: \(error.userInfo)")
    }
    
    func workoutDidStart(date : NSDate) {
        if let query = createHeartRateStreamingQuery(date) {
            healthStore.executeQuery(query)
        } else {
            label.setText("cannot start")
        }
    }
    
    func workoutDidEnd(date : NSDate) {
        if let query = createHeartRateStreamingQuery(date) {
            healthStore.stopQuery(query)
            label.setText("---")
        } else {
            label.setText("cannot stop")
        }
    }
    
    // MARK: - Actions
    @IBAction func startBtnTapped() {
        if (self.workoutActive) {
            //finish the current workout
            self.workoutActive = false
            self.startStopButton.setTitle("Start")
            if let workout = self.workoutSession {
                healthStore.endWorkoutSession(workout)
            }
        } else {
            //start a new workout
            self.workoutActive = true
            self.startStopButton.setTitle("Stop")
            startWorkout()
        }

    }
    
    func startWorkout() {
        self.workoutSession = HKWorkoutSession(activityType: HKWorkoutActivityType.CrossTraining, locationType: HKWorkoutSessionLocationType.Indoor)
        self.workoutSession?.delegate = self
        healthStore.startWorkoutSession(self.workoutSession!)
    }
    
    func createHeartRateStreamingQuery(workoutStartDate: NSDate) -> HKQuery? {
        // adding predicate will not work
        // let predicate = HKQuery.predicateForSamplesWithStartDate(workoutStartDate, endDate: nil, options: HKQueryOptions.None)
        
        guard let quantityType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate) else { return nil }
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: nil, anchor: anchor, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            guard let newAnchor = newAnchor else {return} 
            self.anchor = newAnchor
            self.updateHeartRate(sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor!
            self.updateHeartRate(samples)
        }
        return heartRateQuery
    }
    
    func updateHeartRate(samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        
        dispatch_async(dispatch_get_main_queue()) {
            guard let sample = heartRateSamples.first else{return}
            let value = sample.quantity.doubleValueForUnit(self.heartRateUnit)
            self.label.setText(String(UInt16(value)))
            
            // retrieve source from sample
            let name = sample.sourceRevision.source.name
            self.updateDeviceName(name)
            self.animateHeart()
        }
    }
    
    func updateDeviceName(deviceName: String) {
        deviceLabel.setText(deviceName)
    }
    
    func animateHeart() {
        self.animateWithDuration(0.5) {
            self.heart.setWidth(60)
            self.heart.setHeight(90)
        }
        
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * double_t(NSEC_PER_SEC)))
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_after(when, queue) {
            dispatch_async(dispatch_get_main_queue(), {
                self.animateWithDuration(0.5, animations: {
                    self.heart.setWidth(50)
                    self.heart.setHeight(80)
                })
            })
        }
    }
}
